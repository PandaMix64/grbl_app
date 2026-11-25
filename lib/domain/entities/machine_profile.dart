/// Tipo de herramienta: define cómo se controla el cabezal.
enum ToolType {
  plotter,
  laser,
  mill;

  static ToolType parse(String? value) {
    return switch (value) {
      'plotter' => ToolType.plotter,
      'laser' => ToolType.laser,
      'mill' => ToolType.mill,
      _ => ToolType.mill,
    };
  }
}

/// Perfil local de máquina: lo que vive en la app y **no** en la EEPROM.
///
/// GRBL solo guarda los parámetros `$x`. Todo lo demás —altura segura, holgura,
/// modalidad de herramienta y volumen de trabajo— pertenece al perfil.
class MachineProfile {
  const MachineProfile({
    required this.id,
    required this.name,
    required this.tool,
    required this.travelXmm,
    required this.travelYmm,
    required this.travelZmm,
    this.safeZmm = 5,
    this.backlashXmm = 0,
    this.backlashYmm = 0,
    this.defaultFeedMmMin = 800,
    this.maxSpindleRpm = 1000,
  });

  final String id;
  final String name;
  final ToolType tool;
  final double travelXmm;
  final double travelYmm;
  final double travelZmm;

  /// Altura Z segura para movimientos rápidos y reanudación.
  final double safeZmm;

  /// Holgura mecánica medida (mm). Se compensa con movimiento real, nunca G92.
  final double backlashXmm;
  final double backlashYmm;

  final double defaultFeedMmMin;
  final double maxSpindleRpm;

  /// Volumen de trabajo como `[X, Y, Z]`.
  List<double> get travel => <double>[travelXmm, travelYmm, travelZmm];

  bool get hasBacklashCompensation => backlashXmm > 0 || backlashYmm > 0;

  /// El láser requiere `$32=1` y `M4`; el resto de herramientas usan `M3`.
  bool get usesLaserMode => tool == ToolType.laser;

  /// Comprueba que un punto de trabajo cae dentro del volumen del perfil.
  bool containsPoint(List<double> point) {
    if (point.length < 3) {
      return false;
    }
    return point[0] >= 0 &&
        point[1] >= 0 &&
        point[2] >= 0 &&
        point[0] <= travelXmm &&
        point[1] <= travelYmm &&
        point[2] <= travelZmm;
  }

  /// Errores de validación; lista vacía si el perfil es utilizable.
  List<String> validate() {
    final List<String> errors = <String>[];
    if (id.trim().isEmpty) {
      errors.add('El identificador del perfil no puede estar vacío.');
    }
    if (name.trim().isEmpty) {
      errors.add('El nombre del perfil no puede estar vacío.');
    }
    if (travelXmm <= 0 || travelYmm <= 0 || travelZmm <= 0) {
      errors.add('Las dimensiones de trabajo deben ser mayores que cero.');
    }
    if (safeZmm <= 0 || safeZmm > travelZmm) {
      errors.add('La altura segura debe estar entre 0 y el recorrido de Z.');
    }
    if (backlashXmm < 0 || backlashYmm < 0) {
      errors.add('La holgura no puede ser negativa.');
    }
    if (defaultFeedMmMin <= 0) {
      errors.add('El avance por defecto debe ser mayor que cero.');
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;

  MachineProfile copyWith({
    String? name,
    ToolType? tool,
    double? travelXmm,
    double? travelYmm,
    double? travelZmm,
    double? safeZmm,
    double? backlashXmm,
    double? backlashYmm,
    double? defaultFeedMmMin,
    double? maxSpindleRpm,
  }) {
    return MachineProfile(
      id: id,
      name: name ?? this.name,
      tool: tool ?? this.tool,
      travelXmm: travelXmm ?? this.travelXmm,
      travelYmm: travelYmm ?? this.travelYmm,
      travelZmm: travelZmm ?? this.travelZmm,
      safeZmm: safeZmm ?? this.safeZmm,
      backlashXmm: backlashXmm ?? this.backlashXmm,
      backlashYmm: backlashYmm ?? this.backlashYmm,
      defaultFeedMmMin: defaultFeedMmMin ?? this.defaultFeedMmMin,
      maxSpindleRpm: maxSpindleRpm ?? this.maxSpindleRpm,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'tool': tool.name,
    'travelXmm': travelXmm,
    'travelYmm': travelYmm,
    'travelZmm': travelZmm,
    'safeZmm': safeZmm,
    'backlashXmm': backlashXmm,
    'backlashYmm': backlashYmm,
    'defaultFeedMmMin': defaultFeedMmMin,
    'maxSpindleRpm': maxSpindleRpm,
  };

  /// Construye un perfil desde JSON.
  ///
  /// Lanza [FormatException] si falta un campo obligatorio, en lugar de
  /// inventar valores: un perfil con dimensiones supuestas puede chocar la
  /// máquina contra sus finales de carrera.
  factory MachineProfile.fromJson(Map<String, Object?> json) {
    double requireDouble(String key) {
      final Object? value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      throw FormatException('Campo numérico ausente en el perfil: $key');
    }

    final Object? id = json['id'];
    final Object? name = json['name'];
    if (id is! String || name is! String) {
      throw const FormatException(
        'El perfil requiere id y name de tipo texto.',
      );
    }

    return MachineProfile(
      id: id,
      name: name,
      tool: ToolType.parse(json['tool'] as String?),
      travelXmm: requireDouble('travelXmm'),
      travelYmm: requireDouble('travelYmm'),
      travelZmm: requireDouble('travelZmm'),
      safeZmm: json['safeZmm'] is num
          ? (json['safeZmm']! as num).toDouble()
          : 5,
      backlashXmm: json['backlashXmm'] is num
          ? (json['backlashXmm']! as num).toDouble()
          : 0,
      backlashYmm: json['backlashYmm'] is num
          ? (json['backlashYmm']! as num).toDouble()
          : 0,
      defaultFeedMmMin: json['defaultFeedMmMin'] is num
          ? (json['defaultFeedMmMin']! as num).toDouble()
          : 800,
      maxSpindleRpm: json['maxSpindleRpm'] is num
          ? (json['maxSpindleRpm']! as num).toDouble()
          : 1000,
    );
  }

  @override
  String toString() => 'MachineProfile($name, $tool, ${travel.join('x')} mm)';
}
