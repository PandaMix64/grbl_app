/// Información de compilación del firmware, obtenida con `$I`.
///
/// Es la única forma documentada de conocer el **tamaño real** del búfer de
/// recepción sin asumir los 128 B del ATmega328P: GRBL publica en
/// `[OPT:<flags>,<bloques del planner>,<bytes del búfer RX>]`.
class BuildInfo {
  const BuildInfo({
    required this.version,
    required this.optionFlags,
    required this.plannerBlocks,
    required this.rxBufferSize,
    this.buildDate,
  });

  /// Versión del firmware, por ejemplo `1.1h`.
  final String version;

  /// Fecha de compilación del firmware (`20190825`), si está presente.
  final String? buildDate;

  /// Letras de opciones de compilación (`V`, `N`, `M`, `C`...).
  final String optionFlags;

  /// Bloques del planner (15 en el 328P: `BLOCK_BUFFER_SIZE - 1`).
  final int plannerBlocks;

  /// Bytes del búfer de recepción serial (`RX_BUFFER_SIZE`).
  final int rxBufferSize;

  bool get hasVariableSpindle => optionFlags.contains('V');
  bool get hasLineNumbers => optionFlags.contains('N');
  bool get hasMistCoolant => optionFlags.contains('M');
  bool get hasCoreXY => optionFlags.contains('C');

  /// Parsea las líneas `[VER:...]` y `[OPT:...]` de la respuesta de `$I`.
  factory BuildInfo.fromLines(Iterable<String> lines) {
    String? versionLine;
    String? optionsLine;
    for (final String line in lines) {
      if (line.startsWith('[VER:')) {
        versionLine = line;
      } else if (line.startsWith('[OPT:')) {
        optionsLine = line;
      }
    }
    if (versionLine == null || optionsLine == null) {
      throw const FormatException(
        'Build info incompleta: se esperaban las líneas [VER:] y [OPT:].',
      );
    }

    final List<String> versionParts = _body(versionLine, 'VER').split('.');
    String? date;
    List<String> versionWords = versionParts;
    if (versionParts.length >= 3 &&
        RegExp(r'^\d{8}$').hasMatch(versionParts.last)) {
      date = versionParts.last;
      versionWords = versionParts.sublist(0, versionParts.length - 1);
    }
    final String version = versionWords.join('.');
    if (version.isEmpty) {
      throw const FormatException('Build info sin versión de firmware.');
    }

    final List<String> optionParts = _body(optionsLine, 'OPT').split(',');
    final List<int> numbers = <int>[
      for (final String part in optionParts.skip(1))
        if (int.tryParse(part.trim()) != null) int.parse(part.trim()),
    ];
    if (numbers.length < 2) {
      throw const FormatException(
        'Build info sin tamaño de planner y búfer: se esperaba '
        '[OPT:<flags>,<bloques>,<bytes>].',
      );
    }

    return BuildInfo(
      version: version,
      buildDate: date,
      optionFlags: optionParts.first.trim(),
      plannerBlocks: numbers[0],
      rxBufferSize: numbers[1],
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'buildDate': buildDate,
    'optionFlags': optionFlags,
    'plannerBlocks': plannerBlocks,
    'rxBufferSize': rxBufferSize,
  };

  factory BuildInfo.fromJson(Map<String, Object?> json) {
    return BuildInfo(
      version: json['version'] as String? ?? '',
      buildDate: json['buildDate'] as String?,
      optionFlags: json['optionFlags'] as String? ?? '',
      plannerBlocks: (json['plannerBlocks'] as num?)?.toInt() ?? 0,
      rxBufferSize: (json['rxBufferSize'] as num?)?.toInt() ?? 0,
    );
  }

  static String _body(String line, String tag) {
    final String prefix = '[$tag:';
    String body = line.trim();
    if (body.startsWith(prefix)) {
      body = body.substring(prefix.length);
    }
    if (body.endsWith(']')) {
      body = body.substring(0, body.length - 1);
    }
    // GRBL cierra la versión con dos puntos: `[VER:1.1h.20190825:]`.
    if (body.endsWith(':')) {
      body = body.substring(0, body.length - 1);
    }
    return body;
  }

  @override
  String toString() =>
      'BuildInfo(v$version, opciones "$optionFlags", '
      '$plannerBlocks bloques, ${rxBufferSize}B RX)';
}
