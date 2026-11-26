import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../entities/gcode_program.dart';
import '../entities/motion_segment.dart';

/// Posición del cabezal simulado en un instante del programa.
class SimulationCursor {
  const SimulationCursor({
    required this.segmentIndex,
    required this.seconds,
    required this.position,
    required this.lineIndex,
    required this.rapid,
  });

  /// Segmento que se está recorriendo (base 0).
  final int segmentIndex;

  /// Instante del programa, en segundos.
  final double seconds;

  /// Posición interpolada dentro del segmento (mm).
  final Vector3 position;

  /// Línea del archivo que originó el segmento (base 0).
  final int lineIndex;

  final bool rapid;

  @override
  String toString() =>
      'SimulationCursor(seg $segmentIndex, ${seconds.toStringAsFixed(2)} s, '
      '$position, línea ${lineIndex + 1})';
}

/// Reparto del tiempo de programa entre los segmentos del visor.
///
/// El simulador no consulta la máquina: el reloj sale de la geometría y de los
/// avances del propio G-code (`longitud / avance`), de modo que la reproducción
/// muestra el orden y las proporciones reales del trabajo. Los `G0` no llevan
/// `F`, así que se les supone [rapidFeedMmMin] (en GRBL depende de `$110`–`$112`).
class SimulationTimeline {
  SimulationTimeline({
    required this.program,
    this.rapidFeedMmMin = 5000,
    this.defaultFeedMmMin = 800,
    this.minimumSegmentSeconds = 0.002,
  }) {
    final List<MotionSegment> segments = program.segments;
    _starts = List<double>.filled(segments.length, 0);
    double elapsed = 0;
    for (int i = 0; i < segments.length; i++) {
      _starts[i] = elapsed;
      elapsed += _durationOf(segments[i]);
    }
    _total = elapsed;
  }

  final GcodeProgram program;

  /// Avance supuesto para los rápidos (los `G0` no llevan `F`).
  final double rapidFeedMmMin;

  /// Avance supuesto cuando un `G1` llega sin `F`.
  final double defaultFeedMmMin;

  /// Suelo de duración por segmento.
  ///
  /// Evita que los bloques de longitud cero (cambios de herramienta, `G4`,
  /// puntos repetidos) congelen el reloj o provoquen divisiones por cero.
  final double minimumSegmentSeconds;

  late final List<double> _starts;
  late final double _total;

  int get segmentCount => program.segments.length;

  double get totalSeconds => _total;

  bool get isEmpty => segmentCount == 0;

  /// Instante en que empieza el segmento [index].
  double startSeconds(int index) {
    if (_starts.isEmpty) {
      return 0;
    }
    return _starts[index.clamp(0, _starts.length - 1)];
  }

  /// Instante en que termina el segmento [index].
  double endSeconds(int index) {
    if (_starts.isEmpty) {
      return 0;
    }
    final int clamped = index.clamp(0, _starts.length - 1);
    return clamped + 1 < _starts.length ? _starts[clamped + 1] : _total;
  }

  /// Segmento activo en [seconds] (binaria sobre los inicios acumulados).
  int indexAt(double seconds) {
    if (_starts.isEmpty) {
      return 0;
    }
    final double clamped = seconds.clamp(0.0, _total);
    int low = 0;
    int high = _starts.length - 1;
    while (low < high) {
      final int middle = (low + high + 1) >> 1;
      if (_starts[middle] <= clamped) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  /// Fracción recorrida (0..1) del segmento [index] en [seconds].
  double fractionAt(int index, double seconds) {
    final double duration = endSeconds(index) - startSeconds(index);
    if (duration <= 0) {
      return 1;
    }
    return ((seconds - startSeconds(index)) / duration).clamp(0.0, 1.0);
  }

  /// Cabezal simulado en [seconds]; `null` si el programa no tiene segmentos.
  SimulationCursor? cursorAt(double seconds) {
    if (segmentCount == 0) {
      return null;
    }
    final double clamped = seconds.clamp(0.0, _total);
    final int index = indexAt(clamped);
    final MotionSegment segment = program.segments[index];
    final double fraction = fractionAt(index, clamped);
    final Vector3 position = fraction <= 0
        ? segment.start
        : (fraction >= 1
              ? segment.end
              : segment.start + segment.delta * fraction);
    return SimulationCursor(
      segmentIndex: index,
      seconds: clamped,
      position: position,
      lineIndex: program.lineIndexes[index],
      rapid: segment.rapid,
    );
  }

  /// Duración de un segmento según su avance.
  double _durationOf(MotionSegment segment) {
    final double feed = segment.rapid
        ? rapidFeedMmMin
        : (segment.feedMmMin ?? defaultFeedMmMin);
    final double safeFeed = feed > 0 ? feed : defaultFeedMmMin;
    final double seconds = segment.lengthMm / safeFeed * 60;
    return math.max(seconds, minimumSegmentSeconds);
  }
}
