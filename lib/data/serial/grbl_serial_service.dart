import 'dart:async';

import '../../core/grbl/grbl_constants.dart';
import '../../domain/entities/build_info.dart';
import '../../domain/entities/grbl_handshake.dart';
import '../../domain/entities/grbl_settings.dart';
import '../../domain/entities/jog_command.dart';
import '../../domain/entities/machine_state.dart';
import '../../domain/entities/parser_state.dart';
import '../../domain/entities/status_report.dart';
import '../../domain/entities/work_offsets.dart';
import '../../domain/repositories/serial_port_repository.dart';
import 'character_counting_buffer.dart';

/// Error de secuencia de seguridad: la máquina no quedó en el estado esperado.
class GrblSafetyException implements Exception {
  const GrblSafetyException(this.message);

  final String message;

  @override
  String toString() => 'GrblSafetyException: $message';
}

/// Error de protocolo: GRBL respondió con `error:` o no respondió a una consulta.
class GrblProtocolException implements Exception {
  const GrblProtocolException(this.message);

  final String message;

  @override
  String toString() => 'GrblProtocolException: $message';
}

/// Consulta en curso (`$$`, `$G`, `$#`, `$I`) que acumula líneas hasta el `ok`.
class _LineQuery {
  _LineQuery({required this.accept});

  final bool Function(String line) accept;
  final List<String> lines = <String>[];
  final Completer<List<String>> completer = Completer<List<String>>();
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
  _LineQuery? _query;

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
  ///
  /// La suscripción se crea **antes** de abrir: GRBL imprime su banner al
  /// recibir el reset del DTR y, si se escuchara después, ese primer mensaje se
  /// perdería (los streams broadcast descartan eventos sin oyentes).
  Future<void> connect({
    required String portName,
    int baudRate = kDefaultBaudRate,
  }) async {
    if (isConnected) {
      throw const SerialPortException('El puerto ya está abierto.');
    }
    _subscription = _port.lines.listen(
      _onLine,
      onError: (Object error) => _emitMessage('Puerto serial: $error'),
    );
    try {
      await _port.open(portName: portName, baudRate: baudRate);
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      rethrow;
    }
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

  /// Detiene el sondeo periódico de estado.
  void stopStatusPolling() => _stopStatusPolling();

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
      _completeQuery();
      _pump();
      return;
    }
    if (text.startsWith('error')) {
      // Un error libera espacio igual que un ok; si no, el flujo se congela.
      _buffer.acknowledgeError();
      _failQuery(text);
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
    final _LineQuery? query = _query;
    if (query != null && query.accept(text)) {
      query.lines.add(text);
      return;
    }
    if (text.startsWith('ALARM') || text.startsWith('[MSG:')) {
      _emitMessage(text);
    }
  }

  void _completeQuery() {
    final _LineQuery? query = _query;
    if (query == null) {
      return;
    }
    _query = null;
    if (!query.completer.isCompleted) {
      query.completer.complete(List<String>.of(query.lines));
    }
  }

  void _failQuery(String reason) {
    final _LineQuery? query = _query;
    if (query == null) {
      return;
    }
    _query = null;
    if (!query.completer.isCompleted) {
      query.completer.completeError(GrblProtocolException(reason));
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

  /// Puertos seriales disponibles en el sistema.
  Future<List<SerialPortInfo>> listPorts() => _port.listPorts();

  /// Fija el cero de trabajo actual con `G10 L20 P1`.
  ///
  /// Es la forma recomendada por GRBL: modifica el offset de G54 y **persiste**
  /// en EEPROM, a diferencia de `G92` (no persistente y desaconsejado).
  void setWorkZero({bool x = true, bool y = true, bool z = true}) {
    _requireConnected();
    if (!x && !y && !z) {
      throw ArgumentError('Selecciona al menos un eje para fijar el origen.');
    }
    if (state.isBlocked) {
      throw GrblSafetyException(
        'La máquina está en ${state.label}: desbloquea con \$X y haz homing '
        'antes de fijar el origen de trabajo.',
      );
    }
    final List<String> words = <String>['G10', 'L20', 'P1'];
    if (x) {
      words.add('X0');
    }
    if (y) {
      words.add('Y0');
    }
    if (z) {
      words.add('Z0');
    }
    _buffer.enqueue(words.join(' '));
    _pump();
  }

  /// Ejecuta un jog (`$J=`).
  ///
  /// GRBL solo acepta jogs en `Idle` o `Jog`; en cualquier otro estado devolvería
  /// `error:` y el movimiento quedaría rechazado, por lo que se corta antes.
  void jog(JogCommand command) {
    _requireConnected();
    if (!state.allowsJog) {
      throw GrblSafetyException(
        'El jog solo se acepta en Idle o Jog (estado actual: ${state.label}).',
      );
    }
    _buffer.enqueue(command.build());
    _pump();
  }

  /// Escribe parámetros `$x=valor` uno a uno, esperando el `ok` de cada uno.
  ///
  /// El llamador debe calcular los cambios con `GrblSettings.diff` para enviar
  /// **solo** lo que difiere: cada escritura consume un ciclo de EEPROM.
  /// Devuelve cuántos parámetros se escribieron.
  Future<int> writeSettings(
    Map<int, String> changes, {
    Duration? timeout,
  }) async {
    _requireConnected();
    if (changes.isEmpty) {
      return 0;
    }
    int written = 0;
    for (final MapEntry<int, String> change in changes.entries) {
      await _request(
        '${r'$'}${change.key}=${change.value}',
        accept: (String line) => false,
        timeout: timeout,
      );
      written++;
    }
    _emitMessage('Parámetros escritos en la EEPROM: $written.');
    return written;
  }

  /// Tamaño actual del búfer de recepción usado para el control de flujo.
  int get rxBufferSize => _buffer.bufferSize;

  /// Aplica el tamaño de búfer detectado con `$I` (no asumir 128 B).
  ///
  /// Devuelve `true` si el tamaño cambió.
  bool applyRxBufferSize(int bytes) {
    final bool changed = _buffer.resize(bytes);
    if (changed && !_buffer.isBusy) {
      _emitMessage(
        'Búfer RX detectado: $bytes B (presupuesto útil ${_buffer.budget} B).',
      );
    }
    return changed;
  }

  /// Ejecuta una consulta de sistema (`$$`, `$G`, `$#`, `$I`) y acumula sus
  /// líneas hasta el `ok` final.
  Future<List<String>> _request(
    String command, {
    required bool Function(String line) accept,
    Duration? timeout,
  }) async {
    _requireConnected();
    if (state.isMoving) {
      throw const GrblSafetyException(
        'No se consultan parámetros con la máquina en movimiento.',
      );
    }
    if (_query != null) {
      throw const GrblProtocolException(
        'Ya hay una consulta de parámetros en curso.',
      );
    }
    final _LineQuery query = _LineQuery(accept: accept);
    _query = query;
    enqueue(command);
    try {
      return await query.completer.future.timeout(
        timeout ?? _defaultTimeout,
        onTimeout: () =>
            throw GrblProtocolException('GRBL no respondió a "$command".'),
      );
    } finally {
      if (identical(_query, query)) {
        _query = null;
      }
    }
  }

  /// Lee la información de compilación (`$I`), incluido el tamaño real del
  /// búfer RX. Devuelve `null` si el firmware no la expone.
  Future<BuildInfo?> readBuildInfo({Duration? timeout}) async {
    final List<String> lines = await _request(
      r'$I',
      accept: (String line) =>
          line.startsWith('[VER:') || line.startsWith('[OPT:'),
      timeout: timeout,
    );
    if (lines.isEmpty) {
      return null;
    }
    try {
      return BuildInfo.fromLines(lines);
    } on FormatException catch (error) {
      _emitMessage('Build info ilegible: ${error.message}');
      return null;
    }
  }

  /// Lee todos los parámetros `$x=valor` de la EEPROM (`$$`).
  Future<GrblSettings> readSettings({Duration? timeout}) async {
    final List<String> lines = await _request(
      r'$$',
      accept: (String line) => line.startsWith(r'$'),
      timeout: timeout,
    );
    return GrblSettings.parse(lines.join('\n'));
  }

  /// Lee el estado modal del parser (`$G`).
  Future<ParserState> readParserState({Duration? timeout}) async {
    final List<String> lines = await _request(
      r'$G',
      accept: (String line) => line.startsWith('[GC:'),
      timeout: timeout,
    );
    if (lines.isEmpty) {
      throw const GrblProtocolException(
        'GRBL no devolvió el estado del parser.',
      );
    }
    return ParserState.parse(lines.first);
  }

  /// Lee los offsets de coordenadas (`$#`).
  Future<WorkOffsets> readOffsets({Duration? timeout}) async {
    final List<String> lines = await _request(
      r'$#',
      accept: (String line) =>
          line.startsWith('[') && !line.startsWith('[MSG:'),
      timeout: timeout,
    );
    return WorkOffsets.parse(lines);
  }

  /// Conecta y realiza el handshake completo: banner, `$I`, `$$`, `$G` y `$#`.
  ///
  /// Aplica el tamaño de búfer detectado antes de leer la EEPROM, de modo que
  /// el streaming posterior use el presupuesto real del firmware. Si la lectura
  /// de parámetros falla, cierra el puerto y propaga el error: operar con
  /// suposiciones sobre la EEPROM es más peligroso que no conectar.
  Future<GrblHandshake> connectAndIdentify({
    required String portName,
    int baudRate = kDefaultBaudRate,
    Duration bannerTimeout = const Duration(seconds: 3),
    Duration? requestTimeout,
  }) async {
    final Future<String> banner = banners.first.timeout(
      bannerTimeout,
      onTimeout: () => '',
    );
    await connect(portName: portName, baudRate: baudRate);
    final String bannerLine = await banner;
    startStatusPolling();

    // Espera al primer status report: sin él, `state` es `unknown` y acciones
    // como el jog se rechazarían aunque la máquina esté lista.
    try {
      await _waitFor(
        (StatusReport report) => true,
        timeout: const Duration(seconds: 2),
        onTimeout: 'Sin telemetría inicial.',
      );
    } on GrblSafetyException {
      // Algunos adaptadores tardan en arrancar; no se aborta la conexión.
    }

    BuildInfo? build;
    try {
      build = await readBuildInfo(timeout: requestTimeout);
    } on GrblProtocolException catch (error) {
      _emitMessage('No se pudo leer \$I: ${error.message}');
    }
    if (build != null) {
      applyRxBufferSize(build.rxBufferSize);
    }

    final GrblSettings settings;
    final ParserState parserState;
    final WorkOffsets offsets;
    try {
      settings = await readSettings(timeout: requestTimeout);
      parserState = await readParserState(timeout: requestTimeout);
      offsets = await readOffsets(timeout: requestTimeout);
    } on GrblProtocolException {
      await disconnect();
      rethrow;
    }

    return GrblHandshake(
      buildInfo: build,
      rxBufferSize: _buffer.bufferSize,
      settings: settings,
      parserState: parserState,
      offsets: offsets,
      bannerReceived: bannerLine.isNotEmpty,
    );
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
