import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/domain/entities/machine_profile.dart';
import 'package:grbl_app/domain/entities/project_file.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const MachineProfile profile = MachineProfile(
    id: 'p1',
    name: '3018',
    tool: ToolType.laser,
    travelXmm: 300,
    travelYmm: 180,
    travelZmm: 45,
    safeZmm: 8,
    backlashXmm: 0.1,
    backlashYmm: 0.2,
  );

  ProjectFile project({
    String id = 'proj1',
    String name = 'Grabado',
    ProjectStatus status = ProjectStatus.ready,
    ResumeState? resume,
    DateTime? updatedAt,
  }) => ProjectFile(
    id: id,
    name: name,
    profileId: 'p1',
    gcode: 'G21\nG1 X1.000 Y1.000',
    status: status,
    resume: resume,
    updatedAt: updatedAt ?? DateTime.utc(2026, 11, 24, 10),
  );

  ResumeState resume({int lineIndex = 7}) => ResumeState(
    lineIndex: lineIndex,
    parserState: 'G21 G90 G94 M4 S500',
    workPosition: <double>[1, 2, 3],
    spindleOn: true,
    feedMmMin: 500,
    spindleSpeed: 800,
    savedAt: DateTime.utc(2026, 11, 24, 10, 30),
  );

  group('perfiles', () {
    test(
      'guarda y lee el perfil conservando holgura y altura segura',
      () async {
        await db.upsertProfile(profile);

        final MachineProfile? loaded = await db.profileById('p1');

        expect(loaded, isNotNull);
        expect(loaded!.name, '3018');
        expect(loaded.tool, ToolType.laser);
        expect(loaded.travelXmm, 300);
        expect(loaded.safeZmm, 8);
        expect(loaded.backlashXmm, 0.1);
        expect(loaded.backlashYmm, 0.2);
        expect((await db.allProfiles()).single.id, 'p1');
      },
    );

    test('upsert actualiza en lugar de duplicar', () async {
      await db.upsertProfile(profile);
      await db.upsertProfile(profile.copyWith(name: '3018 v2'));

      final List<MachineProfile> all = await db.allProfiles();

      expect(all, hasLength(1));
      expect(all.single.name, '3018 v2');
    });

    test('elimina por id', () async {
      await db.upsertProfile(profile);

      expect(await db.deleteProfile('p1'), 1);
      expect(await db.profileById('p1'), isNull);
    });

    test('watchProfiles emite al insertar', () async {
      final Future<List<MachineProfile>> next = db.watchProfiles().firstWhere(
        (List<MachineProfile> profiles) => profiles.isNotEmpty,
      );

      await db.upsertProfile(profile);

      expect((await next).single.name, '3018');
    });
  });

  group('proyectos', () {
    test('persiste el proyecto con su punto de reanudación', () async {
      await db.upsertProject(
        project(status: ProjectStatus.paused, resume: resume()),
      );

      final ProjectFile? loaded = await db.projectById('proj1');

      expect(loaded, isNotNull);
      expect(loaded!.gcode, contains('G21'));
      expect(loaded.status, ProjectStatus.paused);
      expect(loaded.resume, isNotNull);
      expect(loaded.resume!.lineIndex, 7);
      expect(loaded.resume!.workPosition, <double>[1, 2, 3]);
      expect(loaded.resume!.parserState, 'G21 G90 G94 M4 S500');
      expect(loaded.resume!.spindleOn, isTrue);
      expect(loaded.resume!.feedMmMin, 500);
      expect(loaded.resume!.spindleSpeed, 800);
    });

    test('saveResume actualiza el punto sin tocar el G-code', () async {
      await db.upsertProject(project());

      await db.saveResume(projectId: 'proj1', resume: resume(lineIndex: 42));

      final ProjectFile? loaded = await db.projectById('proj1');
      expect(loaded!.resume!.lineIndex, 42);
      expect(loaded.status, ProjectStatus.paused);
      expect(loaded.gcode, 'G21\nG1 X1.000 Y1.000');
    });

    test('recentProjects ordena por actualización descendente', () async {
      await db.upsertProject(
        project(id: 'viejo', updatedAt: DateTime.utc(2026, 11, 20)),
      );
      await db.upsertProject(
        project(id: 'nuevo', updatedAt: DateTime.utc(2026, 11, 24)),
      );

      final List<ProjectFile> recent = await db.recentProjects();

      expect(recent.map((ProjectFile p) => p.id), <String>['nuevo', 'viejo']);
    });
  });

  group('archivos recientes', () {
    test('no duplica rutas y ordena por apertura', () async {
      await db.touchRecentFile('C:/a.gcode', at: DateTime.utc(2026, 1, 1));
      await db.touchRecentFile('C:/b.gcode', at: DateTime.utc(2026, 1, 2));
      await db.touchRecentFile('C:/a.gcode', at: DateTime.utc(2026, 1, 3));

      final List<RecentFileRow> files = await db.recentlyOpened();

      expect(files, hasLength(2));
      expect(files.first.path, 'C:/a.gcode');
      expect(files.first.openedAt.toUtc(), DateTime.utc(2026, 1, 3));
    });
  });
}
