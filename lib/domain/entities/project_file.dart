import 'dart:convert';

/// Estado de ejecución de un proyecto (se muestra en el historial).
enum ProjectStatus {
  ready,
  running,
  paused,
  interrupted,
  completed;

  static ProjectStatus parse(String? value) {
    return ProjectStatus.values.firstWhere(
      (ProjectStatus status) => status.name == value,
      orElse: () => ProjectStatus.ready,
    );
  }
}

/// Error de formato del contenedor `.cncproj`.
class ProjectException implements Exception {
  const ProjectException(this.message);

  final String message;

  @override
  String toString() => 'ProjectException: $message';
}

/// Punto de reanudación: todo lo necesario para retomar sin saltos geométricos.
///
/// Un índice de línea no basta (GRBL no tiene "resume"): hay que restaurar el
/// estado modal del parser, los offsets y el estado de la herramienta
/// (`docs/revision_tecnica_ruta_de_accion.md`, P1-2).
class ResumeState {
  const ResumeState({
    required this.lineIndex,
    required this.parserState,
    required this.workPosition,
    required this.spindleOn,
    required this.savedAt,
    this.feedMmMin,
    this.spindleSpeed,
  });

  /// Índice (base 0) de la siguiente línea a ejecutar.
  final int lineIndex;

  /// Bloque devuelto por `$G`, por ejemplo `G0 G54 G17 G21 G90 G94 M5 M9`.
  final String parserState;

  /// `WPos` (X, Y, Z) en el momento de la pausa.
  final List<double> workPosition;

  /// Si la herramienta estaba consignada con potencia/velocidad > 0.
  final bool spindleOn;

  final double? feedMmMin;
  final double? spindleSpeed;
  final DateTime savedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'lineIndex': lineIndex,
    'parserState': parserState,
    'workPosition': workPosition,
    'spindleOn': spindleOn,
    'feedMmMin': feedMmMin,
    'spindleSpeed': spindleSpeed,
    'savedAt': savedAt.toIso8601String(),
  };

  factory ResumeState.fromJson(Map<String, Object?> json) {
    final Object? lineIndex = json['lineIndex'];
    final Object? workPosition = json['workPosition'];
    if (lineIndex is! int || workPosition is! List) {
      throw const ProjectException(
        'Punto de reanudación inválido: falta lineIndex o workPosition.',
      );
    }
    return ResumeState(
      lineIndex: lineIndex,
      parserState: json['parserState'] as String? ?? '',
      workPosition: <double>[
        for (final Object? value in workPosition)
          if (value is num) value.toDouble(),
      ],
      spindleOn: json['spindleOn'] == true,
      feedMmMin: json['feedMmMin'] is num
          ? (json['feedMmMin']! as num).toDouble()
          : null,
      spindleSpeed: json['spindleSpeed'] is num
          ? (json['spindleSpeed']! as num).toDouble()
          : null,
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Contenedor portable de proyecto (`.cncproj`).
///
/// Lleva el G-code, el perfil asociado y el estado de ejecución para poder
/// reanudar en cualquier momento o en otra máquina.
class ProjectFile {
  const ProjectFile({
    required this.id,
    required this.name,
    required this.profileId,
    required this.gcode,
    required this.updatedAt,
    this.status = ProjectStatus.ready,
    this.resume,
    this.schemaVersion = currentSchemaVersion,
  });

  /// Versión de esquema que entiende esta compilación.
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String name;
  final String profileId;
  final String gcode;
  final ProjectStatus status;
  final ResumeState? resume;
  final DateTime updatedAt;

  /// Número de bloques ejecutables (líneas no vacías ni comentarios).
  int get blockCount => gcode.split('\n').where((String line) {
    final String trimmed = line.trim();
    return trimmed.isNotEmpty && !trimmed.startsWith(';');
  }).length;

  ProjectFile copyWith({
    String? name,
    String? profileId,
    String? gcode,
    ProjectStatus? status,
    ResumeState? resume,
    bool clearResume = false,
    DateTime? updatedAt,
  }) {
    return ProjectFile(
      id: id,
      name: name ?? this.name,
      profileId: profileId ?? this.profileId,
      gcode: gcode ?? this.gcode,
      status: status ?? this.status,
      resume: clearResume ? null : (resume ?? this.resume),
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'profileId': profileId,
    'gcode': gcode,
    'status': status.name,
    'resume': resume?.toJson(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ProjectFile.fromJson(Map<String, Object?> json) {
    final Object? schema = json['schemaVersion'];
    if (schema is! int) {
      throw const ProjectException(
        'El archivo no declara schemaVersion: no se puede abrir con seguridad.',
      );
    }
    if (schema > currentSchemaVersion) {
      throw ProjectException(
        'Proyecto creado con un esquema más reciente ($schema > '
        '$currentSchemaVersion). Actualiza la aplicación para abrirlo.',
      );
    }
    if (schema < 1) {
      throw ProjectException('schemaVersion inválido: $schema.');
    }

    final Object? id = json['id'];
    final Object? name = json['name'];
    final Object? gcode = json['gcode'];
    if (id is! String || name is! String || gcode is! String) {
      throw const ProjectException('Proyecto incompleto: id, nombre o G-code.');
    }

    final Object? resume = json['resume'];

    return ProjectFile(
      schemaVersion: schema,
      id: id,
      name: name,
      profileId: json['profileId'] as String? ?? '',
      gcode: gcode,
      status: ProjectStatus.parse(json['status'] as String?),
      resume: resume is Map<String, Object?>
          ? ResumeState.fromJson(resume)
          : null,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Serializa a texto JSON legible.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Parsea el contenido de un archivo `.cncproj`.
  factory ProjectFile.decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw ProjectException('JSON inválido: ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const ProjectException('El archivo no contiene un objeto JSON.');
    }
    return ProjectFile.fromJson(decoded);
  }

  @override
  String toString() =>
      'ProjectFile($name, ${status.name}, $blockCount bloques)';
}
