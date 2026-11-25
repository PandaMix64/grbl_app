import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gcode_program.dart';
import '../../domain/services/gcode_interpreter.dart';

/// Estado del visor de proyectos.
@immutable
class ViewerUiState {
  const ViewerUiState({
    this.program,
    this.source,
    this.fileName,
    this.isLoading = false,
    this.error,
  });

  final GcodeProgram? program;

  /// Texto original del programa (necesario para ejecutar y compensar holgura).
  final String? source;
  final String? fileName;
  final bool isLoading;
  final String? error;

  bool get hasProgram => program != null && !program!.isEmpty;

  ViewerUiState copyWith({
    GcodeProgram? program,
    String? source,
    String? fileName,
    bool? isLoading,
    String? error,
    bool clearProgram = false,
    bool clearError = false,
  }) {
    return ViewerUiState(
      program: clearProgram ? null : (program ?? this.program),
      source: clearProgram ? null : (source ?? this.source),
      fileName: clearProgram ? null : (fileName ?? this.fileName),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Carga y valida G-code para el visor.
class ViewerController extends Notifier<ViewerUiState> {
  static const GcodeInterpreter _interpreter = GcodeInterpreter();

  /// Programa de demostración: cuadrado con esquinas redondeadas y un círculo.
  static const String exampleProgram = '''
; Ejemplo de demostración — no ejecutar sin revisar
G21
G90
G0 X0 Y0 Z5
G1 Z-1 F200
G1 X60 F800
G3 X70 Y10 I0 J10
G1 Y50
G3 X60 Y60 I-10 J0
G1 X10
G3 X0 Y50 I0 J-10
G1 Y10
G3 X10 Y0 I10 J0
G1 X0 Y0
G0 X35 Y30
G2 X35 Y30 I-5 J0
G0 Z5
''';

  @override
  ViewerUiState build() => const ViewerUiState();

  /// Interpreta un programa completo.
  ///
  /// El parseo es síncrono: mover grandes archivos a un isolate es parte de la
  /// optimización de la Fase 5.
  void loadText(String source, {String? fileName}) {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final GcodeProgram program = _interpreter.parse(source);
      if (program.isEmpty) {
        state = ViewerUiState(
          isLoading: false,
          error: 'El programa no contiene movimientos ejecutables.',
        );
        return;
      }
      state = ViewerUiState(
        program: program,
        source: source,
        fileName: fileName,
      );
    } on Object catch (error) {
      state = ViewerUiState(isLoading: false, error: 'G-code ilegible: $error');
    }
  }

  void loadExample() => loadText(exampleProgram, fileName: 'ejemplo.gcode');

  void clear() => state = const ViewerUiState();

  void reportError(String message) =>
      state = state.copyWith(error: message, isLoading: false);
}

/// Estado del visor observable por la UI.
final NotifierProvider<ViewerController, ViewerUiState>
viewerControllerProvider = NotifierProvider<ViewerController, ViewerUiState>(
  ViewerController.new,
);
