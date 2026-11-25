import '../../domain/entities/parser_state.dart';
import '../../domain/entities/project_file.dart';
import '../database/app_database.dart';
import '../serial/grbl_worker_client.dart';

/// Une la persistencia en SQLite con el punto de reanudación que exige el
/// worker antes de resetear.
///
/// Esta clase es la que convierte la confirmación de SEG-03 en **durabilidad
/// real** (R-12): el `confirmPersisted()` solo se llama después de que la
/// escritura haya terminado. Si la base falla, la excepción se propaga, el
/// worker no recibe el ack y **no** envía el soft reset.
class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;

  /// Guarda el punto de reanudación y confirma al worker.
  ///
  /// El estado de la herramienta y el avance se toman del **estado modal**
  /// (`$G`) y no del status report: al pausar, `pauseSafely` ya apagó la
  /// herramienta, así que el reporte diría `S:0` y perderíamos qué había que
  /// reactivar al reanudar.
  Future<ResumeState> persistAndConfirm({
    required String projectId,
    required WorkerPersistRequest request,
    required int lineIndex,
  }) async {
    final ParserState? modal = request.parserState;
    final bool spindleOn = modal == null
        ? (request.status?.isSpindleOn ?? false)
        : modal.spindleMode != 'M5';

    final ResumeState resume = ResumeState(
      lineIndex: lineIndex,
      parserState: modal?.raw ?? '',
      workPosition: request.status?.resolvedWorkPosition ?? const <double>[],
      spindleOn: spindleOn,
      feedMmMin: modal?.feed ?? request.status?.feedMmMin,
      spindleSpeed: modal?.spindle ?? request.status?.spindleSpeed,
      savedAt: DateTime.now(),
    );

    await _db.saveResume(projectId: projectId, resume: resume);
    request.confirmPersisted();
    return resume;
  }
}
