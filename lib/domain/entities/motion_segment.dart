import 'package:vector_math/vector_math_64.dart';

/// Segmento rectilíneo de trayectoria (`G0` o `G1`).
///
/// Es la unidad mínima del visor 3D y del motor CAM. Los arcos se subdividen en
/// segmentos antes de llegar aquí (GRBL solo interpola `G2`/`G3` con `I`/`J`/`K`).
class MotionSegment {
  const MotionSegment({
    required this.start,
    required this.end,
    this.rapid = false,
    this.feedMmMin,
  });

  final Vector3 start;
  final Vector3 end;

  /// `true` para `G0` (rápido en vacío), `false` para `G1` (con avance).
  final bool rapid;

  /// Avance en mm/min; obligatorio para `G1`, ignorado en `G0`.
  final double? feedMmMin;

  Vector3 get delta => end - start;

  double get lengthMm => delta.length;

  /// Longitud proyectada sobre el plano XY (útil para estimar tiempos de láser).
  double get planarLengthMm => Vector2(delta.x, delta.y).length;

  /// Línea de G-code equivalente.
  String toGcode({int decimals = 3}) {
    final String code = rapid ? 'G0' : 'G1';
    final StringBuffer buffer = StringBuffer(code)
      ..write(' X')
      ..write(end.x.toStringAsFixed(decimals))
      ..write(' Y')
      ..write(end.y.toStringAsFixed(decimals))
      ..write(' Z')
      ..write(end.z.toStringAsFixed(decimals));
    if (!rapid && feedMmMin != null) {
      buffer
        ..write(' F')
        ..write(feedMmMin!.toStringAsFixed(1));
    }
    return buffer.toString();
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'sx': start.x,
    'sy': start.y,
    'sz': start.z,
    'ex': end.x,
    'ey': end.y,
    'ez': end.z,
    'rapid': rapid,
    if (feedMmMin != null) 'f': feedMmMin,
  };

  factory MotionSegment.fromJson(Map<String, Object?> json) {
    double read(String key) {
      final Object? value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      throw FormatException('Segmento inválido: falta $key');
    }

    return MotionSegment(
      start: Vector3(read('sx'), read('sy'), read('sz')),
      end: Vector3(read('ex'), read('ey'), read('ez')),
      rapid: json['rapid'] == true,
      feedMmMin: json['f'] is num ? (json['f']! as num).toDouble() : null,
    );
  }

  @override
  String toString() => '${rapid ? 'G0' : 'G1'} $start -> $end';
}
