import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/repositories/project_repository.dart';
import 'package:grbl_app/data/serial/grbl_worker.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/domain/entities/machine_state.dart';
import 'package:grbl_app/domain/entities/project_file.dart';

import '../helpers/fake_serial_port.dart';

void main() {
  late AppDatabase database;
  late FakeSerialPort port;
  late ProjectRepository repository;
  GrblWorkerClient? client;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    port = FakeSerialPort();
    repository = ProjectRepository(database);
    await database.upsertProject(
      ProjectFile(
        id: 'proj1',
        name: 'Grabado',
        profileId: 'p1',
        gcode: 'G21\nG90\nG1 X1.000 Y1.000',
        updatedAt: DateTime.utc(2026, 11, 24),
      ),
    );
  });

  tearDown(() async {
    await client?.dispose();
    await database.close();
  });

  Future<void> prepareRunningJob({
    Duration persistTimeout = const Duration(seconds: 20),
  }) async {
    client = GrblWorkerClient.inProcess(
      port: port,
      persistTimeout: persistTimeout,
    );
    await client!.connect(portName: 'FAKE0');
    port.state = 'Run';
    port.spindle = 600;
    // Láser dinámico activo: es lo que debe quedar guardado para reanudar.
    port.parserStateLine = r'[GC:G1 G54 G17 G21 G90 G94 M4 M9 T0 F500 S600]';
    await client!.startPolling(interval: const Duration(milliseconds: 5));
    await client!.statusReports.firstWhere(
      (report) => report.state == MachineState.run,
    );
  }

  test(
    'persiste antes del reset y guarda modal, posición y herramienta',
    () async {
      await prepareRunningJob();
      int resetsBeforePersist = -1;

      final sub = client!.persistRequests.listen((
        WorkerPersistRequest request,
      ) async {
        resetsBeforePersist = port.realtimeBytes
            .where((int byte) => byte == 0x18)
            .length;
        await repository.persistAndConfirm(
          projectId: 'proj1',
          request: request,
          lineIndex: 42,
        );
      });

      await client!.stopJob();
      await sub.cancel();

      final ProjectFile? saved = await database.projectById('proj1');

      expect(resetsBeforePersist, 0);
      expect(saved, isNotNull);
      expect(saved!.status, ProjectStatus.paused);
      expect(saved.resume, isNotNull);
      expect(saved.resume!.lineIndex, 42);
      expect(saved.resume!.parserState, contains('G21'));
      expect(saved.resume!.spindleOn, isTrue);
      expect(saved.resume!.workPosition, isNotEmpty);
      expect(saved.resume!.feedMmMin, 500);
      expect(saved.resume!.spindleSpeed, 600);
      expect(port.realtimeBytes, contains(0x18));
    },
  );

  test('si no se confirma el guardado, no hay soft reset (R-12)', () async {
    await prepareRunningJob(persistTimeout: const Duration(milliseconds: 300));
    // El cliente recibe la petición pero no la confirma.
    final sub = client!.persistRequests.listen((_) {});

    await expectLater(client!.stopJob(), throwsA(isA<GrblWorkerException>()));
    await sub.cancel();

    expect(port.realtimeBytes, isNot(contains(0x18)));
    // La máquina queda en Hold y con la herramienta apagada: es el estado
    // seguro, no un reset silencioso.
    expect(port.state, 'Hold');
    expect(port.spindle, 0);
    expect((await database.projectById('proj1'))!.resume, isNull);
  });
}
