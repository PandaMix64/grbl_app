import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/domain/entities/project_file.dart';
import 'package:grbl_app/domain/services/gcode_interpreter.dart';
import 'package:grbl_app/features/connection/connection_controller.dart';
import 'package:grbl_app/features/viewer/execution_controller.dart';

import '../helpers/fake_serial_port.dart';

const String _program =
    'G21\n'
    'G90\n'
    'G1 Z5 F300\n'
    'G1 X0 Y0 F800\n'
    'G1 X10\n'
    'G1 Y10\n'
    'G1 X0\n'
    'G1 Y0';

const String _parserState = r'[GC:G0 G54 G17 G21 G90 G94 M5 M9 T0 F0 S0]';

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
    await client.stopPolling();
  }

  /// Deja la máquina reportando la posición de trabajo indicada.
  Future<void> reportPosition(List<double> position) async {
    port.emitLine(
      '<Idle|MPos:${position[0].toStringAsFixed(3)},'
      '${position[1].toStringAsFixed(3)},'
      '${position[2].toStringAsFixed(3)}|FS:0,0|'
      'WCO:0.000,0.000,0.000>',
    );
    await waitUntil(
      () => container.read(connectionControllerProvider).workPosition != null,
      reason: 'posición inicial',
    );
  }

  Future<void> seedProject({
    int lineIndex = 4,
    String parserState = _parserState,
    List<double> position = const <double>[10, 20, 5],
  }) async {
    await database.upsertProject(
      ProjectFile(
        id: 'p1',
        name: 'pieza.gcode',
        profileId: '',
        gcode: _program,
        status: ProjectStatus.paused,
        updatedAt: DateTime.now(),
      ),
    );
    await database.saveResume(
      projectId: 'p1',
      resume: ResumeState(
        lineIndex: lineIndex,
        parserState: parserState,
        workPosition: position,
        spindleOn: false,
        savedAt: DateTime.now(),
      ),
    );
  }

  test('perder el enlace marca el trabajo como interrumpido', () async {
    await connect();
    // Sin `ok` el programa queda en vuelo: la desconexión ocurre con trabajo
    // activo, que es el caso que debe marcar el estado como interrumpido.
    port.autoAck = false;
    await controller().start(
      program: const GcodeInterpreter().parse(_program),
      source: _program,
      fileName: 'pieza.gcode',
    );
    expect(state().status, ExecutionStatus.running);

    await container.read(connectionControllerProvider.notifier).disconnect();

    await waitUntil(
      () => state().status == ExecutionStatus.interrupted,
      reason: 'estado interrumpido',
    );
    expect(state().error, contains('interrumpido'));
    final List<ProjectFile> projects = await database.recentProjects();
    expect(projects.single.status, ProjectStatus.interrupted);
  });

  test('reanuda desde la línea guardada sin repetir el tramo previo', () async {
    await seedProject(lineIndex: 5);
    await connect();
    await reportPosition(const <double>[10, 20, 5]);

    await controller().restartFromSaved();

    expect(state().status, ExecutionStatus.running, reason: state().error);
    expect(state().executedLine, 4);
    await waitUntil(() => port.writtenLines.contains('G1 Y10'));
    // `G1 X10` es anterior al punto guardado: no debe reenviarse.
    expect(port.writtenLines.where((String line) => line == 'G1 X10'), isEmpty);
    expect(state().message, contains('Reanudado desde la línea 6'));
  });

  test('se niega a reanudar si el estado modal cambió', () async {
    await seedProject(
      parserState: r'[GC:G1 G55 G17 G21 G90 G94 M5 M9 T0 F0 S0]',
    );
    await connect();
    await reportPosition(const <double>[10, 20, 5]);

    await controller().restartFromSaved();

    expect(state().status, ExecutionStatus.error);
    expect(state().error, contains('estado modal'));
    expect(port.writtenLines.where((String line) => line == 'G1 Y10'), isEmpty);
  });

  test(
    'se niega a reanudar si la máquina no está en el punto guardado',
    () async {
      await seedProject(position: const <double>[100, 100, 0]);
      await connect();
      await reportPosition(const <double>[10, 20, 5]);

      await controller().restartFromSaved();

      expect(state().status, ExecutionStatus.error);
      expect(state().error, contains('mm del punto guardado'));
      expect(
        port.writtenLines.where((String line) => line == 'G1 Y10'),
        isEmpty,
      );
    },
  );

  test('sin trabajo guardado avisa en lugar de enviar', () async {
    await connect();
    await reportPosition(const <double>[10, 20, 5]);

    await controller().restartFromSaved();

    expect(state().error, contains('No hay ningún trabajo guardado'));
  });
}
