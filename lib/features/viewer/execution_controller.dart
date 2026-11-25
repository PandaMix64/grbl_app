import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/serial/grbl_worker_client.dart';
import '../../domain/entities/gcode_program.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/entities/machine_state.dart';
import '../../domain/entities/parser_state.dart';
import '../../domain/entities/project_file.dart';
import '../../domain/entities/work_offsets.dart';
import '../../domain/services/backlash_compensator.dart';
import '../connection/connection_controller.dart';

/// Estado del envío del programa al controlador.
enum ExecutionStatus { idle, running, paused, stopped, completed, error }

/// Estado observable de la ejecución.
@immutable
class ExecutionUiState {
  const ExecutionUiState({
    this.status = ExecutionStatus.idle,
    this.executedLine,
    this.totalLines = 0,
    this.sentLines = 0,
    this.compensations = 0,
    this.projectId,
    this.resume,
    this.message,
    this.error,
  });

  final ExecutionStatus status;

  /// Última línea de origen confirmada por GRBL.
  final int? executedLine;

  final int totalLines;
  final int sentLines;

  /// Compensaciones de holgura inyectadas antes de enviar.
  final int compensations;

  final String? projectId;

  /// Punto de reanudación guardado en la última pausa o detención.
  final ResumeState? resume;

  final String? message;
  final String? error;

  bool get isActive =>
      status == ExecutionStatus.running || status == ExecutionStatus.paused;

  /// Avance aproximado (0..1) según líneas confirmadas.
  double get progress {
    if (totalLines <= 0 || executedLine == null) {
      return 0;
    }
    return ((executedLine! + 1) / totalLines).clamp(0.0, 1.0);
  }

  ExecutionUiState copyWith({
    ExecutionStatus? status,
    int? executedLine,
    int? totalLines,
    int? sentLines,
    int? compensations,
    String? projectId,
    ResumeState? resume,
    String? message,
    String? error,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return ExecutionUiState(
      status: status ?? this.status,
      executedLine: executedLine ?? this.executedLine,
      totalLines: totalLines ?? this.totalLines,
      sentLines: sentLines ?? this.sentLines,
      compensations: compensations ?? this.compensations,
      projectId: projectId ?? this.projectId,
      resume: resume ?? this.resume,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Ejecuta el programa del visor: compensa holgura, envía y persiste el punto
/// de reanudación antes de pausar o detener.
class ExecutionController extends Notifier<ExecutionUiState> {
  StreamSubscription<WorkerPersistRequest>? _persistSub;
  StreamSubscription<int>? _progressSub;

  List<int> _sendToSource = const <int>[];
  String? _projectId;
  ProjectRepository? _repository;
  bool _jobUsesTool = false;

  static final RegExp _toolPattern = RegExp(
    r'\b(M3|M4|M7|M8)\b',
    caseSensitive: false,
  );

  @override
  ExecutionUiState build() {
    ref.onDispose(() {
      unawaited(_persistSub?.cancel());
      unawaited(_progressSub?.cancel());
    });
    return const ExecutionUiState();
  }

  GrblWorkerClient? get _client => ref.read(grblWorkerProvider).value;

  void _fail(String message) {
    state = ExecutionUiState(
      status: ExecutionStatus.error,
      error: message,
      totalLines: state.totalLines,
      executedLine: state.executedLine,
      projectId: _projectId,
      resume: state.resume,
    );
  }

  /// Prepara y envía el programa del visor.
  ///
  /// Aplica la compensación de holgura del perfil, guarda el proyecto en la base
  /// de datos (para poder reanudar) y arranca el streaming con progreso.
  Future<void> start({
    required GcodeProgram program,
    required String source,
    String? fileName,
  }) async {
    final GrblWorkerClient? client = _client;
    if (client == null) {
      _fail('El puerto serial no está disponible.');
      return;
    }
    if (program.isEmpty) {
      _fail('El programa no tiene movimientos que ejecutar.');
      return;
    }
    final ConnectionUiState connection = ref.read(connectionControllerProvider);
    if (!connection.isConnected) {
      _fail('Conecta la máquina antes de ejecutar.');
      return;
    }
    if (connection.machineState != MachineState.idle) {
      _fail(
        'La máquina está en ${connection.machineState.label}: espera a Idle '
        'para empezar.',
      );
      return;
    }

    final MachineProfile? profile = ref.read(activeProfileProvider).value;
    final List<String> sourceLines = source.split('\n');
    final BacklashCompensationResult compensated = BacklashCompensator(
      backlashXmm: profile?.backlashXmm ?? 0,
      backlashYmm: profile?.backlashYmm ?? 0,
      fallbackFeedMmMin: profile?.defaultFeedMmMin ?? 800,
    ).process(sourceLines);

    final List<String> sendLines = <String>[];
    final List<int> sendMap = <int>[];
    for (int i = 0; i < compensated.gcode.length; i++) {
      final String line = compensated.gcode[i].trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.length > 120) {
        _fail(
          'La línea ${compensated.lineIndexes[i] + 1} supera los 120 caracteres '
          'y no cabe en el búfer de GRBL.',
        );
        return;
      }
      sendLines.add(line);
      sendMap.add(compensated.lineIndexes[i]);
    }
    if (sendLines.isEmpty) {
      _fail('El programa no tiene bloques que enviar.');
      return;
    }

    final AppDatabase db = ref.read(databaseProvider);
    final DateTime now = DateTime.now();
    _projectId = 'job-${now.microsecondsSinceEpoch}';
    _repository = ProjectRepository(db);
    _sendToSource = sendMap;
    // La pausa apaga siempre la herramienta, así que el recuerdo de si el
    // trabajo la usa se toma del programa, no del último status report.
    _jobUsesTool = _toolPattern.hasMatch(source);

    try {
      await db.upsertProject(
        ProjectFile(
          id: _projectId!,
          name:
              fileName ??
              'Trabajo ${now.day}/${now.month} '
                  '${now.hour.toString().padLeft(2, '0')}:'
                  '${now.minute.toString().padLeft(2, '0')}',
          profileId: profile?.id ?? '',
          gcode: source,
          status: ProjectStatus.running,
          updatedAt: now,
        ),
      );
    } on Object catch (error) {
      _fail('No se pudo guardar el proyecto: $error');
      return;
    }

    _attach(client);
    try {
      await client.streamProgram(sendLines);
    } on Object catch (error) {
      _fail('No se pudo iniciar el envío: $error');
      return;
    }

    state = ExecutionUiState(
      status: ExecutionStatus.running,
      totalLines: sourceLines.length,
      sentLines: sendLines.length,
      compensations: compensated.total,
      projectId: _projectId,
      message: compensated.total > 0
          ? 'Ejecutando con ${compensated.total} compensaciones de holgura.'
          : 'Ejecutando.',
    );
  }

  void _attach(GrblWorkerClient client) {
    unawaited(_persistSub?.cancel());
    unawaited(_progressSub?.cancel());
    _persistSub = client.persistRequests.listen(_onPersistRequest);
    _progressSub = client.programProgress.listen(_onProgress);
  }

  /// Guarda el punto de reanudación y **solo entonces** confirma al worker.
  Future<void> _onPersistRequest(WorkerPersistRequest request) async {
    final ProjectRepository? repository = _repository;
    final String? projectId = _projectId;
    if (repository == null || projectId == null) {
      request.confirmPersisted();
      return;
    }
    try {
      final ResumeState resume = await repository.persistAndConfirm(
        projectId: projectId,
        request: request,
        lineIndex: state.executedLine ?? 0,
      );
      state = state.copyWith(
        status: ExecutionStatus.paused,
        resume: resume,
        message: 'Progreso guardado en la línea ${resume.lineIndex + 1}.',
      );
    } on Object catch (error) {
      // Sin confirmación el worker no resetea: la máquina queda en Hold.
      state = state.copyWith(
        error:
            'No se pudo guardar el progreso: $error. La máquina sigue en Hold '
            'con la herramienta apagada.',
      );
    }
  }

  void _onProgress(int confirmed) {
    if (_sendToSource.isEmpty) {
      return;
    }
    final int index = confirmed - 1;
    if (index < 0 || index >= _sendToSource.length) {
      return;
    }
    final bool completed =
        confirmed >= _sendToSource.length &&
        state.status == ExecutionStatus.running;
    state = state.copyWith(
      executedLine: _sendToSource[index],
      status: completed ? ExecutionStatus.completed : state.status,
      message: completed ? 'Programa completado.' : state.message,
    );
  }

  /// Pausa segura: detiene el movimiento, apaga la herramienta y **exige**
  /// guardar el progreso antes de dar la pausa por buena.
  Future<void> pause() async {
    final GrblWorkerClient? client = _client;
    if (client == null || state.status != ExecutionStatus.running) {
      return;
    }
    try {
      await client.pauseJob();
    } on Object catch (error) {
      _fail('No se pudo pausar: $error');
    }
  }

  /// Reanuda solo si el estado modal y los offsets coinciden con lo guardado
  /// (SEG-05). Si divergen, se niega y ofrece reiniciar.
  Future<void> resume() async {
    final GrblWorkerClient? client = _client;
    final ResumeState? resumeState = state.resume;
    if (client == null) {
      return;
    }
    if (resumeState == null) {
      _fail('No hay punto de reanudación guardado.');
      return;
    }
    try {
      if (resumeState.parserState.isNotEmpty) {
        final ParserState saved = ParserState.parse(resumeState.parserState);
        final ParserState current = await client.readParserState(direct: true);
        if (!saved.isCompatibleWith(current)) {
          _fail(
            'El estado modal cambió desde la pausa '
            '(${saved.words.join(' ')} → ${current.words.join(' ')}). '
            'Reinicia el trabajo con la secuencia segura.',
          );
          return;
        }
      }
      if (resumeState.offsets != null) {
        final WorkOffsets current = await client.readOffsets(direct: true);
        if (!resumeState.offsets!.matches(current)) {
          _fail(
            'Los offsets de coordenadas cambiaron desde la pausa: reanudar '
            'movería la pieza a otro sitio.',
          );
          return;
        }
      }

      int start = _sendToSource.indexWhere(
        (int line) => line >= resumeState.lineIndex,
      );
      if (start < 0) {
        start = _sendToSource.length;
      }
      if (start >= _sendToSource.length) {
        state = state.copyWith(
          status: ExecutionStatus.completed,
          message: 'No quedan líneas por ejecutar.',
        );
        return;
      }

      // GRBL conserva en su búfer los bloques ya enviados: se reanuda con `~`
      // (reactivando la herramienta) en lugar de reenviarlos.
      await client.resumeJob(restartTool: _jobUsesTool);
      state = state.copyWith(
        status: ExecutionStatus.running,
        clearError: true,
        message: 'Reanudado desde la línea ${resumeState.lineIndex + 1}.',
      );
    } on Object catch (error) {
      _fail('No se pudo reanudar: $error');
    }
  }

  /// Detiene el trabajo (pausa + persistencia + soft reset).
  Future<void> stop() async {
    final GrblWorkerClient? client = _client;
    if (client == null) {
      return;
    }
    try {
      await client.stopJob();
      state = state.copyWith(
        status: ExecutionStatus.stopped,
        message: 'Trabajo detenido; progreso guardado.',
      );
    } on Object catch (error) {
      _fail('No se pudo detener: $error');
    }
  }

  /// Limpia el estado de ejecución (al cerrar el programa).
  void reset() => state = const ExecutionUiState();
}

/// Estado de ejecución observable por la UI.
final NotifierProvider<ExecutionController, ExecutionUiState>
executionControllerProvider =
    NotifierProvider<ExecutionController, ExecutionUiState>(
      ExecutionController.new,
    );
