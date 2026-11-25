import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/domain/entities/axis.dart';
import 'package:grbl_app/domain/entities/machine_profile.dart';
import 'package:grbl_app/domain/entities/machine_state.dart';
import 'package:grbl_app/domain/services/profile_consistency.dart';
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

  group('holgura mecánica', () {
    test('guarda la holgura estimada en el perfil activo', () async {
      await controller().saveProfile(profile);

      final double? result = await controller().calibrateBacklash(
        axis: MachineAxis.x,
        commandedMm: 5,
        measuredMm: 4.7,
      );

      expect(result, closeTo(0.3, 1e-9));
      final MachineProfile? saved = await database.profileById('p1');
      expect(saved!.backlashXmm, closeTo(0.3, 1e-9));
      expect(state().message, contains('0.300'));
    });

    test('rechaza holgura en Z', () async {
      await controller().saveProfile(profile);

      final double? result = await controller().calibrateBacklash(
        axis: MachineAxis.z,
        commandedMm: 5,
        measuredMm: 4.5,
      );

      expect(result, isNull);
      expect(state().error, contains('Z'));
    });

    test('rechaza medidas imposibles sin tocar el perfil', () async {
      await controller().saveProfile(profile);

      final double? result = await controller().calibrateBacklash(
        axis: MachineAxis.y,
        commandedMm: 5,
        measuredMm: 6,
      );

      expect(result, isNull);
      expect(state().error, contains('supera lo ordenado'));
      final MachineProfile? saved = await database.profileById('p1');
      expect(saved!.backlashYmm, 0);
    });
  });

  group('aplicar perfil a la máquina', () {
    test('no escribe nada si la EEPROM ya coincide', () async {
      await connect();
      await controller().refreshSettings();
      await controller().saveProfile(profile);

      final int written = await controller().applyProfileToSettings();

      expect(written, 0);
      expect(state().message, contains('ya coincide'));
      expect(
        port.writtenLines.where((String line) => line.startsWith(r'$13')),
        isEmpty,
      );
    });

    test('escribe solo lo que difiere', () async {
      await connect();
      await controller().refreshSettings();
      await controller().saveProfile(profile.copyWith(travelZmm: 40));

      final int written = await controller().applyProfileToSettings();

      expect(written, 1);
      expect(port.writtenLines, contains(r'$132=40.000'));
    });

    test('sin perfil seleccionado no intenta escribir', () async {
      expect(await controller().applyProfileToSettings(), 0);
      expect(state().error, contains('Selecciona un perfil'));
    });
  });

  group('homing y origen de trabajo', () {
    test('homing envía el comando al controlador', () async {
      await connect();

      await controller().home();

      expect(port.writtenLines, contains(r'$H'));
      expect(state().message, contains('Homing'));
    });

    test('fija el cero con G10 L20 en los ejes elegidos', () async {
      await connect();

      await controller().setWorkZero(x: true, y: false, z: false);

      expect(port.writtenLines, contains('G10 L20 P1 X0'));
      expect(state().message, contains('G10 L20'));
    });

    test('sin conexión avisa', () async {
      await controller().setWorkZero();

      expect(state().error, contains('Conecta'));
    });

    test('ir al cero usa el delta hasta WPos (0,0)', () async {
      await connect();
      await client.requestStatus();
      final Stopwatch watch = Stopwatch()..start();
      while (container.read(connectionControllerProvider).workPosition ==
          null) {
        if (watch.elapsed > const Duration(seconds: 3)) {
          fail('Sin telemetría de posición.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      await controller().goToWorkZero();

      expect(
        port.writtenLines,
        contains(r'$J=G91 X-10.000 Y-20.000 F500.000'),
        reason: port.writtenLines.join(' | '),
      );
    });

    test('ir al cero exige Idle', () async {
      await connect();
      port.state = 'Run';
      final Stopwatch watch = Stopwatch()..start();
      while (container.read(connectionControllerProvider).machineState !=
          MachineState.run) {
        if (watch.elapsed > const Duration(seconds: 3)) {
          fail('La máquina no reportó Run.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      await controller().goToWorkZero();

      expect(state().error, contains('Idle'));
    });
  });

  group('perfil frente a la EEPROM', () {
    test(
      'al refrescar los parámetros se revalidan las discrepancias',
      () async {
        await connect();
        expect(container.read(connectionControllerProvider).issues, isEmpty);

        // Perfil con 400 mm de recorrido X frente a `$130=300`: discrepancia
        // bloqueante que solo puede aparecer al revalidar contra la EEPROM.
        await controller().saveProfile(profile.copyWith(travelXmm: 400));
        await controller().refreshSettings();

        final List<ConsistencyIssue> issues = container
            .read(connectionControllerProvider)
            .issues;
        expect(issues, isNotEmpty);
        expect(
          issues.any((ConsistencyIssue issue) => issue.code == 'TRAVEL_X'),
          isTrue,
          reason: issues.join(' | '),
        );
      },
    );
  });
}
