import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/motion_segment.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('MotionSegment', () {
    test('calcula la longitud real en 3D', () {
      final MotionSegment segment = MotionSegment(
        start: Vector3.zero(),
        end: Vector3(3, 4, 0),
      );

      expect(segment.lengthMm, 5);
      expect(segment.planarLengthMm, 5);
    });

    test('incluye Z en la longitud y en el G-code', () {
      final MotionSegment segment = MotionSegment(
        start: Vector3.zero(),
        end: Vector3(0, 0, -2.5),
      );

      expect(segment.lengthMm, 2.5);
      expect(segment.toGcode(), 'G1 X0.000 Y0.000 Z-2.500');
    });

    test('G0 no emite avance y G1 sí', () {
      final MotionSegment rapid = MotionSegment(
        start: Vector3.zero(),
        end: Vector3(10, 0, 5),
        rapid: true,
        feedMmMin: 900,
      );
      final MotionSegment cut = MotionSegment(
        start: Vector3.zero(),
        end: Vector3(10, 0, 5),
        feedMmMin: 900,
      );

      expect(rapid.toGcode(), 'G0 X10.000 Y0.000 Z5.000');
      expect(cut.toGcode(), 'G1 X10.000 Y0.000 Z5.000 F900.0');
    });

    test('sobrevive a la serialización JSON', () {
      final MotionSegment segment = MotionSegment(
        start: Vector3(1, 2, 3),
        end: Vector3(4, 5, 6),
        feedMmMin: 300,
      );

      final MotionSegment restored = MotionSegment.fromJson(segment.toJson());

      expect(restored.start, Vector3(1, 2, 3));
      expect(restored.end, Vector3(4, 5, 6));
      expect(restored.rapid, isFalse);
      expect(restored.feedMmMin, 300);
    });

    test('rechaza segmentos incompletos', () {
      expect(
        () => MotionSegment.fromJson(<String, Object?>{'sx': 0}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
