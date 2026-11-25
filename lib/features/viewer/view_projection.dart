import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:vector_math/vector_math_64.dart';

/// Proyección ortográfica 3D → 2D para el visor.
///
/// Es una rotación de guiñada (Y) y cabeceo (X) seguida de escala: suficiente
/// para leer una trayectoria y mucho más barata que un motor 3D completo
/// (decisión del documento de ruta, §1).
class ViewProjection {
  const ViewProjection({
    required this.center,
    required this.scale,
    this.yawDegrees = -30,
    this.pitchDegrees = 25,
  });

  /// Centro del modelo (mm) que se coloca en el origen de pantalla.
  final Vector3 center;

  /// Píxeles por milímetro.
  final double scale;

  final double yawDegrees;
  final double pitchDegrees;

  double get _yaw => yawDegrees * math.pi / 180;
  double get _pitch => pitchDegrees * math.pi / 180;

  /// Proyecta un punto del modelo a coordenadas de pantalla (sin traslación).
  Vector2 project(Vector3 point) {
    final double dx = point.x - center.x;
    final double dy = point.y - center.y;
    final double dz = point.z - center.z;
    final double rotatedX = dx * math.cos(_yaw) - dy * math.sin(_yaw);
    final double rotatedY = dx * math.sin(_yaw) + dy * math.cos(_yaw);
    return Vector2(
      rotatedX * scale,
      (rotatedY * math.cos(_pitch) - dz * math.sin(_pitch)) * scale,
    );
  }

  /// Escala que hace caber un volumen de trabajo en el viewport.
  ///
  /// Proyecta las ocho esquinas de una caja centrada en el origen y calcula el
  /// mayor desajuste, dejando un margen para que no toque los bordes.
  static double fitScale({
    required Vector3 size,
    required Size viewport,
    double yawDegrees = -30,
    double pitchDegrees = 25,
    double margin = 0.85,
  }) {
    final ViewProjection probe = ViewProjection(
      center: Vector3.zero(),
      scale: 1,
      yawDegrees: yawDegrees,
      pitchDegrees: pitchDegrees,
    );
    double maxAbsX = 1;
    double maxAbsY = 1;
    for (final double sx in <double>[-0.5, 0.5]) {
      for (final double sy in <double>[-0.5, 0.5]) {
        for (final double sz in <double>[-0.5, 0.5]) {
          final Vector2 p = probe.project(
            Vector3(size.x * sx, size.y * sy, size.z * sz),
          );
          maxAbsX = math.max(maxAbsX, p.x.abs());
          maxAbsY = math.max(maxAbsY, p.y.abs());
        }
      }
    }
    final double available =
        math.min(viewport.width, viewport.height) * margin / 2;
    return available / math.max(maxAbsX, maxAbsY);
  }

  ViewProjection copyWith({
    Vector3? center,
    double? scale,
    double? yawDegrees,
    double? pitchDegrees,
  }) {
    return ViewProjection(
      center: center ?? this.center,
      scale: scale ?? this.scale,
      yawDegrees: yawDegrees ?? this.yawDegrees,
      pitchDegrees: pitchDegrees ?? this.pitchDegrees,
    );
  }

  @override
  String toString() =>
      'ViewProjection(center: $center, scale: ${scale.toStringAsFixed(2)}, '
      'yaw: $yawDegrees, pitch: $pitchDegrees)';
}
