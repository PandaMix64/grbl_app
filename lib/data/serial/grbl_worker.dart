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
import 'grbl_serial_service.dart';
import 'grbl_worker_protocol.dart';

/// Error producido dentro del worker y reenviado al cliente.
class GrblWorkerException implements Exception {
  const GrblWorkerException(this.message);

  final String message;

  @override
  String toString() => 'GrblWorkerException: $message';
}

/// Lado worker del canal serial: posee el puerto y el [GrblSerialService].
///
/// Se puede crear dentro del isolate actual (pruebas con `FakeSerialPort`) o
/// dentro de un isolate propio vía `GrblWorkerClient.spawn()`.
///
/// El comando `stop` implementa la confirmación de persistencia: el worker
/// **no** envía el soft reset hasta que el cliente confirma haber guardado el
/// punto de reanudación (SEG-03).
class GrblWorker {
  GrblWorker({
    required this.toClient,
    required SerialPortRepository port,
    int bufferSize = kDefaultRxBufferSize,
    this.persistTimeout = const Duration(seconds: 20),
  }) : _service = GrblSerialService(port: port, bufferSize: bufferSize) {
    _forwardEvents();
  }

  final SendPort toClient;
  final GrblSerialService _service;

  /// Tiempo máximo que el worker espera la confirmación de guardado.
  final Duration persistTimeout;

  ReceivePort? _inbox;
  StreamSubscription<StatusReport>? _statusSub;
  StreamSubscription<String>? _messageSub;
  StreamSubscription<int>? _progressSub;
  StreamSubscription<String>? _consoleSub;
  Completer<void>? _persistAck;

  /// Servicio interno, expuesto para pruebas en proceso.
  GrblSerialService get service => _service;

  /// Empieza a atender comandos del cliente.
  void listen(ReceivePort inbox) {
    _inbox = inbox;
    inbox.listen((Object? message) {
      unawaited(_handle(message));
    });
  }

  void _forwardEvents() {
    _statusSub = _service.statusReports.listen((StatusReport report) {
      toClient.send(<String, Object?>{
        GrblWorkerKey.event: GrblWorkerEvent.status,
        GrblWorkerKey.line: report.raw,
      });
    });
    _messageSub = _service.messages.listen((String message) {
      toClient.send(<String, Object?>{
        GrblWorkerKey.event: GrblWorkerEvent.message,
        GrblWorkerKey.message: message,
      });
    });
    _progressSub = _service.programProgress.listen((int line) {
      toClient.send(<String, Object?>{
        GrblWorkerKey.event: GrblWorkerEvent.progress,
        GrblWorkerKey.startLine: line,
      });
    });
    _consoleSub = _service.consoleLines.listen((String line) {
      toClient.send(<String, Object?>{
        GrblWorkerKey.event: GrblWorkerEvent.console,
        GrblWorkerKey.text: line,
      });
    });
  }

  Future<void> _handle(Object? raw) async {
    if (raw is! Map) {
      return;
    }
    final Object? command = raw[GrblWorkerKey.command];
    final Object? id = raw[GrblWorkerKey.id];
    try {
      switch (command) {
        case GrblWorkerCommand.connect:
          final GrblHandshake handshake = await _service.connectAndIdentify(
            portName: raw[GrblWorkerKey.portName] as String? ?? '',
            baudRate:
                (raw[GrblWorkerKey.baudRate] as num?)?.toInt() ??
                kDefaultBaudRate,
          );
          _reply(id, handshake.toJson());
        case GrblWorkerCommand.disconnect:
          await _service.disconnect();
          _reply(id);
        case GrblWorkerCommand.listPorts:
          final List<SerialPortInfo> ports = await _service.listPorts();
          _reply(id, <String, Object?>{
            GrblWorkerKey.ports: <Map<String, Object?>>[
              for (final SerialPortInfo port in ports)
                <String, Object?>{
                  GrblWorkerKey.portName: port.name,
                  GrblWorkerKey.message: port.description,
                },
            ],
          });
        case GrblWorkerCommand.startPolling:
          _service.startStatusPolling(
            interval: Duration(
              milliseconds:
                  (raw[GrblWorkerKey.intervalMs] as num?)?.toInt() ?? 200,
            ),
          );
          _reply(id);
        case GrblWorkerCommand.stopPolling:
          _service.stopStatusPolling();
          _reply(id);
        case GrblWorkerCommand.requestStatus:
          _service.requestStatus();
          _reply(id);
        case GrblWorkerCommand.stream:
          final Object? blocks = raw[GrblWorkerKey.blocks];
          if (blocks is! List) {
            throw const GrblWorkerException(
              'El comando stream requiere una lista de bloques.',
            );
          }
          _service.streamGcode(blocks.whereType<String>());
          _reply(id);
        case GrblWorkerCommand.streamProgram:
          final Object? programLines = raw[GrblWorkerKey.blocks];
          if (programLines is! List) {
            throw const GrblWorkerException(
              'El comando streamProgram requiere la lista de líneas.',
            );
          }
          _service.streamProgram(
            programLines.whereType<String>().toList(),
            startLine: (raw[GrblWorkerKey.startLine] as num?)?.toInt() ?? 0,
          );
          _reply(id);
        case GrblWorkerCommand.pauseJob:
          final StatusReport report = await _service.pauseJob();
          await _requestPersistence(id);
          _reply(id, <String, Object?>{GrblWorkerKey.line: report.raw});
        case GrblWorkerCommand.resumeJob:
          final StatusReport resumed = await _service.resumeProgram(
            restartTool: raw[GrblWorkerKey.toolOn] as bool? ?? true,
          );
          _reply(id, <String, Object?>{GrblWorkerKey.line: resumed.raw});
        case GrblWorkerCommand.pause:
          final StatusReport report = await _service.pauseSafely();
          _reply(id, <String, Object?>{GrblWorkerKey.line: report.raw});
        case GrblWorkerCommand.resume:
          final String toolOn = raw[GrblWorkerKey.toolOnLine] as String? ?? '';
          if (toolOn.isEmpty) {
            throw const GrblWorkerException(
              'El comando resume requiere toolOnLine.',
            );
          }
          await _service.resumeAfterPause(
            toolOnLine: toolOn,
            settle: Duration(
              milliseconds:
                  (raw[GrblWorkerKey.settleMs] as num?)?.toInt() ?? 4000,
            ),
          );
          _reply(id);
        case GrblWorkerCommand.jogCancel:
          await _service.cancelJog();
          _reply(id);
        case GrblWorkerCommand.unlock:
          _service.unlock();
          _reply(id);
        case GrblWorkerCommand.consoleCommand:
          _service.sendConsoleCommand(raw[GrblWorkerKey.text] as String? ?? '');
          _reply(id);
        case GrblWorkerCommand.softReset:
          await _service.softReset();
          _reply(id);
        case GrblWorkerCommand.home:
          _service.home();
          _reply(id);
        case GrblWorkerCommand.jog:
          final Object? rawValues = raw[GrblWorkerKey.values];
          final Object? rawFeed = raw[GrblWorkerKey.feedMmMin];
          if (rawValues is! Map || rawFeed is! num) {
            throw const GrblWorkerException(
              'El comando jog requiere values y feedMmMin.',
            );
          }
          final Map<MachineAxis, double> increments = <MachineAxis, double>{};
          for (final MapEntry<Object?, Object?> entry in rawValues.entries) {
            final MachineAxis? axis = _axisByName(entry.key);
            final Object? value = entry.value;
            if (axis != null && value is num) {
              increments[axis] = value.toDouble();
            }
          }
          _service.jog(
            JogCommand(
              values: increments,
              feedMmMin: rawFeed.toDouble(),
              mode: raw[GrblWorkerKey.absolute] == true
                  ? JogMode.absoluteMachine
                  : JogMode.relative,
            ),
          );
          _reply(id);
        case GrblWorkerCommand.writeSettings:
          final Object? rawChanges = raw[GrblWorkerKey.changes];
          if (rawChanges is! Map) {
            throw const GrblWorkerException(
              'El comando writeSettings requiere changes.',
            );
          }
          final Map<int, String> changes = <int, String>{};
          for (final MapEntry<Object?, Object?> entry in rawChanges.entries) {
            final int? code = int.tryParse('${entry.key}');
            final Object? value = entry.value;
            if (code != null && value is String) {
              changes[code] = value;
            }
          }
          final int written = await _service.writeSettings(changes);
          _reply(id, <String, Object?>{GrblWorkerKey.written: written});
        case GrblWorkerCommand.setWorkZero:
          final Object? axes = raw[GrblWorkerKey.axes];
          if (axes is! List) {
            throw const GrblWorkerException(
              'El comando setWorkZero requiere la lista de ejes.',
            );
          }
          _service.setWorkZero(
            x: axes.contains('x'),
            y: axes.contains('y'),
            z: axes.contains('z'),
          );
          _reply(id);
        case GrblWorkerCommand.readSettings:
          final GrblSettings settings = await _service.readSettings();
          _reply(id, settings.toJson());
        case GrblWorkerCommand.readParserState:
          final ParserState state = await _service.readParserState(
            direct: raw[GrblWorkerKey.direct] as bool? ?? false,
          );
          _reply(id, state.toJson());
        case GrblWorkerCommand.readOffsets:
          final WorkOffsets offsets = await _service.readOffsets(
            direct: raw[GrblWorkerKey.direct] as bool? ?? false,
          );
          _reply(id, offsets.toJson());
        case GrblWorkerCommand.stop:
          await _stopWithPersistence(id);
        case GrblWorkerCommand.persistDone:
          final Completer<void>? ack = _persistAck;
          _persistAck = null;
          if (ack != null && !ack.isCompleted) {
            ack.complete();
          }
        case GrblWorkerCommand.dispose:
          _reply(id);
          await dispose();
        default:
          throw GrblWorkerException('Comando desconocido: $command');
      }
    } catch (error) {
      _replyError(id, error);
    }
  }

  /// Pausa, exige la confirmación de guardado y solo entonces resetea.
  Future<void> _stopWithPersistence(Object? id) async {
    await _service.stopJob(
      persistProgress: (StatusReport? report) => _requestPersistence(id),
    );
    _service.cancelProgram();
    _reply(id);
  }

  /// Pide al cliente que guarde el progreso y espera su confirmación.
  ///
  /// Lee `$G` y `$#` con la máquina en `Hold` (quieta) para que el punto de
  /// reanudación incluya el estado modal y los offsets (SEG-05).
  Future<void> _requestPersistence(Object? id) async {
    ParserState? parserState;
    WorkOffsets? offsets;
    try {
      parserState = await _service.readParserState(
        direct: true,
        timeout: const Duration(milliseconds: 900),
      );
    } on GrblProtocolException {
      parserState = null;
    }
    try {
      offsets = await _service.readOffsets(
        direct: true,
        timeout: const Duration(milliseconds: 900),
      );
    } on GrblProtocolException {
      offsets = null;
    }

    final Completer<void> ack = Completer<void>();
    _persistAck = ack;
    toClient.send(<String, Object?>{
      GrblWorkerKey.event: GrblWorkerEvent.persistRequest,
      GrblWorkerKey.id: id,
      GrblWorkerKey.line: _service.lastStatus?.raw,
      GrblWorkerKey.parserState: parserState?.toJson(),
      GrblWorkerKey.offsets: offsets?.toJson(),
    });
    await ack.future.timeout(
      persistTimeout,
      onTimeout: () => throw const GrblSafetyException(
        'El cliente no confirmó el guardado del progreso: no se envía el '
        'soft reset y la máquina permanece en Hold con la herramienta '
        'apagada.',
      ),
    );
  }

  void _reply(Object? id, [Map<String, Object?>? data]) {
    final Map<String, Object?> message = <String, Object?>{
      GrblWorkerKey.event: GrblWorkerEvent.result,
      GrblWorkerKey.id: id,
    };
    if (data != null) {
      message[GrblWorkerKey.data] = data;
    }
    toClient.send(message);
  }

  void _replyError(Object? id, Object error) {
    toClient.send(<String, Object?>{
      GrblWorkerKey.event: GrblWorkerEvent.error,
      GrblWorkerKey.id: id,
      GrblWorkerKey.message: error.toString(),
    });
  }

  /// Cierra el servicio y deja de escuchar comandos.
  Future<void> dispose() async {
    await _statusSub?.cancel();
    await _messageSub?.cancel();
    await _progressSub?.cancel();
    await _consoleSub?.cancel();
    await _service.dispose();
    _inbox?.close();
  }
}

/// Traduce el nombre de eje que llega en el mensaje (`x`, `y`, `z`) a [MachineAxis].
MachineAxis? _axisByName(Object? name) {
  for (final MachineAxis axis in MachineAxis.values) {
    if (axis.name == name) {
      return axis;
    }
  }
  return null;
}
