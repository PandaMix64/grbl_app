/// Estado modal del parser de G-code de GRBL, obtenido con `$G`.
///
/// Es imprescindible para reanudar un trabajo (SEG-05): después de un reset o
/// una desconexión, GRBL no recuerda nada y la app debe reenviar explícitamente
/// unidades, distancia, sistema de coordenadas y estado de la herramienta.
class ParserState {
  const ParserState({required this.words, required this.raw});

  /// Palabras modales en orden de aparición (`G0`, `G54`, `G21`, `G90`, `M5`...).
  final List<String> words;

  /// Línea original (`[GC:G0 G54 G17 G21 G90 G94 M5 M9 T0 F0 S0]`).
  final String raw;

  /// Parsea la línea `[GC:...]`.
  factory ParserState.parse(String line) {
    final String trimmed = line.trim();
    if (!trimmed.startsWith('[GC:')) {
      throw FormatException('Estado del parser inválido: $line');
    }
    String body = trimmed.substring(4);
    if (body.endsWith(']')) {
      body = body.substring(0, body.length - 1);
    }
    final List<String> words = body
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      throw FormatException('Estado del parser vacío: $line');
    }
    return ParserState(words: words, raw: trimmed);
  }

  /// Construye el estado a partir de palabras sueltas (para pruebas o restore).
  factory ParserState.fromWords(Iterable<String> words) {
    final List<String> list = words.toList(growable: false);
    return ParserState(words: list, raw: '[GC:${list.join(' ')}]');
  }

  bool get isAbsolute => words.contains('G90');
  bool get isIncremental => words.contains('G91');
  bool get isMetric => words.contains('G21');
  bool get isInches => words.contains('G20');

  /// Modo de movimiento activo (`G0`..`G3`).
  String get motionMode => _firstMatching(RegExp(r'^G[0-3]$'), 'G0');

  /// Sistema de coordenadas de trabajo (`G54`..`G59`).
  String get workCoordinateSystem =>
      _firstMatching(RegExp(r'^G5[4-9]$'), 'G54');

  /// Modo de husillo/láser (`M3` constante, `M4` dinámico, `M5` apagado).
  String get spindleMode => _firstMatching(RegExp(r'^M[345]$'), 'M5');

  /// Avance modal (`F`), o `null` si no está definido.
  double? get feed => _value('F');

  /// Consigna de husillo/láser (`S`), o `null` si no está definida.
  double? get spindle => _value('S');

  /// `true` si el láser está en modo dinámico (el correcto para grabado).
  bool get usesDynamicLaserPower => spindleMode == 'M4';

  /// Compara el estado modal **relevante** para reanudar: unidades, distancia,
  /// sistema de coordenadas, modo de movimiento y herramienta. Ignora `F`/`S`/`T`.
  bool isCompatibleWith(ParserState other) {
    return motionMode == other.motionMode &&
        workCoordinateSystem == other.workCoordinateSystem &&
        spindleMode == other.spindleMode &&
        isMetric == other.isMetric &&
        isAbsolute == other.isAbsolute;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'words': words,
    'raw': raw,
  };

  factory ParserState.fromJson(Map<String, Object?> json) {
    final Object? words = json['words'];
    if (words is! List) {
      throw const FormatException('Estado del parser sin palabras.');
    }
    return ParserState(
      words: <String>[
        for (final Object? word in words)
          if (word is String) word,
      ],
      raw: json['raw'] as String? ?? '',
    );
  }

  String _firstMatching(RegExp pattern, String fallback) {
    for (final String word in words) {
      if (pattern.hasMatch(word)) {
        return word;
      }
    }
    return fallback;
  }

  double? _value(String prefix) {
    for (final String word in words) {
      if (word.startsWith(prefix)) {
        return double.tryParse(word.substring(prefix.length));
      }
    }
    return null;
  }

  @override
  String toString() => 'ParserState(${words.join(' ')})';
}
