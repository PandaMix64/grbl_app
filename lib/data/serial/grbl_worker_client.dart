import 'dart:async';
import 'dart:isolate';

import '../../core/grbl/grbl_constants.dart';
import '../../domain/entities/axis.dart';
import '../../domain/entities/grbl_handshake.dart';
import '../../domain/entities/grbl_settings.dart';
import '../../domain/entities/jog_command.dart';
import '../../domain/entities/parser_state.dart';
import '../../domain/entities/status_report.dart';
import '../../domain/entities/work_offsets.dart';
import '../../domain/repositories/serial_port_repository.dart';
import 'grbl_worker.dart';
import 'grbl_worker_protocol.dart';
import 'lib_serial_port_repository.dart';

/// Petición de persistencia: el worker pausó la máquina y espera confirmación
/// antes de resetear (SEG-03).
class WorkerPersistRequest {
  const WorkerPersistRequest({
    required this.id,
    required this.confirmPersisted,
    this.status,
    this.parserState,
    this.offsets,
  });

  final Object? id;

  /// Último status report antes de la pausa, útil para guardar el punto.
  final StatusReport? status;

  /// Estado modal leído con `$G` dentro de la pausa; `null` si no se pudo leer.
  final ParserState? parserState;

  /// Offsets leídos con `$#` dentro de la pausa; `null` si no se pudieron leer.
  final WorkOffsets? offsets;

  /// Confirma que el progreso quedó persistido.
  final void Function() confirmPersisted;
}

/// Cliente del worker serial: API tipada sobre mensajes de isolate.
///
/// La UI nunca toca el puerto ni el `GrblSerialService`: habla con este cliente.
/// Con `spawn()` el puerto vive en un isolate aparte; con `inProcess()` el mismo
/// código se prueba en el isolate del test usando `FakeSerialPort`.
class GrblWorkerClient {
  GrblWorkerClient._(this._fromWorker) {
    _fromWorker.listen(_onMessage);
  }

  /// Worker en el mismo isolate (solo pruebas con puerto falso).
  factory GrblWorkerClient.inProcess({
    required SerialPortRepository port,
    int bufferSize = kDefaultRxBufferSize,
    Duration persistTimeout = const Duration(seconds: 20),
  }) {
    final ReceivePort fromWorker = ReceivePort();
    final GrblWorkerClient client = GrblWorkerClient._(fromWorker);
    final ReceivePort inbox = ReceivePort();
    final GrblWorker worker = GrblWorker(
      toClient: fromWorker.sendPort,
      port: port,
      bufferSize: bufferSize,
      persistTimeout: persistTimeout,
    );
    worker.listen(inbox);
    // En el mismo isolate el canal está listo de inmediato: no hay que esperar
    // el anuncio del SendPort como en `spawn()`.
    client._toWorker = inbox.sendPort;
    if (!client._ready.isCompleted) {
      client._ready.complete();
    }
    client._worker = worker;
    return client;
  }

  final ReceivePort _fromWorker;
  final StreamController<StatusReport> _statuses =
      StreamController<StatusReport>.broadcast();
  final StreamController<String> _messages =
      StreamController<String>.broadcast();
  final StreamController<WorkerPersistRequest> _persistRequests =
      StreamController<WorkerPersistRequest>.broadcast();
  final StreamController<int> _progress = StreamController<int>.broadcast();
  final StreamController<String> _console =
      StreamController<String>.broadcast();
  final Map<int, Completer<Map<String, Object?>>> _pending =
      <int, Completer<Map<String, Object?>>>{};
  final Completer<void> _ready = Completer<void>();

  SendPort? _toWorker;
  Isolate? _isolate;
  GrblWorker? _worker;
  int _nextId = 1;

  /// Worker en proceso (solo cuando se usa [GrblWorkerClient.inProcess]).
  ///
  /// Se mantiene referenciado para que el recolector no lo elimine y para que
  /// las pruebas puedan inspeccionarlo.
  GrblWorker? get inProcessWorker => _worker;

  Stream<StatusReport> get statusReports => _statuses.stream;
  Stream<String> get messages => _messages.stream;
  Stream<WorkerPersistRequest> get persistRequests => _persistRequests.stream;

  /// Progreso del programa: línea de origen confirmada por GRBL.
  Stream<int> get programProgress => _progress.stream;

  /// Tráfico de consola (comandos enviados y respuestas), sin telemetría.
  Stream<String> get consoleLines => _console.stream;
  bool get isReady => _toWorker != null;

  /// Lanza el worker en un isolate propio con el puerto FFI real.
  static Future<GrblWorkerClient> spawn() async {
    final ReceivePort fromWorker = ReceivePort();
    final GrblWorkerClient client = GrblWorkerClient._(fromWorker);
    client._isolate = await Isolate.spawn(
      _workerEntryPoint,
      fromWorker.sendPort,
      debugName: 'grbl-worker',
    );
    await client._ready.future.timeout(const Duration(seconds: 10));
    return client;
  }

  void _onMessage(Object? message) {
    if (message is SendPort) {
      _toWorker = message;
      if (!_ready.isCompleted) {
        _ready.complete();
      }
      return;
    }
    if (message is! Map) {
      return;
    }
    final Object? event = message[GrblWorkerKey.event];
    final Object? id = message[GrblWorkerKey.id];

    switch (event) {
      case GrblWorkerEvent.status:
        final Object? line = message[GrblWorkerKey.line];
        if (line is String && !_statuses.isClosed) {
          try {
            _statuses.add(StatusReport.parse(line));
          } on FormatException {
            // Un reporte ilegible no debe tumbar el canal.
          }
        }
      case GrblWorkerEvent.message:
        final Object? text = message[GrblWorkerKey.message];
        if (text is String && !_messages.isClosed) {
          _messages.add(text);
        }
      case GrblWorkerEvent.result:
        if (id is int) {
          final Completer<Map<String, Object?>>? completer = _pending.remove(
            id,
          );
          final Object? data = message[GrblWorkerKey.data];
          if (completer != null && !completer.isCompleted) {
            completer.complete(
              data is Map<String, Object?> ? data : <String, Object?>{},
            );
          }
        }
      case GrblWorkerEvent.error:
        if (id is int) {
          final Completer<Map<String, Object?>>? completer = _pending.remove(
            id,
          );
          if (completer != null && !completer.isCompleted) {
            completer.completeError(
              GrblWorkerException(
                message[GrblWorkerKey.message] as String? ??
                    'Error desconocido del worker.',
              ),
            );
          }
        }
      case GrblWorkerEvent.progress:
        final Object? progressLine = message[GrblWorkerKey.startLine];
        if (progressLine is int && !_progress.isClosed) {
          _progress.add(progressLine);
        }
      case GrblWorkerEvent.console:
        final Object? consoleLine = message[GrblWorkerKey.text];
        if (consoleLine is String && !_console.isClosed) {
          _console.add(consoleLine);
        }
      case GrblWorkerEvent.persistRequest:
        final Object? line = message[GrblWorkerKey.line];
        StatusReport? report;
        if (line is String) {
          try {
            report = StatusReport.parse(line);
          } on FormatException {
            report = null;
          }
        }
        final Object? rawParserState = message[GrblWorkerKey.parserState];
        ParserState? parserState;
        if (rawParserState is Map<String, Object?>) {
          try {
            parserState = ParserState.fromJson(rawParserState);
          } on FormatException {
            parserState = null;
          }
        }
        final Object? rawOffsets = message[GrblWorkerKey.offsets];
        WorkOffsets? offsets;
        if (rawOffsets is Map<String, Object?>) {
          offsets = WorkOffsets.fromJson(rawOffsets);
        }
        if (!_persistRequests.isClosed) {
          _persistRequests.add(
            WorkerPersistRequest(
              id: id,
              status: report,
              parserState: parserState,
              offsets: offsets,
              confirmPersisted: () {
                _toWorker?.send(<String, Object?>{
                  GrblWorkerKey.command: GrblWorkerCommand.persistDone,
                  GrblWorkerKey.id: id,
                });
              },
            ),
          );
        }
    }
  }

  /// Conecta y devuelve el handshake completo (búfer real, `$$`, `$G`, `$#`).
  Future<GrblHandshake> connect({
    required String portName,
    int baudRate = kDefaultBaudRate,
  }) async {
    final Map<String, Object?> data = await _send(
      GrblWorkerCommand.connect,
      <String, Object?>{
        GrblWorkerKey.portName: portName,
        GrblWorkerKey.baudRate: baudRate,
      },
    );
    return GrblHandshake.fromJson(data);
  }

  Future<void> disconnect() => _send(GrblWorkerCommand.disconnect);

  /// Puertos disponibles en el sistema (enumeración FFI en el worker).
  Future<List<SerialPortInfo>> listPorts() async {
    final Map<String, Object?> data = await _send(GrblWorkerCommand.listPorts);
    final Object? ports = data[GrblWorkerKey.ports];
    if (ports is! List) {
      return const <SerialPortInfo>[];
    }
    return <SerialPortInfo>[
      for (final Object? item in ports)
        if (item is Map<String, Object?>)
          SerialPortInfo(
            name: item[GrblWorkerKey.portName] as String? ?? '',
            description: item[GrblWorkerKey.message] as String?,
          ),
    ];
  }

  Future<void> startPolling({
    Duration interval = const Duration(milliseconds: 200),
  }) => _send(GrblWorkerCommand.startPolling, <String, Object?>{
    GrblWorkerKey.intervalMs: interval.inMilliseconds,
  });

  Future<void> stopPolling() => _send(GrblWorkerCommand.stopPolling);

  Future<void> requestStatus() => _send(GrblWorkerCommand.requestStatus);

  Future<void> streamGcode(Iterable<String> blocks) => _send(
    GrblWorkerCommand.stream,
    <String, Object?>{GrblWorkerKey.blocks: List<String>.of(blocks)},
  );

  /// Envía un programa y publica progreso por línea de origen confirmada.
  Future<void> streamProgram(List<String> lines, {int startLine = 0}) {
    return _send(GrblWorkerCommand.streamProgram, <String, Object?>{
      GrblWorkerKey.blocks: lines,
      GrblWorkerKey.startLine: startLine,
    });
  }

  /// Pausa segura con persistencia obligatoria del punto de reanudación.
  Future<StatusReport?> pauseJob() async {
    final Map<String, Object?> data = await _send(GrblWorkerCommand.pauseJob);
    final Object? line = data[GrblWorkerKey.line];
    return line is String ? StatusReport.parse(line) : null;
  }

  /// Reanuda el programa tras la pausa: reactiva la herramienta (si estaba
  /// encendida) y envía cycle start, sin reenviar líneas.
  Future<StatusReport?> resumeJob({bool restartTool = true}) async {
    final Map<String, Object?> data = await _send(
      GrblWorkerCommand.resumeJob,
      <String, Object?>{GrblWorkerKey.toolOn: restartTool},
    );
    final Object? line = data[GrblWorkerKey.line];
    return line is String ? StatusReport.parse(line) : null;
  }

  /// Pausa segura: detiene el movimiento y apaga la herramienta.
  Future<StatusReport?> pause() async {
    final Map<String, Object?> data = await _send(GrblWorkerCommand.pause);
    final Object? line = data[GrblWorkerKey.line];
    return line is String ? StatusReport.parse(line) : null;
  }

  /// Reanuda: reactiva la herramienta, espera y envía `~`.
  Future<void> resume({
    required String toolOnLine,
    Duration settle = const Duration(seconds: 4),
  }) => _send(GrblWorkerCommand.resume, <String, Object?>{
    GrblWorkerKey.toolOnLine: toolOnLine,
    GrblWorkerKey.settleMs: settle.inMilliseconds,
  });

  /// Detiene el trabajo.
  ///
  /// El worker emitirá un [WorkerPersistRequest]; si no se confirma con
  /// `confirmPersisted()`, no se envía el soft reset y la llamada falla.
  Future<void> stopJob() => _send(GrblWorkerCommand.stop);

  Future<void> cancelJog() => _send(GrblWorkerCommand.jogCancel);

  Future<void> unlock() => _send(GrblWorkerCommand.unlock);

  /// Envía una línea escrita en la consola de la UI.
  Future<void> sendConsoleCommand(String line) => _send(
    GrblWorkerCommand.consoleCommand,
    <String, Object?>{GrblWorkerKey.text: line},
  );

  /// Soft reset manual (`0x18`); pierde posición y estado modal.
  Future<void> softReset() => _send(GrblWorkerCommand.softReset);

  Future<void> home() => _send(GrblWorkerCommand.home);

  /// Ejecuta un jog (`$J=`) con avance obligatorio.
  Future<void> jog({
    required Map<MachineAxis, double> values,
    required double feedMmPerMin,
    JogMode mode = JogMode.relative,
  }) {
    return _send(GrblWorkerCommand.jog, <String, Object?>{
      GrblWorkerKey.values: <String, double>{
        for (final MapEntry<MachineAxis, double> entry in values.entries)
          entry.key.name: entry.value,
      },
      GrblWorkerKey.feedMmMin: feedMmPerMin,
      GrblWorkerKey.absolute: mode == JogMode.absoluteMachine,
    });
  }

  /// Escribe parámetros `$` y devuelve cuántos se aplicaron.
  Future<int> writeSettings(Map<int, String> changes) async {
    final Map<String, Object?> data = await _send(
      GrblWorkerCommand.writeSettings,
      <String, Object?>{
        GrblWorkerKey.changes: <String, String>{
          for (final MapEntry<int, String> entry in changes.entries)
            entry.key.toString(): entry.value,
        },
      },
    );
    return (data[GrblWorkerKey.written] as num?)?.toInt() ?? 0;
  }

  /// Fija el cero de trabajo actual en G54 (`G10 L20 P1`).
  Future<void> setWorkZero({bool x = true, bool y = true, bool z = true}) {
    return _send(GrblWorkerCommand.setWorkZero, <String, Object?>{
      GrblWorkerKey.axes: <String>[if (x) 'x', if (y) 'y', if (z) 'z'],
    });
  }

  Future<GrblSettings> readSettings() async =>
      GrblSettings.fromJson(await _send(GrblWorkerCommand.readSettings));

  Future<ParserState> readParserState({bool direct = false}) async =>
      ParserState.fromJson(
        await _send(GrblWorkerCommand.readParserState, <String, Object?>{
          GrblWorkerKey.direct: direct,
        }),
      );

  Future<WorkOffsets> readOffsets({bool direct = false}) async =>
      WorkOffsets.fromJson(
        await _send(GrblWorkerCommand.readOffsets, <String, Object?>{
          GrblWorkerKey.direct: direct,
        }),
      );

  Future<Map<String, Object?>> _send(
    String command, [
    Map<String, Object?> args = const <String, Object?>{},
  ]) {
    final SendPort? port = _toWorker;
    if (port == null) {
      throw const GrblWorkerException('El worker no está listo.');
    }
    final int id = _nextId++;
    final Completer<Map<String, Object?>> completer =
        Completer<Map<String, Object?>>();
    _pending[id] = completer;
    port.send(<String, Object?>{
      GrblWorkerKey.command: command,
      GrblWorkerKey.id: id,
      ...args,
    });
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove(id);
        throw GrblWorkerException('El worker no respondió a "$command".');
      },
    );
  }

  /// Cierra el worker y libera el puerto.
  Future<void> dispose() async {
    if (_toWorker != null) {
      try {
        await _send(GrblWorkerCommand.dispose);
      } on Object {
        // El worker puede haberse cerrado ya.
      }
    }
    _fromWorker.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _worker = null;
    for (final Completer<Map<String, Object?>> completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          const GrblWorkerException('El worker se cerró.'),
        );
      }
    }
    _pending.clear();
    await _statuses.close();
    await _messages.close();
    await _persistRequests.close();
    await _progress.close();
    await _console.close();
  }
}

/// Punto de entrada del isolate worker (debe ser de nivel superior).
Future<void> _workerEntryPoint(SendPort toClient) async {
  final ReceivePort inbox = ReceivePort();
  toClient.send(inbox.sendPort);
  final GrblWorker worker = GrblWorker(
    toClient: toClient,
    port: LibSerialPortRepository(),
  );
  worker.listen(inbox);
}
