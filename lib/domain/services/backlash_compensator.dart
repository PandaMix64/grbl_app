/// Resultado de compensar la holgura de un programa.
class BacklashCompensationResult {
  const BacklashCompensationResult({
    required this.gcode,
    required this.compensationsX,
    required this.compensationsY,
  });

  final List<String> gcode;
  final int compensationsX;
  final int compensationsY;

  int get total => compensationsX + compensationsY;

  @override
  String toString() =>
      'BacklashCompensationResult($total compensaciones: '
      'X=$compensationsX, Y=$compensationsY)';
}

/// Compensa la holgura mecánica **con movimiento real**, nunca con `G92`
/// (hallazgo P0-2 de la revisión técnica).
///
/// Modelo físico: la mesa queda retrasada respecto al motor en el momento de
/// invertir el sentido. Al detectar una inversión se emite un movimiento corto
/// de `holgura` en el nuevo sentido, que consume el juego mecánico; a partir de
/// ahí el resto del bloque mueve la mesa exactamente lo ordenado. Todo ocurre en
/// coordenadas de motor, así que no se falsea ningún origen.
///
/// Limitaciones conocidas y deliberadas:
/// * no compensa `Z` (la fuerza de la herramienta lo haría peligroso),
/// * no compensa arcos `G2`/`G3` (solo actualiza la posición estimada),
/// * la primera aparición de un eje no compensa: se desconoce el estado inicial.
class BacklashCompensator {
  const BacklashCompensator({
    required this.backlashXmm,
    required this.backlashYmm,
    this.fallbackFeedMmMin = 800,
  });

  final double backlashXmm;
  final double backlashYmm;

  /// Avance a usar si el programa aún no ha fijado un `F`.
  final double fallbackFeedMmMin;

  /// Devuelve el programa con las compensaciones inyectadas.
  BacklashCompensationResult process(Iterable<String> lines) {
    final List<String> output = <String>[];
    double x = 0;
    double y = 0;
    double? feed;
    int lastDirX = 0;
    int lastDirY = 0;
    int compensationsX = 0;
    int compensationsY = 0;

    for (final String line in lines) {
      final Map<String, double>? words = _parseWords(line);
      if (words == null) {
        output.add(line);
        continue;
      }

      final double? g = words['G'];
      final bool isLinear = g != null && (g == 0 || g == 1);
      final bool hasAxis =
          words.containsKey('X') ||
          words.containsKey('Y') ||
          words.containsKey('Z');

      if (!isLinear || !hasAxis) {
        output.add(line);
        continue;
      }

      final double targetX = words['X'] ?? x;
      final double targetY = words['Y'] ?? y;
      final double? lineFeed = words['F'];
      final double effectiveFeed = lineFeed ?? feed ?? fallbackFeedMmMin;

      final int dirX = _sign(targetX - x);
      final int dirY = _sign(targetY - y);

      if (dirX != 0 && backlashXmm > 0 && lastDirX != 0 && dirX != lastDirX) {
        x += backlashXmm * dirX;
        output.add('G1 X${_format(x)} F${_format(effectiveFeed)}');
        compensationsX++;
      }
      if (dirY != 0 && backlashYmm > 0 && lastDirY != 0 && dirY != lastDirY) {
        y += backlashYmm * dirY;
        output.add('G1 Y${_format(y)} F${_format(effectiveFeed)}');
        compensationsY++;
      }

      output.add(line);
      x = targetX;
      y = targetY;
      if (dirX != 0) {
        lastDirX = dirX;
      }
      if (dirY != 0) {
        lastDirY = dirY;
      }
      feed = lineFeed ?? feed;
    }

    return BacklashCompensationResult(
      gcode: output,
      compensationsX: compensationsX,
      compensationsY: compensationsY,
    );
  }

  /// Extrae `letra → valor` de una línea; `null` si es comentario, vacía o un
  /// comando sin palabras numéricas.
  static Map<String, double>? _parseWords(String line) {
    final String body = line.split(';').first.trim();
    if (body.isEmpty || body.startsWith('(')) {
      return null;
    }
    final Map<String, double> words = <String, double>{};
    final RegExp pattern = RegExp(r'([A-Za-z])\s*(-?\d*\.?\d+)');
    for (final RegExpMatch match in pattern.allMatches(body)) {
      final String letter = match.group(1)!.toUpperCase();
      final double? value = double.tryParse(match.group(2)!);
      if (value != null) {
        words[letter] = value;
      }
    }
    return words.isEmpty ? null : words;
  }

  static int _sign(double value) {
    if (value > 1e-9) {
      return 1;
    }
    if (value < -1e-9) {
      return -1;
    }
    return 0;
  }

  static String _format(double value) => value.toStringAsFixed(3);
}
