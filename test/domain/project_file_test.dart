import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/project_file.dart';

void main() {
  final DateTime stamp = DateTime.utc(2026, 11, 24, 10, 30);

  ProjectFile build() => ProjectFile(
    id: 'proj-1',
    name: 'Grabado de prueba',
    profileId: 'p1',
    gcode: 'G21\nG90\n\n; comentario\nG1 X1.000 Y1.000',
    status: ProjectStatus.paused,
    updatedAt: stamp,
    resume: ResumeState(
      lineIndex: 3,
      parserState: 'G21 G90 G94 M4 S500',
      workPosition: <double>[1, 2, 3],
      spindleOn: true,
      feedMmMin: 500,
      spindleSpeed: 800,
      savedAt: stamp,
    ),
  );

  group('ProjectFile', () {
    test('cuenta solo los bloques ejecutables', () {
      expect(build().blockCount, 3);
    });

    test('sobrevive a encode/decode conservando el punto de reanudación', () {
      final ProjectFile original = build();

      final ProjectFile restored = ProjectFile.decode(original.encode());

      expect(restored.id, 'proj-1');
      expect(restored.status, ProjectStatus.paused);
      expect(restored.schemaVersion, ProjectFile.currentSchemaVersion);
      expect(restored.resume, isNotNull);
      expect(restored.resume!.lineIndex, 3);
      expect(restored.resume!.parserState, 'G21 G90 G94 M4 S500');
      expect(restored.resume!.workPosition, <double>[1, 2, 3]);
      expect(restored.resume!.spindleOn, isTrue);
      expect(restored.updatedAt, stamp);
    });

    test(
      'rechaza un esquema más reciente en lugar de corromper el proyecto',
      () {
        final Map<String, Object?> json = build().toJson()
          ..['schemaVersion'] = ProjectFile.currentSchemaVersion + 1;

        expect(
          () => ProjectFile.fromJson(json),
          throwsA(
            isA<ProjectException>().having(
              (ProjectException error) => error.message,
              'mensaje',
              contains('esquema más reciente'),
            ),
          ),
        );
      },
    );

    test('exige schemaVersion', () {
      final Map<String, Object?> json = build().toJson()
        ..remove('schemaVersion');

      expect(
        () => ProjectFile.fromJson(json),
        throwsA(isA<ProjectException>()),
      );
    });

    test('falla con JSON inválido o con otro tipo de raíz', () {
      expect(
        () => ProjectFile.decode('{ no es json'),
        throwsA(isA<ProjectException>()),
      );
      expect(
        () => ProjectFile.decode('[1,2,3]'),
        throwsA(isA<ProjectException>()),
      );
    });

    test('copyWith puede limpiar el punto de reanudación', () {
      final ProjectFile cleared = build().copyWith(clearResume: true);

      expect(cleared.resume, isNull);
      expect(cleared.id, 'proj-1');
    });
  });
}
