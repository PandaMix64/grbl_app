import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/features/viewer/view_projection.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('ViewProjection', () {
    test('sin rotación proyecta escalando XY e ignorando Z', () {
      final ViewProjection projection = ViewProjection(
        center: Vector3.zero(),
        scale: 2,
        yawDegrees: 0,
        pitchDegrees: 0,
      );

      final Vector2 p = projection.project(Vector3(3, 4, 5));

      expect(p.x, closeTo(6, 1e-9));
      expect(p.y, closeTo(8, 1e-9));
    });

    test('el centro del modelo se coloca en el origen', () {
      final ViewProjection projection = ViewProjection(
        center: Vector3(5, 5, 2),
        scale: 3,
        yawDegrees: 0,
        pitchDegrees: 0,
      );

      final Vector2 p = projection.project(Vector3(5, 5, 2));

      expect(p.x, closeTo(0, 1e-9));
      expect(p.y, closeTo(0, 1e-9));
    });

    test('con cabeceo la altura Z se proyecta en vertical', () {
      final ViewProjection projection = ViewProjection(
        center: Vector3.zero(),
        scale: 1,
        yawDegrees: 0,
        pitchDegrees: 90,
      );

      final Vector2 p = projection.project(Vector3(0, 0, 10));

      expect(p.x, closeTo(0, 1e-9));
      expect(p.y, closeTo(-10, 1e-9));
    });

    test('la guiñada rota el plano XY', () {
      final ViewProjection projection = ViewProjection(
        center: Vector3.zero(),
        scale: 1,
        yawDegrees: 90,
        pitchDegrees: 0,
      );

      final Vector2 p = projection.project(Vector3(10, 0, 0));

      expect(p.x, closeTo(0, 1e-9));
      expect(p.y, closeTo(10, 1e-9));
    });

    test('fitScale encaja el volumen dentro del viewport con margen', () {
      const Size viewport = Size(100, 100);
      final double scale = ViewProjection.fitScale(
        size: Vector3(100, 100, 0),
        viewport: viewport,
        yawDegrees: 0,
        pitchDegrees: 0,
      );

      final ViewProjection projection = ViewProjection(
        center: Vector3.zero(),
        scale: 0,
        yawDegrees: 0,
        pitchDegrees: 0,
      );
      final ViewProjection fitted = projection.copyWith(scale: scale);
      final Vector2 corner = fitted.project(Vector3(50, 50, 0));

      expect(scale, greaterThan(0));
      expect(corner.x.abs(), lessThanOrEqualTo(viewport.width / 2));
      expect(corner.y.abs(), lessThanOrEqualTo(viewport.height / 2));
    });

    test('un volumen mayor produce una escala menor', () {
      const Size viewport = Size(400, 400);
      final double small = ViewProjection.fitScale(
        size: Vector3(50, 50, 5),
        viewport: viewport,
      );
      final double large = ViewProjection.fitScale(
        size: Vector3(500, 500, 5),
        viewport: viewport,
      );

      expect(small, greaterThan(large));
    });
  });
}
