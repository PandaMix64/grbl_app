import 'dart:async';

import '../../core/grbl/grbl_constants.dart';
import '../../domain/entities/machine_state.dart';
import '../../domain/entities/status_report.dart';
import '../../domain/repositories/serial_port_repository.dart';
import 'character_counting_buffer.dart';

/// Error de secuencia de seguridad: la máquina no quedó en el estado esperado.
class GrblSafetyException implements Exception {
  const GrblSafetyException(this.message);

  final String message;

  @override
  String toString() => 'GrblSafetyException: $message';
}

/// Servicio de comunicación con GRBL v1.1h.
///
/// Concentra el streaming por conteo de caracteres, la telemetría y las
/// secuencias de `docs/seguridad_operativa.md`. Depende solo de
/// [SerialPortRepository], por lo que se prueba con un puerto falso.
///
/// **Ningún widget debe escribir bytes directamente**: todo pasa por aquí.
class GrblSerialService {
  GrblSerialService({
    required SerialPortRepository port,
    int bufferSize = kDefaultRxBufferSize,
    Duration defaultTimeout = const Duration(seconds: 5),
  }) : this._(
         port,
         CharacterCountingBuffer(bufferSize: bufferSize),
         defaultTimeout,
       );

  GrblSerialService._(this._port, this._buffer, this._defaultTimeout);

  final SerialPortRepository _port;
  final CharacterCountingBuffer _buffer;
  final Duration _defaultTimeout;

  final StreamController<StatusReport> _statusController =
      StreamController<StatusReport>.broadcast();
  final StreamController<String> _messagesController =
      StreamController<String>.broadcast();
  final StreamController<String> _bannerController =
      StreamController<String>.broadcast();

  StreamSubscription<String>? _subscription;
  Timer? _pollTimer;
  StatusReport? _lastStatus;
  int _sentBlocks = 0;

  /// Telemetría parseada; emite cada `<...>` recibido.
  Stream<StatusReport> get statusReports => _statusController.stream;

  /// Líneas informativas: `error:`, `ALARM:`, `[MSG:...]` y avisos propios.
  Stream<String> get messages => _messagesController.stream;

  /// Banner de arranque (`Grbl 1.1h ['$' for help]`), útil tras un reset.
  Stream<String> get banners => _bannerController.stream;

  /// Último reporte recibido, o `null` si aún no hay telemetría.
  StatusReport? get lastStatus => _lastStatus;

  /// Estado de máquina según la última telemetría.
  MachineState get state => _lastStatus?.state ?? MachineState.unknown;

  /// Control de flujo, expuesto para diagnóstico y tests.
  CharacterCountingBuffer get buffer => _buffer;

  /// Bloques enviados desde la conexión.
  int get sentBlocks => _sentBlocks;

  bool get isConnected => _port.isOpen;

  /// Abre el puerto y empieza a escuchar respuestas.
  Future<void> connect({
    required String portName,
    int baudRate = kDefaultBaudRate,
  }) async {
    if (isConnected) {
      throw const SerialPortException('El puerto ya está abierto.');
    }
    await _port.open(portName: portName, baudRate: baudRate);
    _subscription = _port.lines.listen(
      _onLine,
      onError: (Object error) => _emitMessage('Puerto serial: $error'),
    );
  }

  /// Cierra el puerto y reinicia el control de flujo.
  Future<void> disconnect() async {
    _stopStatusPolling();
    await _subscription?.cancel();
    _subscription = null;
    _buffer.reset();
    if (_port.isOpen) {
      await _port.close();
    }
  }

  /// Sondea el estado con `?` a la frecuencia indicada (200 ms ≈ 5 Hz).
  ///
  /// GRBL no publica una tasa oficial; 5–10 Hz es la práctica segura. Sondear
  /// más rápido compite con el streaming por el mismo enlace.
  void startStatusPolling({
    Duration interval = const Duration(milliseconds: 200),
  }) {
    _stopStatusPolling();
    _pollTimer = Timer.periodic(interval, (_) => requestStatus());
  }

  void _stopStatusPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Encola un programa completo y empieza a enviarlo.
  void streamGcode(Iterable<String> blocks) {
    _requireConnected();
    _buffer.enqueueAll(blocks);
    _pump();
  }

  /// Encola una sola línea (G-code o comando `$`).
  void enqueue(String line) {
    _requireConnected();
    _buffer.enqueue(line);
    _pump();
  }

  /// Solicita un status report (`?`). Comando en tiempo real.
  void requestStatus() {
    if (isConnected) {
      _port.writeRealtime(GrblRealtime.statusReport);
    }
  }

  void _pump() {
    for (final String line in _buffer.drainSendable()) {
      _port.writeLine(line);
      _sentBlocks++;
    }
  }

  void _onLine(String line) {
    final String text = line.trim();
    if (text.isEmpty) {
      return;
    }

    if (text == 'ok') {
      _buffer.acknowledgeOk();
      _pump();
      return;
    }
    if (text.startsWith('error')) {
      // Un error libera espacio igual que un ok; si no, el flujo se congela.
      _buffer.acknowledgeError();
      _emitMessage(text);
      _pump();
      return;
    }
    if (text.startsWith('<')) {
      try {
        final StatusReport report = StatusReport.parse(text);
        _lastStatus = report;
        if (!_statusController.isClosed) {
          _statusController.add(report);
        }
      } on FormatException catch (error) {
        _emitMessage('Status report ilegible: ${error.message}');
      }
      return;
    }
    if (text.startsWith('Grbl ')) {
      if (!_bannerController.isClosed) {
        _bannerController.add(text);
      }
      return;
    }
    if (text.startsWith('ALARM') || text.startsWith('[MSG:')) {
      _emitMessage(text);
    }
  }

  void _emitMessage(String message) {
    if (!_messagesController.isClosed) {
      _messagesController.add(message);
    }
  }

  void _requireConnected() {
    if (!isConnected) {
      throw const SerialPortException('No hay puerto abierto.');
    }
  }

  /// Secuencia de **pausa segura** (§3 de `docs/seguridad_operativa.md`).
  ///
  /// `!` → estado `Hold` → `0x9E` (spindle stop) → confirmación de `S:0`.
  /// El feed hold por sí solo **no apaga** la herramienta.
  Future<StatusReport> pauseSafely({Duration? timeout}) async {
    _requireConnected();
    final Duration limit = timeout ?? _defaultTimeout;

    if (state == MachineState.hold) {
      await _ensureToolOff();
      return _lastStatus!;
    }
    if (!state.isMoving && state != MachineState.door) {
      throw GrblSafetyException(
        'No hay movimiento que pausar (estado ${state.label}).',
      );
    }

    _port.writeRealtime(GrblRealtime.feedHold);
    await _waitFor(
      (StatusReport report) => report.state == MachineState.hold,
      timeout: limit,
      onTimeout:
          'La máquina no entró en Hold (estado ${state.label}). '
          'Considera detener el trabajo.',
    );
    await _ensureToolOff();
    return _lastStatus!;
  }

  /// Apaga la herramienta con `0x9E` y verifica que la consigna sea 0.
  ///
  /// `0x9E` solo tiene efecto en `Hold`; por eso nunca se envía `M5` durante
  /// `Run` (quedaría encolado y podría ejecutarse más tarde).
  Future<void> _ensureToolOff() async {
    if (_lastStatus != null && !_lastStatus!.isSpindleOn) {
      return;
    }
    for (int attempt = 0; attempt < 2; attempt++) {
      _port.writeRealtime(GrblRealtime.spindleStopToggle);
      try {
        await _waitFor(
          (StatusReport report) =>
              report.state == MachineState.hold && !report.isSpindleOn,
          timeout: const Duration(seconds: 1),
          onTimeout: 'La herramienta no se apagó.',
        );
        return;
      } on GrblSafetyException {
        // Segundo intento antes de rendirse.
      }
    }
    throw const GrblSafetyException(
      'La herramienta sigue activa tras la pausa. No cierres la aplicación: '
      'acciona el paro de emergencia y verifica la salida física.',
    );
  }

  /// Secuencia de **reanudación segura** (§6).
  ///
  /// Encola el bloque de reactivación de la herramienta, espera la
  /// estabilización y solo entonces envía `~` (cycle start).
  Future<void> resumeAfterPause({
    required String toolOnLine,
    Duration settle = const Duration(seconds: 4),
    Duration? timeout,
  }) async {
    _requireConnected();
    if (state != MachineState.hold && state != MachineState.door) {
      throw GrblSafetyException(
        'Solo se reanuda desde Hold o Door (estado ${state.label}).',
      );
    }
    enqueue(toolOnLine);
    await Future<void>.delayed(settle);
    _port.writeRealtime(GrblRealtime.cycleStart);
    await _waitFor(
      (StatusReport report) => report.state == MachineState.run,
      timeout: timeout ?? _defaultTimeout,
      onTimeout: 'La máquina no reanudó (estado ${state.label}).',
    );
  }

  /// Cancela el jog en curso (§4).
  ///
  /// Si la máquina no está en `Jog`, el comando se ignora y se registra
  /// (SEG-04), porque `serial.c` solo atiende `0x85` en ese estado.
  Future<void> cancelJog({Duration? timeout}) async {
    _requireConnected();
    if (state != MachineState.jog) {
      _emitMessage('Jog cancel ignorado: la máquina está en ${state.label}.');
      return;
    }
    _port.writeRealtime(GrblRealtime.jogCancel);
    _buffer.reset();
    await _waitFor(
      (StatusReport report) => report.state == MachineState.idle,
      timeout: timeout ?? const Duration(seconds: 1),
      onTimeout: 'El jog no se detuvo.',
    );
  }

  /// Detiene el trabajo (§5).
  ///
  /// Exige persistir el progreso **antes** del soft reset (SEG-03): el callback
  /// es obligatorio para que ningún camino de código alcance `0x18` sin
  /// guardar el punto de reanudación.
  Future<void> stopJob({
    required Future<void> Function(StatusReport? report) persistProgress,
    Duration? timeout,
  }) async {
    _requireConnected();
    await pauseSafely(timeout: timeout);
    await persistProgress(_lastStatus);
    _buffer.reset();

    final Future<String> banner = banners.first.timeout(
      timeout ?? const Duration(seconds: 3),
      onTimeout: () => throw const GrblSafetyException(
        'GRBL no respondió al soft reset. Reconecta el puerto.',
      ),
    );
    _port.writeRealtime(GrblRealtime.softReset);
    await banner;

    // Tras un reset en movimiento, GRBL queda en ALARM:3; `$X` es idempotente.
    enqueue(r'$X');
  }

  /// Desbloquea una alarma (`$X`). No mueve la máquina.
  void unlock() => enqueue(r'$X');

  /// Ejecuta el ciclo de homing (`$H`).
  void home() => enqueue(r'$H');

  /// Alterna el spindle stop (solo tiene efecto en `Hold`).
  void toggleSpindleStop() {
    _requireConnected();
    _port.writeRealtime(GrblRealtime.spindleStopToggle);
  }

  /// Safety door (`0x84`): parada con reanudación controlada.
  void triggerSafetyDoor() {
    _requireConnected();
    _port.writeRealtime(GrblRealtime.safetyDoor);
  }

  Future<StatusReport> _waitFor(
    bool Function(StatusReport report) predicate, {
    required Duration timeout,
    required String onTimeout,
  }) {
    return statusReports
        .firstWhere(predicate)
        .timeout(
          timeout,
          onTimeout: () => throw GrblSafetyException(onTimeout),
        );
  }

  /// Libera los recursos del servicio.
  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
    await _messagesController.close();
    await _bannerController.close();
  }
}
