import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/gcode_program.dart';
import 'package:grbl_app/domain/entities/motion_segment.dart';
import 'package:grbl_app/domain/services/gcode_interpreter.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  const GcodeInterpreter interpreter = GcodeInterpreter();

  group('movimientos lineales', () {
    test('interpreta G0 y G1 en coordenadas absolutas', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG90\nG0 X0 Y0\nG1 X10 Y0 F500\nG1 X10 Y10',
      );

      expect(program.segments, hasLength(2));
      expect(program.segments.first.rapid, isFalse);
      expect(program.segments.first.feedMmMin, 500);
      expect(program.segments.last.end.x, 10);
      expect(program.segments.last.end.y, 10);
      expect(program.arcCount, 0);
      expect(program.warnings, isEmpty);
    });

    test('respeta el modo incremental G91', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG91\nG1 X5 F300\nG1 X5',
      );

      expect(program.segments, hasLength(2));
      expect(program.segments.first.end.x, 5);
      expect(program.segments.last.end.x, 10);
    });

    test('convierte pulgadas a milímetros', () {
      final GcodeProgram program = interpreter.parse('G20\nG90\nG1 X1 F10');

      expect(program.segments.single.end.x, closeTo(25.4, 1e-9));
      expect(program.segments.single.feedMmMin, closeTo(254, 1e-9));
    });

    test('ignora movimientos sin desplazamiento', () {
      final GcodeProgram program = interpreter.parse('G0 X0 Y0\nG1 X0 Y0');

      expect(program.isEmpty, isTrue);
    });

    test('marca los rápidos y suma longitudes', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG90\nG0 X0 Y50 F1000\n'
        'G1 X10 Y50 F500\nG1 X10 Y60\nG1 X0 Y60\nG1 X0 Y50',
      );

      expect(program.segments.first.rapid, isTrue);
      expect(program.rapidLengthMm, closeTo(50, 1e-9));
      expect(program.cuttingLengthMm, closeTo(40, 1e-9));
    });

    test('calcula el volumen ocupado', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG90\nG1 X10 Y20 F500\nG1 X-5 Y-10 Z-2',
      );

      expect(program.min, isNotNull);
      expect(program.min!.x, -5);
      expect(program.min!.y, -10);
      expect(program.min!.z, -2);
      expect(program.max!.x, 10);
      expect(program.max!.y, 20);
    });
  });

  group('arcos', () {
    test('subdivide un cuarto de círculo con I/J', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG90\nG1 X10 Y0 F500\nG3 X0 Y10 I-10 J0',
      );

      expect(program.arcCount, 1);
      expect(program.segments.length, inInclusiveRange(18, 20));
      final List<MotionSegment> arc = program.segments.skip(1).toList();
      expect(arc.first.start.x, closeTo(10, 1e-9));
      expect(arc.first.start.y, closeTo(0, 1e-9));
      expect(arc.last.end.x, closeTo(0, 1e-9));
      expect(arc.last.end.y, closeTo(10, 1e-9));
      for (final MotionSegment segment in arc) {
        final double radius = math.sqrt(
          segment.end.x * segment.end.x + segment.end.y * segment.end.y,
        );
        expect(radius, closeTo(10, 0.01));
      }
    });

    test('acepta la forma con radio R', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG90\nG1 X10 Y0 F500\nG2 X0 Y10 R10',
      );

      expect(program.arcCount, 1);
      expect(program.warnings, isEmpty);
      expect(program.segments.last.end.x, closeTo(0, 1e-9));
      expect(program.segments.last.end.y, closeTo(10, 1e-9));
    });

    test('reconoce un círculo completo cuando inicio y fin coinciden', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG90\nG1 X10 Y0 F500\nG2 X10 Y0 I-10 J0',
      );

      expect(program.arcCount, 1);
      expect(program.segments.length, inInclusiveRange(70, 75));
      expect(program.segments.last.end.x, closeTo(10, 1e-9));
      expect(program.segments.last.end.y, closeTo(0, 1e-9));
    });

    test('avisa y traza una recta si el arco no tiene centro', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG90\nG1 X0 Y0 F500\nG2 X10 Y10',
      );

      expect(program.arcCount, 0);
      expect(program.warnings.single, contains('sin I/J ni R'));
      expect(program.segments, hasLength(1));
    });

    test('avisa si el radio es imposible', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG90\nG1 X0 Y0 F500\nG2 X10 Y0 R1',
      );

      expect(program.warnings.single, contains('imposible'));
    });
  });

  group('robustez', () {
    test('ignora comentarios, líneas vacías y códigos no geométricos', () {
      final GcodeProgram program = interpreter.parse(
        '; cabecera\n\n(comentario)\nG21\nG90\nM4 S500\nG17\nG54\n'
        'G1 X1 Y1 F500 ; trazo',
      );

      expect(program.segments, hasLength(1));
      expect(program.warnings, isEmpty);
    });

    test('avisa de G92 en lugar de simularlo mal', () {
      final GcodeProgram program = interpreter.parse('G21\nG92 X0 Y0');

      expect(program.warnings.single, contains('G92'));
    });

    test('un programa vacío no produce segmentos', () {
      final GcodeProgram program = interpreter.parse('');

      expect(program.isEmpty, isTrue);
      expect(program.min, isNull);
      expect(program.max, isNull);
      expect(program.toString(), contains('0 segmentos'));
    });

    test('cada segmento recuerda su línea de origen', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG90\nG1 X1 F500\nG1 X2',
      );

      expect(program.lineIndexes, <int>[2, 3]);
      expect(program.sourceLineCount, 4);
    });

    test('el arco termina exactamente en el punto ordenado', () {
      final GcodeProgram program = interpreter.parse(
        'G21\nG90\nG1 X10 Y0 F500\nG3 X0 Y10 I-10 J0',
      );

      expect(program.segments.last.end, Vector3(0, 10, 0));
    });
  });
}
