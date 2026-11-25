import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/entities/machine_profile.dart';
import '../../domain/entities/project_file.dart';
import '../../domain/entities/work_offsets.dart';

part 'app_database.g.dart';

/// Perfil de máquina persistido.
@DataClassName('MachineProfileRow')
class MachineProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get tool => text()();
  RealColumn get travelXmm => real()();
  RealColumn get travelYmm => real()();
  RealColumn get travelZmm => real()();
  RealColumn get safeZmm => real().withDefault(const Constant(5))();
  RealColumn get backlashXmm => real().withDefault(const Constant(0))();
  RealColumn get backlashYmm => real().withDefault(const Constant(0))();
  RealColumn get defaultFeedMmMin => real().withDefault(const Constant(800))();
  RealColumn get maxSpindleRpm => real().withDefault(const Constant(1000))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Proyecto persistido: G-code, perfil asociado y punto de reanudación.
@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get profileId => text()();
  TextColumn get gcode => text()();

  /// Versión del esquema del archivo `.cncproj`, para migrar al exportar.
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();
  TextColumn get status => text()();

  IntColumn get resumeLineIndex => integer().nullable()();
  TextColumn get resumeParserState => text().nullable()();

  /// Posición de trabajo serializada como lista JSON (X, Y, Z).
  TextColumn get resumeWorkPosition => text().nullable()();
  BoolColumn get resumeSpindleOn => boolean().nullable()();
  RealColumn get resumeFeedMmMin => real().nullable()();
  RealColumn get resumeSpindleSpeed => real().nullable()();
  DateTimeColumn get resumeSavedAt => dateTime().nullable()();

  /// Offsets `$#` serializados como JSON (G54–G59, G92, TLO...).
  TextColumn get resumeOffsets => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Archivos abiertos recientemente (G-code o `.cncproj`).
@DataClassName('RecentFileRow')
class RecentFiles extends Table {
  TextColumn get path => text()();
  DateTimeColumn get openedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{path};
}

/// Base de datos local (SQLite mediante drift).
@DriftDatabase(tables: <Type>[MachineProfiles, Projects, RecentFiles])
class AppDatabase extends _$AppDatabase {
  /// Base real, en el directorio de documentos de la aplicación.
  AppDatabase() : super(driftDatabase(name: 'grbl_app'));

  /// Base para pruebas (en memoria).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // v2: offsets de coordenadas en el punto de reanudación (SEG-05).
        await m.addColumn(projects, projects.resumeOffsets);
      }
    },
  );

  // ---------------------------------------------------------------- perfiles

  Future<void> upsertProfile(MachineProfile profile) {
    return into(machineProfiles).insertOnConflictUpdate(
      MachineProfilesCompanion.insert(
        id: profile.id,
        name: profile.name,
        tool: profile.tool.name,
        travelXmm: profile.travelXmm,
        travelYmm: profile.travelYmm,
        travelZmm: profile.travelZmm,
        safeZmm: Value(profile.safeZmm),
        backlashXmm: Value(profile.backlashXmm),
        backlashYmm: Value(profile.backlashYmm),
        defaultFeedMmMin: Value(profile.defaultFeedMmMin),
        maxSpindleRpm: Value(profile.maxSpindleRpm),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<MachineProfile>> allProfiles() async {
    final List<MachineProfileRow> rows =
        await (select(machineProfiles)
              ..orderBy(<OrderClauseGenerator<$MachineProfilesTable>>[
                ($MachineProfilesTable t) => OrderingTerm(expression: t.name),
              ]))
            .get();
    return rows.map((MachineProfileRow row) => row.toDomain()).toList();
  }

  Stream<List<MachineProfile>> watchProfiles() {
    return (select(machineProfiles)
          ..orderBy(<OrderClauseGenerator<$MachineProfilesTable>>[
            ($MachineProfilesTable t) => OrderingTerm(expression: t.name),
          ]))
        .watch()
        .map(
          (List<MachineProfileRow> rows) =>
              rows.map((MachineProfileRow row) => row.toDomain()).toList(),
        );
  }

  Future<MachineProfile?> profileById(String id) async {
    final MachineProfileRow? row = await (select(
      machineProfiles,
    )..where(($MachineProfilesTable t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  /// Perfil actualizado más recientemente; es el que se usa por defecto.
  Future<MachineProfile?> mostRecentProfile() async {
    final MachineProfileRow? row =
        await (select(machineProfiles)
              ..orderBy(<OrderClauseGenerator<$MachineProfilesTable>>[
                ($MachineProfilesTable t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.toDomain();
  }

  Future<int> deleteProfile(String id) => (delete(
    machineProfiles,
  )..where(($MachineProfilesTable t) => t.id.equals(id))).go();

  // --------------------------------------------------------------- proyectos

  Future<void> upsertProject(ProjectFile project) {
    final ResumeState? resume = project.resume;
    return into(projects).insertOnConflictUpdate(
      ProjectsCompanion.insert(
        id: project.id,
        name: project.name,
        profileId: project.profileId,
        gcode: project.gcode,
        status: project.status.name,
        updatedAt: project.updatedAt,
        schemaVersion: Value(project.schemaVersion),
        resumeLineIndex: Value(resume?.lineIndex),
        resumeParserState: Value(resume?.parserState),
        resumeWorkPosition: Value(
          resume == null ? null : jsonEncode(resume.workPosition),
        ),
        resumeSpindleOn: Value(resume?.spindleOn),
        resumeFeedMmMin: Value(resume?.feedMmMin),
        resumeSpindleSpeed: Value(resume?.spindleSpeed),
        resumeSavedAt: Value(resume?.savedAt),
        resumeOffsets: Value(
          resume?.offsets == null
              ? null
              : jsonEncode(resume!.offsets!.toJson()),
        ),
      ),
    );
  }

  Future<List<ProjectFile>> recentProjects({int limit = 20}) async {
    final List<ProjectRow> rows =
        await (select(projects)
              ..orderBy(<OrderClauseGenerator<$ProjectsTable>>[
                ($ProjectsTable t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(limit))
            .get();
    return rows.map((ProjectRow row) => row.toDomain()).toList();
  }

  Stream<List<ProjectFile>> watchRecentProjects({int limit = 20}) {
    return (select(projects)
          ..orderBy(<OrderClauseGenerator<$ProjectsTable>>[
            ($ProjectsTable t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch()
        .map(
          (List<ProjectRow> rows) =>
              rows.map((ProjectRow row) => row.toDomain()).toList(),
        );
  }

  Future<ProjectFile?> projectById(String id) async {
    final ProjectRow? row = await (select(
      projects,
    )..where(($ProjectsTable t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  /// Marca un proyecto como interrumpido sin tocar su punto de reanudación.
  ///
  /// Se usa al perder el enlace: el progreso guardado sigue siendo válido, pero
  /// el estado del proyecto debe reflejar que el trabajo no terminó.
  Future<void> markProjectInterrupted(String projectId) {
    return (update(
      projects,
    )..where(($ProjectsTable t) => t.id.equals(projectId))).write(
      ProjectsCompanion(
        status: Value(ProjectStatus.interrupted.name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Guarda el punto de reanudación de un proyecto existente.
  Future<void> saveResume({
    required String projectId,
    required ResumeState resume,
    ProjectStatus status = ProjectStatus.paused,
  }) async {
    await (update(
      projects,
    )..where(($ProjectsTable t) => t.id.equals(projectId))).write(
      ProjectsCompanion(
        status: Value(status.name),
        resumeLineIndex: Value(resume.lineIndex),
        resumeParserState: Value(resume.parserState),
        resumeWorkPosition: Value(jsonEncode(resume.workPosition)),
        resumeSpindleOn: Value(resume.spindleOn),
        resumeFeedMmMin: Value(resume.feedMmMin),
        resumeSpindleSpeed: Value(resume.spindleSpeed),
        resumeSavedAt: Value(resume.savedAt),
        resumeOffsets: Value(
          resume.offsets == null ? null : jsonEncode(resume.offsets!.toJson()),
        ),
        updatedAt: Value(resume.savedAt),
      ),
    );
  }

  // ---------------------------------------------------------------- recientes

  Future<void> touchRecentFile(String path, {DateTime? at}) async {
    await into(recentFiles).insertOnConflictUpdate(
      RecentFilesCompanion.insert(path: path, openedAt: at ?? DateTime.now()),
    );
  }

  /// Archivos abiertos recientemente, del más nuevo al más antiguo.
  ///
  /// Se llama `recentlyOpened` y no `recentFiles` porque drift genera ese
  /// nombre como getter de la tabla.
  Future<List<RecentFileRow>> recentlyOpened({int limit = 10}) {
    return (select(recentFiles)
          ..orderBy(<OrderClauseGenerator<$RecentFilesTable>>[
            ($RecentFilesTable t) =>
                OrderingTerm(expression: t.openedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }
}

/// Conversión de fila a entidad de dominio.
extension MachineProfileRowMapper on MachineProfileRow {
  MachineProfile toDomain() => MachineProfile(
    id: id,
    name: name,
    tool: ToolType.parse(tool),
    travelXmm: travelXmm,
    travelYmm: travelYmm,
    travelZmm: travelZmm,
    safeZmm: safeZmm,
    backlashXmm: backlashXmm,
    backlashYmm: backlashYmm,
    defaultFeedMmMin: defaultFeedMmMin,
    maxSpindleRpm: maxSpindleRpm,
  );
}

/// Conversión de fila a [ProjectFile], reconstruyendo el punto de reanudación.
extension ProjectRowMapper on ProjectRow {
  ProjectFile toDomain() => ProjectFile(
    schemaVersion: schemaVersion,
    id: id,
    name: name,
    profileId: profileId,
    gcode: gcode,
    status: ProjectStatus.parse(status),
    resume: _resume(),
    updatedAt: updatedAt,
  );

  ResumeState? _resume() {
    final int? index = resumeLineIndex;
    if (index == null) {
      return null;
    }
    return ResumeState(
      lineIndex: index,
      parserState: resumeParserState ?? '',
      workPosition: _decodePosition(resumeWorkPosition),
      spindleOn: resumeSpindleOn ?? false,
      feedMmMin: resumeFeedMmMin,
      spindleSpeed: resumeSpindleSpeed,
      savedAt: resumeSavedAt ?? updatedAt,
      offsets: _decodeOffsets(resumeOffsets),
    );
  }

  static WorkOffsets? _decodeOffsets(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return WorkOffsets.fromJson(decoded);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  static List<double> _decodePosition(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <double>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const <double>[];
    }
    if (decoded is! List) {
      return const <double>[];
    }
    return <double>[
      for (final Object? value in decoded)
        if (value is num) value.toDouble(),
    ];
  }
}
