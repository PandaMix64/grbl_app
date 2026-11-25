/// Offsets de trabajo y parámetros de coordenadas, obtenidos con `$#`.
///
/// Incluye `G54`–`G59`, `G28`/`G30`, `G92`, `TLO` y `PRB`. Solo `G54`–`G59` y
/// `G28`/`G30` son persistentes; `G92`, `G43.1` y `PRB` se pierden en reset.
class WorkOffsets {
  const WorkOffsets({required this.entries});

  /// Mapa `clave → valores` (`G54 → [x, y, z]`, `TLO → [z]`).
  final Map<String, List<double>> entries;

  List<double>? operator [](String key) => entries[key];

  bool get isEmpty => entries.isEmpty;

  /// Parsea las líneas `[G54:...]`, `[G92:...]`, `[TLO:...]`, etc.
  factory WorkOffsets.parse(Iterable<String> lines) {
    final Map<String, List<double>> entries = <String, List<double>>{};
    for (final String rawLine in lines) {
      final String line = rawLine.trim();
      if (!line.startsWith('[') || !line.endsWith(']')) {
        continue;
      }
      final int colon = line.indexOf(':');
      if (colon <= 1) {
        continue;
      }
      final String key = line.substring(1, colon);
      String body = line.substring(colon + 1, line.length - 1);
      // `PRB` lleva el indicador de éxito tras dos puntos: `[PRB:0,0,0:1]`.
      final int extra = body.indexOf(':');
      if (extra >= 0) {
        body = body.substring(0, extra);
      }
      final List<double> values = <double>[];
      for (final String part in body.split(',')) {
        final double? value = double.tryParse(part.trim());
        if (value == null) {
          values.clear();
          break;
        }
        values.add(value);
      }
      if (values.isNotEmpty) {
        entries[key] = values;
      }
    }
    return WorkOffsets(entries: entries);
  }

  /// Compara dos instantáneas con tolerancia (mm).
  bool matches(WorkOffsets other, {double tolerance = 0.001}) {
    if (entries.length != other.entries.length) {
      return false;
    }
    for (final MapEntry<String, List<double>> entry in entries.entries) {
      final List<double>? theirs = other.entries[entry.key];
      if (theirs == null || theirs.length != entry.value.length) {
        return false;
      }
      for (int i = 0; i < entry.value.length; i++) {
        if ((entry.value[i] - theirs[i]).abs() > tolerance) {
          return false;
        }
      }
    }
    return true;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'entries': <String, Object?>{
      for (final MapEntry<String, List<double>> entry in entries.entries)
        entry.key: entry.value,
    },
  };

  factory WorkOffsets.fromJson(Map<String, Object?> json) {
    final Object? raw = json['entries'];
    final Map<String, List<double>> entries = <String, List<double>>{};
    if (raw is Map) {
      for (final MapEntry<Object?, Object?> entry in raw.entries) {
        final Object? key = entry.key;
        final Object? value = entry.value;
        if (key is String && value is List) {
          entries[key] = <double>[
            for (final Object? item in value)
              if (item is num) item.toDouble(),
          ];
        }
      }
    }
    return WorkOffsets(entries: entries);
  }

  @override
  String toString() => 'WorkOffsets(${entries.keys.join(', ')})';
}
