import 'axis.dart';

/// Conjunto de parámetros `$x=valor` leídos del controlador (`$$`).
///
/// Se conserva el valor como texto para no perder la precisión ni el formato
/// original de GRBL, y se ofrecen accesos tipados para los códigos usados por
/// la aplicación.
class GrblSettings {
  GrblSettings._(this._values);

  final Map<int, String> _values;

  /// Crea un mapa vacío (útil cuando aún no se ha leído la EEPROM).
  factory GrblSettings.empty() => GrblSettings._(<int, String>{});

  /// Parsea la respuesta completa de `$$` (una o varias líneas `$x=valor`).
  ///
  /// Ignora líneas vacías, `ok` y cualquier texto que no sea un parámetro.
  factory GrblSettings.parse(String payload) {
    final Map<int, String> values = <int, String>{};
    for (final String rawLine in payload.split(RegExp(r'\r?\n'))) {
      final String line = rawLine.trim();
      if (!line.startsWith(r'$')) {
        continue;
      }
      final int equals = line.indexOf('=');
      if (equals <= 1) {
        continue;
      }
      final int? code = int.tryParse(line.substring(1, equals));
      if (code == null) {
        continue;
      }
      values[code] = line.substring(equals + 1).trim();
    }
    return GrblSettings._(values);
  }

  /// Códigos cuyos valores GRBL expone como enteros.
  static const Set<int> _integerCodes = <int>{
    0,
    1,
    3,
    4,
    5,
    6,
    10,
    13,
    20,
    21,
    22,
    23,
    26,
    32,
  };

  /// Etiquetas de los parámetros más relevantes; GRBL v1.1 ya no las envía.
  static const Map<int, String> labels = <int, String>{
    0: 'Duración del pulso de paso (µs)',
    1: 'Retardo de reposo del motor (ms)',
    2: 'Inversión del pulso de paso',
    3: 'Inversión de dirección',
    4: 'Invertir habilitación de motores',
    5: 'Invertir límites (finales de carrera)',
    6: 'Invertir pin de sonda',
    10: 'Máscara del status report',
    11: 'Desviación de unión (mm)',
    12: 'Tolerancia de arco (mm)',
    13: 'Reportar en pulgadas',
    20: 'Soft limits habilitados',
    21: 'Hard limits habilitados',
    22: 'Homing habilitado',
    23: 'Dirección de homing',
    24: 'Velocidad de homing (mm/min)',
    25: 'Velocidad de búsqueda de homing (mm/min)',
    26: 'Retardo de debounce de límites (ms)',
    27: 'Distancia de pull-off de homing (mm)',
    30: 'Velocidad máxima del husillo (RPM)',
    31: 'Velocidad mínima del husillo (RPM)',
    32: 'Modo láser',
    100: 'Pasos/mm X',
    101: 'Pasos/mm Y',
    102: 'Pasos/mm Z',
    110: 'Velocidad máxima X (mm/min)',
    111: 'Velocidad máxima Y (mm/min)',
    112: 'Velocidad máxima Z (mm/min)',
    120: 'Aceleración X (mm/s²)',
    121: 'Aceleración Y (mm/s²)',
    122: 'Aceleración Z (mm/s²)',
    130: 'Recorrido máximo X (mm)',
    131: 'Recorrido máximo Y (mm)',
    132: 'Recorrido máximo Z (mm)',
  };

  /// Códigos presentes, ordenados.
  List<int> get codes {
    final List<int> result = _values.keys.toList()..sort();
    return result;
  }

  /// Valor textual original de un parámetro.
  String? rawValue(int code) => _values[code];

  /// Indica si el parámetro fue leído.
  bool has(int code) => _values.containsKey(code);

  /// Valor numérico, o `null` si no existe o no es parseable.
  double? number(int code) => double.tryParse(_values[code] ?? '');

  /// Valor entero, o `null` si no existe o no es parseable.
  int? integer(int code) => number(code)?.round();

  bool get isLaserMode => integer(32) == 1;
  bool get softLimitsEnabled => integer(20) == 1;
  bool get hardLimitsEnabled => integer(21) == 1;
  bool get homingEnabled => integer(22) == 1;

  double? stepsPerMm(MachineAxis axis) => number(axis.stepsPerMmCode);
  double? maxRate(MachineAxis axis) => number(axis.maxRateCode);
  double? acceleration(MachineAxis axis) => number(axis.accelerationCode);
  double? maxTravel(MachineAxis axis) => number(axis.maxTravelCode);

  /// Devuelve una copia con el parámetro actualizado.
  GrblSettings withValue(int code, num value) {
    final Map<int, String> copy = Map<int, String>.of(_values);
    copy[code] = _format(code, value);
    return GrblSettings._(copy);
  }

  /// Cambios necesarios para igualar [target] sin escribir de más.
  ///
  /// Escribir EEPROM desgasta el ATmega (~10⁵ ciclos), así que solo se emiten
  /// los parámetros que realmente difieren.
  Map<int, String> diff(GrblSettings target) {
    final Map<int, String> changes = <int, String>{};
    for (final MapEntry<int, String> entry in target._values.entries) {
      if (_values[entry.key] != entry.value) {
        changes[entry.key] = entry.value;
      }
    }
    return changes;
  }

  /// Líneas de comando listas para enviar al controlador.
  List<String> toCommands([Iterable<int>? onlyCodes]) {
    final Iterable<int> codesToWrite = onlyCodes ?? codes;
    return <String>[
      for (final int code in codesToWrite)
        if (_values.containsKey(code))
          r'$'
              '$code=${_values[code]}',
    ];
  }

  static String _format(int code, num value) {
    if (_integerCodes.contains(code)) {
      return value.round().toString();
    }
    return value.toStringAsFixed(3);
  }

  /// Serializa los parámetros como `{código: valor}` para cruzar isolates o
  /// guardarse en un perfil.
  Map<String, Object?> toJson() => <String, Object?>{
    for (final MapEntry<int, String> entry in _values.entries)
      entry.key.toString(): entry.value,
  };

  factory GrblSettings.fromJson(Map<String, Object?> json) {
    final Map<int, String> values = <int, String>{};
    for (final MapEntry<String, Object?> entry in json.entries) {
      final int? code = int.tryParse(entry.key);
      final Object? value = entry.value;
      if (code != null && value is String) {
        values[code] = value;
      }
    }
    return GrblSettings._(values);
  }

  @override
  String toString() => 'GrblSettings(${codes.length} parámetros)';
}
