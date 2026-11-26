import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/grbl/grbl_constants.dart';
import '../../data/serial/grbl_worker_client.dart';
import '../../domain/entities/grbl_handshake.dart';
import '../../domain/entities/grbl_settings.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/entities/machine_state.dart';
import '../../domain/entities/status_report.dart';
import '../../domain/repositories/serial_port_repository.dart';
import '../../domain/services/profile_consistency.dart';

/// Estado de la pantalla de conexión.
@immutable
class ConnectionUiState {
  const ConnectionUiState({
    this.ports = const <SerialPortInfo>[],
    this.selectedPort,
    this.baudRate = kDefaultBaudRate,
    this.isBusy = false,
    this.isConnected = false,
    this.machineState = MachineState.unknown,
    this.handshake,
    this.issues = const <ConsistencyIssue>[],
    this.error,
    this.lastMessage,
    this.workPosition,
    this.positionIsLive = false,
  });

  final List<SerialPortInfo> ports;
  final String? selectedPort;
  final int baudRate;
  final bool isBusy;
  final bool isConnected;
  final MachineState machineState;

  /// Instantánea del handshake (versión, búfer real, `$$`, `$G`, `$#`).
  final GrblHandshake? handshake;

  /// Discrepancias entre el perfil activo y la EEPROM.
  final List<ConsistencyIssue> issues;

  final String? error;
  final String? lastMessage;

  /// Última posición de trabajo conocida.
  ///
  /// GRBL no incluye `WCO` en todos los reportes (`$10` y cambio de offset), así
  /// que la posición se guarda y se refresca con cada lectura: borrarla dejaba
  /// el cabezal del visor y el origen sin datos casi todo el tiempo.
  final List<double>? workPosition;

  /// `true` si [workPosition] viene del reporte más reciente.
  final bool positionIsLive;

  /// `true` si alguna discrepancia impide ejecutar trabajo.
  bool get hasBlockingIssues => ProfileConsistency.hasBlocking(issues);

  ConnectionUiState copyWith({
    List<SerialPortInfo>? ports,
    String? selectedPort,
    int? baudRate,
    bool? isBusy,
    bool? isConnected,
    MachineState? machineState,
    GrblHandshake? handshake,
    List<ConsistencyIssue>? issues,
    String? error,
    String? lastMessage,
    List<double>? workPosition,
    bool? positionIsLive,
    bool clearError = false,
    bool clearHandshake = false,
    bool clearSelectedPort = false,
  }) {
    return ConnectionUiState(
      ports: ports ?? this.ports,
      selectedPort: clearSelectedPort
          ? null
          : (selectedPort ?? this.selectedPort),
      baudRate: baudRate ?? this.baudRate,
      isBusy: isBusy ?? this.isBusy,
      isConnected: isConnected ?? this.isConnected,
      machineState: machineState ?? this.machineState,
      handshake: clearHandshake ? null : (handshake ?? this.handshake),
      issues: issues ?? this.issues,
      error: clearError ? null : (error ?? this.error),
      lastMessage: lastMessage ?? this.lastMessage,
      workPosition: workPosition ?? this.workPosition,
      positionIsLive: positionIsLive ?? this.positionIsLive,
    );
  }
}

/// Controlador de conexión: enumera puertos, conecta con handshake y refleja la
/// telemetría. No envía bytes directamente: todo pasa por el worker.
class ConnectionController extends Notifier<ConnectionUiState> {
  StreamSubscription<StatusReport>? _statusSub;
  StreamSubscription<String>? _messageSub;

  /// Último `WCO` conocido, para resolver `WPos = MPos - WCO` cuando GRBL no lo
  /// incluye en el reporte.
  List<double>? _lastWco;

  /// Última posición de trabajo válida, conservada entre reportes.
  List<double>? _lastWorkPosition;

  @override
  ConnectionUiState build() {
    ref.onDispose(() {
      unawaited(_statusSub?.cancel());
      unawaited(_messageSub?.cancel());
    });
    return const ConnectionUiState();
  }

  void selectPort(String? name) => state = state.copyWith(selectedPort: name);

  void selectBaudRate(int baudRate) =>
      state = state.copyWith(baudRate: baudRate);

  /// Mensaje único para destinos sin host USB (iOS, web).
  static const String serialUnsupportedMessage =
      'Esta plataforma no expone puertos USB serie: prepara el trabajo aquí '
      '(CAM, plóter, visor) y conéctate a la máquina desde Android o la versión '
      'de escritorio.';

  /// Enumeración de puertos (FFI dentro del worker).
  Future<void> refreshPorts() async {
    if (!ref.read(serialSupportProvider)) {
      state = state.copyWith(
        ports: const <SerialPortInfo>[],
        clearSelectedPort: true,
        error: serialUnsupportedMessage,
      );
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final GrblWorkerClient client = await ref.read(grblWorkerProvider.future);
      final List<SerialPortInfo> ports = await client.listPorts();
      state = state.copyWith(
        ports: ports,
        isBusy: false,
        selectedPort:
            state.selectedPort ?? (ports.isEmpty ? null : ports.first.name),
      );
    } on Object catch (error) {
      state = state.copyWith(
        isBusy: false,
        error: 'No se pudieron listar los puertos: $error',
      );
    }
  }

  /// Conecta, ejecuta el handshake y compara el perfil activo con la EEPROM.
  Future<void> connect() async {
    if (!ref.read(serialSupportProvider)) {
      state = state.copyWith(error: serialUnsupportedMessage);
      return;
    }
    final String? port = state.selectedPort;
    if (port == null || port.isEmpty) {
      state = state.copyWith(error: 'Selecciona un puerto serial.');
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final GrblWorkerClient client = await ref.read(grblWorkerProvider.future);
      final MachineProfile? profile = await ref.read(
        activeProfileProvider.future,
      );

      final GrblHandshake handshake = await client.connect(
        portName: port,
        baudRate: state.baudRate,
      );
      await client.startPolling();

      _statusSub = client.statusReports.listen(_onStatusReport);
      _messageSub = client.messages.listen((String message) {
        state = state.copyWith(lastMessage: message);
      });

      // Semilla del `WCO` con el `$#` del handshake (G54): el primer reporte
      // puede venir sin `WCO` y aun así resolverse.
      _lastWorkPosition = null;
      _lastWco = handshake.offsets['G54'];

      final List<ConsistencyIssue> issues = profile == null
          ? const <ConsistencyIssue>[]
          : ProfileConsistency.check(
              profile: profile,
              settings: handshake.settings,
              parserState: handshake.parserState,
            );

      state = state.copyWith(
        isConnected: true,
        isBusy: false,
        handshake: handshake,
        issues: issues,
        machineState: MachineState.idle,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isBusy: false,
        isConnected: false,
        error: 'Conexión fallida: $error',
      );
    }
  }

  /// Recalcula las discrepancias entre el perfil activo y una lectura fresca de
  /// la EEPROM.
  ///
  /// Sin esto, el aviso solo aparecía al conectar: refrescar `$$` o aplicar el
  /// perfil dejaba los `issues` desactualizados.
  Future<void> revalidate(GrblSettings settings) async {
    final MachineProfile? profile = await ref.read(
      activeProfileProvider.future,
    );
    if (profile == null) {
      state = state.copyWith(issues: const <ConsistencyIssue>[]);
      return;
    }
    state = state.copyWith(
      issues: ProfileConsistency.check(
        profile: profile,
        settings: settings,
        parserState: state.handshake?.parserState,
      ),
    );
  }

  /// Refresca el estado y la posición con un status report.
  ///
  /// GRBL omite `WCO` en la mayoría de reportes, así que se memoriza el último
  /// para resolver `WPos = MPos - WCO`. Si el reporte no trae posición alguna se
  /// conserva la última conocida en lugar de borrarla: el cabezal del visor y el
  /// cero de trabajo necesitan ese dato de forma continua.
  void _onStatusReport(StatusReport report) {
    final List<double>? wco = report.workCoordinateOffset;
    if (wco != null && wco.length >= 2) {
      _lastWco = wco;
    }
    List<double>? resolved = report.resolvedWorkPosition;
    final List<double>? machine = report.machinePosition;
    final List<double>? offset = _lastWco;
    if (resolved == null && machine != null && offset != null) {
      resolved = <double>[
        for (int i = 0; i < machine.length; i++)
          machine[i] - (i < offset.length ? offset[i] : 0.0),
      ];
    }
    if (resolved != null) {
      _lastWorkPosition = resolved;
    }
    state = state.copyWith(
      machineState: report.state,
      workPosition: _lastWorkPosition,
      positionIsLive: resolved != null,
    );
  }

  /// Cierra el puerto y detiene la telemetría.
  Future<void> disconnect() async {
    state = state.copyWith(isBusy: true, clearError: true);
    await _statusSub?.cancel();
    _statusSub = null;
    await _messageSub?.cancel();
    _messageSub = null;
    try {
      final GrblWorkerClient client = await ref.read(grblWorkerProvider.future);
      await client.disconnect();
    } on Object catch (error) {
      state = state.copyWith(lastMessage: 'Al desconectar: $error');
    }
    state = ConnectionUiState(
      ports: state.ports,
      selectedPort: state.selectedPort,
      baudRate: state.baudRate,
    );
    _lastWco = null;
    _lastWorkPosition = null;
  }
}

/// Estado de conexión observable por la UI.
final NotifierProvider<ConnectionController, ConnectionUiState>
connectionControllerProvider =
    NotifierProvider<ConnectionController, ConnectionUiState>(
      ConnectionController.new,
    );
