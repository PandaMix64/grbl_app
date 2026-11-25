import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../entities/gcode_program.dart';
import '../entities/motion_segment.dart';

/// Interpreta G-code de GRBL y lo convierte en segmentos rectilíneos.
///
/// Soporta lo que necesita el visor: `G0`/`G1`, arcos `G2`/`G3` con `I`/`J` o
/// `R` (subdivididos), modos `G90`/`G91` y unidades `G20`/`G21`. Los códigos que
/// no afectan a la geometría (`M3`, `S`, `F`, `G54`, `G17`...) se aceptan y se
/// ignoran; los que cambian de sistema de coordenadas (`G28`, `G30`, `G53`,
/// `G92`) se ignoran **con aviso**, porque el visor simula coordenadas de trabajo.
class GcodeInterpreter {
  const GcodeInterpreter({
    this.arcSegmentDegrees = 5,
    this.defaultFeedMmMin = 800,
  });

  /// Máximo ángulo (grados) de cada segmento en que se subdivide un arco.
  final double arcSegmentDegrees;

  /// Avance asumido cuando el programa aún no ha fijado `F`.
  final double defaultFeedMmMin;

  GcodeProgram parse(String source) {
    final List<MotionSegment> segments = <MotionSegment>[];
    final List<int> lineIndexes = <int>[];
    final List<String> warnings = <String>[];

    double x = 0;
    double y = 0;
    double z = 0;
    double? feed;
    bool absolute = true;
    double scale = 1;
    int arcCount = 0;

    double minX = double.infinity;
    double minY = double.infinity;
    double minZ = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    double maxZ = double.negativeInfinity;

    void track(double px, double py, double pz) {
      minX = math.min(minX, px);
      minY = math.min(minY, py);
      minZ = math.min(minZ, pz);
      maxX = math.max(maxX, px);
      maxY = math.max(maxY, py);
      maxZ = math.max(maxZ, pz);
    }

    final List<String> lines = source.split('\n');

    for (int index = 0; index < lines.length; index++) {
      final _Block? block = _Block.parse(lines[index]);
      if (block == null) {
        continue;
      }

      for (final double code in block.codes) {
        if (code == 20) {
          scale = 25.4;
        } else if (code == 21) {
          scale = 1;
        } else if (code == 90) {
          absolute = true;
        } else if (code == 91) {
          absolute = false;
        }
      }

      final double? f = block.value('F');
      if (f != null) {
        feed = f * scale;
      }

      double? motion;
      for (final double code in block.codes) {
        if (code == 0 || code == 1 || code == 2 || code == 3) {
          motion = code;
        }
      }
      if (motion == null) {
        _checkUnsupported(block, warnings, index);
        continue;
      }

      final double? wx = block.value('X');
      final double? wy = block.value('Y');
      final double? wz = block.value('Z');
      final double targetX = wx == null
          ? x
          : (absolute ? wx * scale : x + wx * scale);
      final double targetY = wy == null
          ? y
          : (absolute ? wy * scale : y + wy * scale);
      final double targetZ = wz == null
          ? z
          : (absolute ? wz * scale : z + wz * scale);
      final double feedRate = feed ?? defaultFeedMmMin;

      if (motion <= 1) {
        if (targetX == x && targetY == y && targetZ == z) {
          continue;
        }
        segments.add(
          MotionSegment(
            start: Vector3(x, y, z),
            end: Vector3(targetX, targetY, targetZ),
            rapid: motion == 0,
            feedMmMin: motion == 0 ? null : feedRate,
          ),
        );
        lineIndexes.add(index);
        track(x, y, z);
        track(targetX, targetY, targetZ);
        x = targetX;
        y = targetY;
        z = targetZ;
        continue;
      }

      // Arcos G2 (horario) / G3 (antihorario).
      final double? i = block.value('I');
      final double? j = block.value('J');
      final double? r = block.value('R');
      final bool clockwise = motion == 2;

      double? centerX;
      double? centerY;
      if (i != null || j != null) {
        centerX = x + (i ?? 0) * scale;
        centerY = y + (j ?? 0) * scale;
      } else if (r != null) {
        final (double?, double?) computed = _centerFromRadius(
          x0: x,
          y0: y,
          x1: targetX,
          y1: targetY,
          radius: r * scale,
          clockwise: clockwise,
        );
        centerX = computed.$1;
        centerY = computed.$2;
        if (centerX == null) {
          warnings.add(
            'Línea ${index + 1}: arco imposible con R=${r.toStringAsFixed(3)}.',
          );
        }
      } else {
        warnings.add(
          'Línea ${index + 1}: arco sin I/J ni R; se trata como recta.',
        );
      }

      if (centerX == null || centerY == null) {
        segments.add(
          MotionSegment(
            start: Vector3(x, y, z),
            end: Vector3(targetX, targetY, targetZ),
            feedMmMin: feedRate,
          ),
        );
        lineIndexes.add(index);
        track(x, y, z);
        track(targetX, targetY, targetZ);
        x = targetX;
        y = targetY;
        z = targetZ;
        continue;
      }

      final double radius = math.sqrt(
        math.pow(x - centerX, 2) + math.pow(y - centerY, 2),
      );
      final double endRadius = math.sqrt(
        math.pow(targetX - centerX, 2) + math.pow(targetY - centerY, 2),
      );
      if ((radius - endRadius).abs() > 0.05) {
        warnings.add(
          'Línea ${index + 1}: el punto final no está sobre el arco '
          '(r=${radius.toStringAsFixed(3)} vs '
          '${endRadius.toStringAsFixed(3)}).',
        );
      }

      final double startAngle = math.atan2(y - centerY, x - centerX);
      final double endAngle = math.atan2(targetY - centerY, targetX - centerX);
      double sweep;
      if (clockwise) {
        sweep = startAngle - endAngle;
        while (sweep <= 0) {
          sweep += 2 * math.pi;
        }
      } else {
        sweep = endAngle - startAngle;
        while (sweep <= 0) {
          sweep += 2 * math.pi;
        }
      }
      // Círculo completo: GRBL repite el punto de inicio con I/J definidos.
      final bool fullCircle =
          (x - targetX).abs() < 1e-6 && (y - targetY).abs() < 1e-6;
      if (fullCircle) {
        sweep = 2 * math.pi;
      }

      final double step = math.max(arcSegmentDegrees, 0.5) * math.pi / 180;
      final int steps = math.max(2, (sweep / step).ceil());
      double previousX = x;
      double previousY = y;
      double previousZ = z;
      for (int s = 1; s <= steps; s++) {
        final double t = s / steps;
        final double angle = clockwise
            ? startAngle - sweep * t
            : startAngle + sweep * t;
        final double px = s == steps
            ? targetX
            : centerX + radius * math.cos(angle);
        final double py = s == steps
            ? targetY
            : centerY + radius * math.sin(angle);
        final double pz = z + (targetZ - z) * t;
        segments.add(
          MotionSegment(
            start: Vector3(previousX, previousY, previousZ),
            end: Vector3(px, py, pz),
            feedMmMin: feedRate,
          ),
        );
        lineIndexes.add(index);
        track(previousX, previousY, previousZ);
        track(px, py, pz);
        previousX = px;
        previousY = py;
        previousZ = pz;
      }
      arcCount++;
      x = targetX;
      y = targetY;
      z = targetZ;
    }

    return GcodeProgram(
      segments: segments,
      lineIndexes: lineIndexes,
      warnings: warnings,
      arcCount: arcCount,
      sourceLineCount: lines.length,
      min: minX.isFinite ? Vector3(minX, minY, minZ) : null,
      max: maxX.isFinite ? Vector3(maxX, maxY, maxZ) : null,
    );
  }

  /// Centro del arco a partir del radio `R` (forma alternativa a `I`/`J`).
  ///
  /// Devuelve `(null, null)` si el arco es imposible (cuerda mayor que 2R).
  /// Con `R` positivo se elige el arco menor; con `R` negativo, el mayor.
  static (double?, double?) _centerFromRadius({
    required double x0,
    required double y0,
    required double x1,
    required double y1,
    required double radius,
    required bool clockwise,
  }) {
    final double dx = x1 - x0;
    final double dy = y1 - y0;
    final double chord = math.sqrt(dx * dx + dy * dy);
    if (chord == 0 || chord > 2 * radius.abs()) {
      return (null, null);
    }
    final double r = radius.abs();
    final double h = math.sqrt(r * r - (chord / 2) * (chord / 2));
    final double midX = (x0 + x1) / 2;
    final double midY = (y0 + y1) / 2;
    final double perpX = -dy / chord;
    final double perpY = dx / chord;

    final List<(double, double)> candidates = <(double, double)>[
      (midX + perpX * h, midY + perpY * h),
      (midX - perpX * h, midY - perpY * h),
    ];
    for (final (double cx, double cy) in candidates) {
      final double start = math.atan2(y0 - cy, x0 - cx);
      final double end = math.atan2(y1 - cy, x1 - cx);
      double sweep = clockwise ? start - end : end - start;
      while (sweep <= 0) {
        sweep += 2 * math.pi;
      }
      final bool minor = sweep <= math.pi + 1e-9;
      if (radius > 0 ? minor : !minor) {
        return (cx, cy);
      }
    }
    return (candidates.first.$1, candidates.first.$2);
  }

  static void _checkUnsupported(
    _Block block,
    List<String> warnings,
    int index,
  ) {
    const Set<int> ignored = <int>{28, 30, 53, 92};
    for (final double code in block.codes) {
      if (ignored.contains(code.round())) {
        warnings.add(
          'Línea ${index + 1}: G${code.round()} se ignora en el visor '
          '(cambia el sistema de coordenadas en la máquina).',
        );
        return;
      }
    }
  }
}

/// Bloque de G-code con sus palabras separadas.
class _Block {
  _Block(this.codes, this._values);

  /// Códigos `G` en el orden en que aparecen (un bloque puede traer varios).
  final List<double> codes;

  final Map<String, double> _values;

  double? value(String letter) => _values[letter];

  static _Block? parse(String line) {
    String body = line;
    final int parenthesis = body.indexOf('(');
    if (parenthesis >= 0) {
      body = body.substring(0, parenthesis);
    }
    final int semicolon = body.indexOf(';');
    if (semicolon >= 0) {
      body = body.substring(0, semicolon);
    }
    body = body.trim();
    if (body.isEmpty || body == '%') {
      return null;
    }

    final List<double> codes = <double>[];
    final Map<String, double> values = <String, double>{};
    final RegExp pattern = RegExp(r'([A-Za-z])\s*(-?\d*\.?\d+)');
    for (final RegExpMatch match in pattern.allMatches(body)) {
      final String letter = match.group(1)!.toUpperCase();
      final double? parsed = double.tryParse(match.group(2)!);
      if (parsed == null) {
        continue;
      }
      if (letter == 'G') {
        codes.add(parsed);
      } else {
        values[letter] = parsed;
      }
    }
    if (codes.isEmpty && values.isEmpty) {
      return null;
    }
    return _Block(codes, values);
  }
}
