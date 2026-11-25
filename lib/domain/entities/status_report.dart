import 'machine_state.dart';

/// Status report de GRBL v1.1 (`<Idle|MPos:0.000,0.000,0.000|FS:0,0>`).
///
/// Los campos son opcionales porque la máscara `$10` decide qué se emite: un
/// equipo mal configurado puede no reportar `MPos`, `WCO` o `Bf`. La UI debe
/// funcionar con lo que llegue, nunca asumir un campo presente.
class StatusReport {
  const StatusReport({
    required this.state,
    required this.raw,
    this.machinePosition,
    this.workPosition,
    this.workCoordinateOffset,
    this.feedMmMin,
    this.spindleSpeed,
    this.plannerBlocks,
    this.rxBufferBytes,
  });

  final MachineState state;

  /// Línea original, útil para depuración y para mostrar en consola.
  final String raw;

  /// `MPos` — posición en coordenadas de máquina (X, Y, Z).
  final List<double>? machinePosition;

  /// `WPos` — posición en coordenadas de trabajo (X, Y, Z).
  final List<double>? workPosition;

  /// `WCO` — offset de trabajo (`WPos = MPos - WCO`).
  final List<double>? workCoordinateOffset;

  /// Primer valor de `FS` — avance programado en mm/min.
  final double? feedMmMin;

  /// Segundo valor de `FS` — consigna de husillo/láser (`S`).
  final double? spindleSpeed;

  /// Primer valor de `Bf` — bloques disponibles en el planner.
  ///
  /// Solo para diagnóstico: GRBL advierte explícitamente de que **no** debe
  /// usarse para controlar el streaming (ver `interface.md`).
  final int? plannerBlocks;

  /// Segundo valor de `Bf` — bytes disponibles en el búfer de recepción.
  final int? rxBufferBytes;

  /// Indica si la herramienta está consignada con potencia/velocidad > 0.
  bool get isSpindleOn => (spindleSpeed ?? 0) > 0;

  /// Posición de máquina resuelta, aplicando `WPos = MPos - WCO` si hace falta.
  List<double>? get resolvedMachinePosition {
    if (machinePosition != null) {
      return machinePosition;
    }
    final List<double>? work = workPosition;
    final List<double>? offset = workCoordinateOffset;
    if (work == null || offset == null) {
      return null;
    }
    return <double>[
      for (int i = 0; i < work.length; i++)
        work[i] + (i < offset.length ? offset[i] : 0.0),
    ];
  }

  /// Posición de trabajo resuelta, aplicando `WPos = MPos - WCO` si hace falta.
  List<double>? get resolvedWorkPosition {
    if (workPosition != null) {
      return workPosition;
    }
    final List<double>? machine = machinePosition;
    final List<double>? offset = workCoordinateOffset;
    if (machine == null || offset == null) {
      return null;
    }
    return <double>[
      for (int i = 0; i < machine.length; i++)
        machine[i] - (i < offset.length ? offset[i] : 0.0),
    ];
  }

  /// Parsea una línea de status report.
  ///
  /// Lanza [FormatException] si la línea no tiene el formato `<...>`.
  static StatusReport parse(String line) {
    final String trimmed = line.trim();
    if (trimmed.length < 2 ||
        !trimmed.startsWith('<') ||
        !trimmed.endsWith('>')) {
      throw FormatException('Status report inválido: $line');
    }

    final List<String> fields = trimmed
        .substring(1, trimmed.length - 1)
        .split('|');
    if (fields.isEmpty || fields.first.isEmpty) {
      throw FormatException('Status report sin estado: $line');
    }

    final MachineState state = MachineState.parse(fields.first);
    List<double>? mpos;
    List<double>? wpos;
    List<double>? wco;
    double? feed;
    double? spindle;
    int? blocks;
    int? rx;

    for (final String field in fields.skip(1)) {
      final int separator = field.indexOf(':');
      if (separator <= 0) {
        continue;
      }
      final String key = field.substring(0, separator);
      final String value = field.substring(separator + 1);

      switch (key) {
        case 'MPos':
          mpos = _parseVector(value);
        case 'WPos':
          wpos = _parseVector(value);
        case 'WCO':
          wco = _parseVector(value);
        case 'FS':
          final List<String> parts = value.split(',');
          if (parts.isNotEmpty) {
            feed = double.tryParse(parts[0]);
          }
          if (parts.length > 1) {
            spindle = double.tryParse(parts[1]);
          }
        case 'Bf':
          final List<String> parts = value.split(',');
          if (parts.isNotEmpty) {
            blocks = int.tryParse(parts[0]);
          }
          if (parts.length > 1) {
            rx = int.tryParse(parts[1]);
          }
      }
    }

    return StatusReport(
      state: state,
      raw: trimmed,
      machinePosition: mpos,
      workPosition: wpos,
      workCoordinateOffset: wco,
      feedMmMin: feed,
      spindleSpeed: spindle,
      plannerBlocks: blocks,
      rxBufferBytes: rx,
    );
  }

  static List<double>? _parseVector(String value) {
    final List<String> parts = value.split(',');
    final List<double> parsed = <double>[];
    for (final String part in parts) {
      final double? number = double.tryParse(part.trim());
      if (number == null) {
        return null;
      }
      parsed.add(number);
    }
    return parsed.isEmpty ? null : parsed;
  }

  @override
  String toString() =>
      'StatusReport(state: ${state.label}, mpos: $machinePosition, '
      'feed: $feedMmMin, spindle: $spindleSpeed)';
}
