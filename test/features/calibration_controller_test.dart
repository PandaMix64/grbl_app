import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/domain/entities/axis.dart';
import 'package:grbl_app/domain/entities/machine_profile.dart';
import 'package:grbl_app/features/calibration/calibration_controller.dart';
import 'package:grbl_app/features/connection/connection_controller.dart';

import '../helpers/fake_serial_port.dart';

void main() {
  late FakeSerialPort port;
  late GrblWorkerClient client;
  late AppDatabase database;
  late ProviderContainer container;

  const MachineProfile profile = MachineProfile(
    id: 'p1',
    name: '3018',
    tool: ToolType.laser,
    travelXmm: 300,
    travelYmm: 180,
    travelZmm: 45,
  );

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

  CalibrationController controller() =>
      container.read(calibrationControllerProvider.notifier);

  CalibrationUiState state() => container.read(calibrationControllerProvider);

  Future<void> connect() async {
    final ConnectionController connection = container.read(
      connectionControllerProvider.notifier,
    );
    await connection.refreshPorts();
    await connection.connect();
    expect(container.read(connectionControllerProvider).isConnected, isTrue);
  }

  group('perfiles', () {
    test('guarda, selecciona y elimina', () async {
      await controller().loadProfiles();
      expect(state().profiles, isEmpty);

      expect(await controller().saveProfile(profile), isTrue);
      expect(state().profiles, hasLength(1));
      expect(state().selectedProfileId, 'p1');

      await controller().deleteProfile('p1');
      expect(state().profiles, isEmpty);
      expect(state().selectedProfileId, isNull);
    });

    test('rechaza un perfil inválido sin tocar la base', () async {
      final bool saved = await controller().saveProfile(
        profile.copyWith(travelXmm: 0),
      );

      expect(saved, isFalse);
      expect(state().error, contains('dimensiones'));
      expect(await database.allProfiles(), isEmpty);
    });
  });

  group('parámetros de la EEPROM', () {
    test('sin conexión avisa en lugar de fallar', () async {
      await controller().refreshSettings();

      expect(state().settings, isNull);
      expect(state().error, contains('Conecta'));
    });

    test('lee la EEPROM y prepara el borrador', () async {
      await connect();

      await controller().refreshSettings();

      expect(state().settings, isNotNull);
      expect(state().draft.keys, contains(100));
      expect(state().pending, isEmpty);
      expect(state().settingsRevision, 1);
    });

    test('solo escribe los parámetros que cambian', () async {
      await connect();
      await controller().refreshSettings();

      controller().setDraftValue(100, '255.102');
      controller().setDraftValue(101, state().draft[101]!);

      expect(state().pending.keys, <int>[100]);

      final int written = await controller().applyDraft();

      expect(written, 1);
      expect(port.writtenLines, contains(r'$100=255.102'));
      expect(state().pending, isEmpty);
      expect(state().settings!.stepsPerMm(MachineAxis.x), 255.102);
    });
  });

  group('calibración de pasos/mm', () {
    test('aplica la corrección calculada sobre el eje elegido', () async {
      await connect();
      await controller().refreshSettings();

      final double? result = await controller().calibrateSteps(
        axis: MachineAxis.x,
        commandedMm: 10,
        measuredMm: 9.8,
      );

      expect(result, closeTo(255.102, 0.001));
      expect(port.writtenLines, contains(r'$100=255.102'));
      expect(state().message, contains('255.102'));
      expect(state().settings!.stepsPerMm(MachineAxis.x), 255.102);
    });

    test('rechaza medidas imposibles sin escribir', () async {
      await connect();
      await controller().refreshSettings();

      final double? result = await controller().calibrateSteps(
        axis: MachineAxis.y,
        commandedMm: 10,
        measuredMm: 25.4,
      );

      expect(result, isNull);
      expect(state().error, contains('50 %'));
      expect(
        port.writtenLines.where((String line) => line.startsWith(r'$101=')),
        isEmpty,
      );
    });

    test('sin lectura previa de la EEPROM no inventa valores', () async {
      await connect();

      final double? result = await controller().calibrateSteps(
        axis: MachineAxis.z,
        commandedMm: 10,
        measuredMm: 10,
      );

      expect(result, isNull);
      expect(state().error, contains('Lee primero'));
    });
  });

  group('jogging', () {
    test('sin conexión avisa y no escribe nada', () async {
      await controller().jog(axis: MachineAxis.x, direction: 1);

      expect(state().error, contains('Conecta'));
      expect(port.writtenLines, isEmpty);
    });

    test('envía el jog con paso y avance configurados', () async {
      await connect();
      controller().setJogStep(10);
      controller().setJogFeed(1000);

      await controller().jog(axis: MachineAxis.y, direction: -1);

      expect(port.writtenLines, contains(r'$J=G91 Y-10.000 F1000.000'));
      expect(state().error, isNull);
    });
  });
}
