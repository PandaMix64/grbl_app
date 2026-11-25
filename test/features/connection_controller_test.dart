import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/domain/entities/machine_profile.dart';
import 'package:grbl_app/domain/entities/machine_state.dart';
import 'package:grbl_app/domain/services/profile_consistency.dart';
import 'package:grbl_app/features/connection/connection_controller.dart';

import '../helpers/fake_serial_port.dart';

void main() {
  late FakeSerialPort port;
  late GrblWorkerClient client;
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    port = FakeSerialPort();
    client = GrblWorkerClient.inProcess(port: port);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        grblWorkerProvider.overrideWith((Ref ref) => client),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await client.dispose();
    await database.close();
  });

  ConnectionController controller() =>
      container.read(connectionControllerProvider.notifier);

  ConnectionUiState state() => container.read(connectionControllerProvider);

  test('enumera puertos y selecciona el primero', () async {
    await controller().refreshPorts();

    expect(state().ports, hasLength(1));
    expect(state().ports.first.name, 'FAKE0');
    expect(state().selectedPort, 'FAKE0');
    expect(state().error, isNull);
    expect(state().isBusy, isFalse);
  });

  test('sin soporte serie (Android) no enumera ni abre el puerto', () async {
    final ProviderContainer android = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        grblWorkerProvider.overrideWith((Ref ref) => client),
        serialSupportProvider.overrideWithValue(false),
      ],
    );
    addTearDown(android.dispose);

    await android.read(connectionControllerProvider.notifier).refreshPorts();

    ConnectionUiState snapshot = android.read(connectionControllerProvider);
    expect(snapshot.ports, isEmpty);
    expect(snapshot.selectedPort, isNull);
    expect(snapshot.error, ConnectionController.serialUnsupportedMessage);
    expect(snapshot.isBusy, isFalse);

    await android.read(connectionControllerProvider.notifier).connect();

    snapshot = android.read(connectionControllerProvider);
    expect(snapshot.isConnected, isFalse);
    expect(snapshot.error, ConnectionController.serialUnsupportedMessage);
    expect(port.writtenLines, isEmpty);
  });

  test('conecta, hace el handshake y aplica el búfer real', () async {
    await controller().refreshPorts();

    await controller().connect();

    expect(state().isConnected, isTrue);
    expect(state().machineState, MachineState.idle);
    expect(state().handshake, isNotNull);
    expect(state().handshake!.buildInfo!.version, '1.1h');
    expect(state().handshake!.rxBufferSize, 128);
    expect(state().error, isNull);

    await controller().disconnect();

    expect(state().isConnected, isFalse);
    expect(state().handshake, isNull);
  });

  test('sin puerto seleccionado no intenta conectar', () async {
    await controller().connect();

    expect(state().isConnected, isFalse);
    expect(state().error, contains('Selecciona un puerto'));
  });

  test('avisa cuando el perfil láser no coincide con la EEPROM', () async {
    await database.upsertProfile(
      const MachineProfile(
        id: 'p1',
        name: '3018',
        tool: ToolType.laser,
        travelXmm: 300,
        travelYmm: 180,
        travelZmm: 45,
      ),
    );
    // Simula una EEPROM sin modo láser configurado.
    port.settingsLines = port.settingsLines
        .where((String line) => !line.startsWith(r'$32'))
        .toList();

    await controller().refreshPorts();
    await controller().connect();

    expect(state().hasBlockingIssues, isTrue);
    expect(
      state().issues.map((ConsistencyIssue issue) => issue.code),
      contains('LASER_MODE_OFF'),
    );
  });

  test('propaga el estado de la máquina desde la telemetría', () async {
    await controller().refreshPorts();
    await controller().connect();

    port.state = 'Hold';
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(state().machineState, MachineState.hold);
  });
}
