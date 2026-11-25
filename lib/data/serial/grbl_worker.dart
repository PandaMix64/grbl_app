import 'dart:async';
import 'dart:isolate';

import '../../core/grbl/grbl_constants.dart';
import '../../domain/entities/grbl_handshake.dart';
import '../../domain/entities/grbl_settings.dart';
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
  }) : _service = GrblSerialService(port: port, bufferSize: bufferSize) {
    _forwardEvents();
  }

  final SendPort toClient;
  final GrblSerialService _service;

  ReceivePort? _inbox;
  StreamSubscription<StatusReport>? _statusSub;
  StreamSubscription<String>? _messageSub;
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
        case GrblWorkerCommand.home:
          _service.home();
          _reply(id);
        case GrblWorkerCommand.readSettings:
          final GrblSettings settings = await _service.readSettings();
          _reply(id, settings.toJson());
        case GrblWorkerCommand.readParserState:
          final ParserState state = await _service.readParserState();
          _reply(id, state.toJson());
        case GrblWorkerCommand.readOffsets:
          final WorkOffsets offsets = await _service.readOffsets();
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
      persistProgress: (StatusReport? report) async {
        final Completer<void> ack = Completer<void>();
        _persistAck = ack;
        toClient.send(<String, Object?>{
          GrblWorkerKey.event: GrblWorkerEvent.persistRequest,
          GrblWorkerKey.id: id,
          GrblWorkerKey.line: report?.raw,
        });
        await ack.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw const GrblSafetyException(
            'El cliente no confirmó el guardado del progreso: no se envía el '
            'soft reset y la máquina permanece en Hold con la herramienta '
            'apagada.',
          ),
        );
      },
    );
    _reply(id);
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
    await _service.dispose();
    _inbox?.close();
  }
}
