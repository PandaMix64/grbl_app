import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/domain/entities/machine_state.dart';
import 'package:grbl_app/domain/entities/project_file.dart';
import 'package:grbl_app/domain/services/gcode_interpreter.dart';
import 'package:grbl_app/features/connection/connection_controller.dart';
import 'package:grbl_app/features/viewer/execution_controller.dart';

import '../helpers/fake_serial_port.dart';

const String _shortProgram = 'G21\nG90\nG1 X10 F500\nG1 Y10\nG1 X0\nG1 Y0';

String _longProgram(int segments) {
  final StringBuffer buffer = StringBuffer('G21\nG90\nG1 X0 Y0 F500\n');
  for (int i = 1; i <= segments; i++) {
    buffer.writeln('G1 X${i % 50} Y${i % 30} F500');
  }
  return buffer.toString();
}

Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) {
      fail('Timeout esperando: ${reason ?? 'condición'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

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

  ExecutionController controller() =>
      container.read(executionControllerProvider.notifier);
  ExecutionUiState state() => container.read(executionControllerProvider);

  Future<void> connect() async {
    final ConnectionController connection = container.read(
      connectionControllerProvider.notifier,
    );
    await connection.refreshPorts();
    await connection.connect();
    expect(container.read(connectionControllerProvider).isConnected, isTrue);
  }

  group('arranque', () {
    test('exige conexión', () async {
      await controller().start(
        program: const GcodeInterpreter().parse(_shortProgram),
        source: _shortProgram,
      );

      expect(state().status, ExecutionStatus.error);
      expect(state().error, contains('Conecta'));
    });

    test('exige máquina en Idle', () async {
      await connect();
      port.state = 'Run';
      await waitUntil(
        () =>
            container.read(connectionControllerProvider).machineState ==
            MachineState.run,
      );

      await controller().start(
        program: const GcodeInterpreter().parse(_shortProgram),
        source: _shortProgram,
      );

      expect(state().status, ExecutionStatus.error);
      expect(state().error, contains('Idle'));
    });

    test('guarda el proyecto y completa el programa', () async {
      await connect();

      await controller().start(
        program: const GcodeInterpreter().parse(_shortProgram),
        source: _shortProgram,
        fileName: 'pieza.gcode',
      );

      await waitUntil(() => state().status == ExecutionStatus.completed);
      expect(state().executedLine, isNotNull);
      expect(state().sentLines, 6);

      final List<ProjectFile> projects = await database.recentProjects();
      expect(projects.single.name, 'pieza.gcode');
      expect(projects.single.status, ProjectStatus.running);
      expect(projects.single.gcode, _shortProgram);
    });

    test('rechaza líneas que no caben en el búfer', () async {
      await connect();

      await controller().start(
        program: const GcodeInterpreter().parse('G21\nG90\nG1 X10 F500'),
        source: 'G21\nG90\nG1 X${'1' * 140} F500',
      );

      expect(state().status, ExecutionStatus.error);
      expect(state().error, contains('120 caracteres'));
    });
  });

  group('pausa, reanudación y detención', () {
    Future<String> startLongJob() async {
      port.ackDelay = const Duration(milliseconds: 4);
      port.spindle = 500;
      await connect();
      final String source = _longProgram(200);
      await controller().start(
        program: const GcodeInterpreter().parse('G21\nG90\nG1 X10 F500'),
        source: source,
      );
      expect(state().status, ExecutionStatus.running);
      // La máquina empieza a ejecutar y avanza el progreso.
      port.state = 'Run';
      await client.requestStatus();
      await waitUntil(
        () =>
            container.read(connectionControllerProvider).machineState ==
            MachineState.run,
        timeout: const Duration(seconds: 3),
      );
      await waitUntil(
        () => state().executedLine != null,
        timeout: const Duration(seconds: 3),
        reason: 'progreso del programa',
      );
      return source;
    }

    test(
      'la pausa guarda el punto, apaga la herramienta y no resetea',
      () async {
        await startLongJob();

        await controller().pause();

        await waitUntil(() => state().status == ExecutionStatus.paused);
        expect(state().resume, isNotNull);
        final ResumeState resume = state().resume!;
        expect(resume.parserState, contains('G21'));
        expect(resume.offsets, isNotNull);

        final ProjectFile? saved = await database.projectById(
          state().projectId!,
        );
        expect(saved!.status, ProjectStatus.paused);
        expect(saved.resume, isNotNull);
        expect(saved.resume!.offsets, isNotNull);
        expect(
          saved.resume!.lineIndex,
          lessThanOrEqualTo(state().executedLine! + 1),
        );

        expect(port.realtimeBytes, containsAllInOrder(<int>[0x21, 0x9E]));
        expect(port.realtimeBytes, isNot(contains(0x18)));
      },
    );

    test('la reanudación se niega si los offsets cambiaron (SEG-05)', () async {
      await startLongJob();
      await controller().pause();
      await waitUntil(() => state().status == ExecutionStatus.paused);

      port.offsetLines = <String>[
        '[G54:5.000,0.000,0.000]',
        '[G55:0.000,0.000,0.000]',
        '[G56:0.000,0.000,0.000]',
        '[G57:0.000,0.000,0.000]',
        '[G58:0.000,0.000,0.000]',
        '[G59:0.000,0.000,0.000]',
        '[G28:0.000,0.000,0.000]',
        '[G30:0.000,0.000,0.000]',
        '[G92:0.000,0.000,0.000]',
        '[TLO:0.000]',
        '[PRB:0.000,0.000,0.000:0]',
      ];

      await controller().resume();

      expect(state().status, ExecutionStatus.error);
      expect(state().error, contains('offsets'));
    });

    test(
      'la reanudación se niega si el estado modal cambió (SEG-05)',
      () async {
        await startLongJob();
        await controller().pause();
        await waitUntil(() => state().status == ExecutionStatus.paused);

        port.parserStateLine = r'[GC:G1 G55 G17 G21 G90 G94 M5 M9 T0 F0 S0]';

        await controller().resume();

        expect(state().status, ExecutionStatus.error);
        expect(state().error, contains('estado modal'));
      },
    );

    test('reanuda desde la línea guardada cuando todo coincide', () async {
      await startLongJob();
      await controller().pause();
      await waitUntil(() => state().status == ExecutionStatus.paused);
      final int savedLine = state().resume!.lineIndex;
      final int resetsBefore = port.realtimeBytes
          .where((int byte) => byte == 0x18)
          .length;

      await controller().resume();

      expect(state().status, ExecutionStatus.running);
      expect(state().message, contains('Reanudado'));
      expect(port.realtimeBytes, contains(0x7E));
      expect(
        port.realtimeBytes.where((int byte) => byte == 0x18).length,
        resetsBefore,
      );
      expect(savedLine, greaterThanOrEqualTo(0));
    });

    test('detener guarda, resetea y deja el estado detenido', () async {
      await startLongJob();

      await controller().stop();

      await waitUntil(() => state().status == ExecutionStatus.stopped);
      expect(port.realtimeBytes, contains(0x18));
      final ProjectFile? saved = await database.projectById(state().projectId!);
      expect(saved!.resume, isNotNull);
    });
  });
}
