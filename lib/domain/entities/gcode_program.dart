import 'package:vector_math/vector_math_64.dart';

import 'motion_segment.dart';

/// Programa de G-code interpretado y listo para el visor.
class GcodeProgram {
  GcodeProgram({
    required this.segments,
    required this.lineIndexes,
    required this.warnings,
    required this.arcCount,
    required this.sourceLineCount,
    required this.min,
    required this.max,
  }) : assert(
         segments.length == lineIndexes.length,
         'Cada segmento necesita su línea de origen',
       );

  /// Segmentos en orden de ejecución.
  final List<MotionSegment> segments;

  /// Índice de la línea del archivo que originó cada segmento.
  ///
  /// Permite progreso y reanudación por línea (Fase 3).
  final List<int> lineIndexes;

  /// Problemas no fatales detectados (arcos imposibles, códigos ignorados...).
  final List<String> warnings;

  /// Arcos `G2`/`G3` convertidos a segmentos.
  final int arcCount;

  final int sourceLineCount;

  /// Extremos del volumen ocupado por la trayectoria (mm).
  final Vector3? min;
  final Vector3? max;

  bool get isEmpty => segments.isEmpty;
  int get blockCount => segments.length;

  /// Recorrido total en rápido (`G0`), en mm.
  double get rapidLengthMm => _sum((MotionSegment segment) => segment.rapid);

  /// Recorrido total de mecanizado (`G1` y arcos), en mm.
  double get cuttingLengthMm => _sum((MotionSegment segment) => !segment.rapid);

  double _sum(bool Function(MotionSegment segment) filter) {
    double total = 0;
    for (final MotionSegment segment in segments) {
      if (filter(segment)) {
        total += segment.lengthMm;
      }
    }
    return total;
  }

  @override
  String toString() =>
      'GcodeProgram($blockCount segmentos, $arcCount arcos, '
      '${warnings.length} avisos)';
}
