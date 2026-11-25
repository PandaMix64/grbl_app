import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/services/plot_generator.dart';
import '../viewer/viewer_controller.dart';

/// Estado de la pantalla de trazado (plóter).
@immutable
class PlotUiState {
  const PlotUiState({
    this.imageBytes,
    this.fileName,
    this.result,
    this.isBusy = false,
    this.error,
    this.message,
  });

  final Uint8List? imageBytes;
  final String? fileName;
  final PlotResult? result;
  final bool isBusy;
  final String? error;
  final String? message;

  bool get hasImage => imageBytes != null;
  bool get hasResult => result != null;

  PlotUiState copyWith({
    Uint8List? imageBytes,
    String? fileName,
    PlotResult? result,
    bool? isBusy,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
    bool clearImage = false,
    bool clearResult = false,
  }) {
    return PlotUiState(
      imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
      fileName: clearImage ? null : (fileName ?? this.fileName),
      result: clearResult ? null : (result ?? this.result),
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// Trazado con plóter: imagen → rutas vectoriales optimizadas o bordado raster.
///
/// La generación corre en un isolate y el resultado se revisa en el visor antes
/// de dibujar nada.
class PlotController extends Notifier<PlotUiState> {
  static const PlotGenerator _generator = PlotGenerator();

  @override
  PlotUiState build() => const PlotUiState();

  void loadImage(Uint8List bytes, String fileName) {
    state = PlotUiState(
      imageBytes: bytes,
      fileName: fileName,
      message: 'Imagen cargada: $fileName',
    );
  }

  Future<void> generate(PlotSettings settings) async {
    final Uint8List? bytes = state.imageBytes;
    if (bytes == null) {
      state = state.copyWith(error: 'Elige una imagen primero.');
      return;
    }
    final MachineProfile? profile = ref.read(activeProfileProvider).value;
    if (profile == null) {
      state = state.copyWith(
        error: 'Crea o selecciona un perfil de máquina antes de generar.',
      );
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final PlotResult result = await _generator.generateAsync(
        PlotJob(bytes: bytes, settings: settings),
      );
      if (result.widthMm > profile.travelXmm ||
          result.heightMm > profile.travelYmm) {
        state = state.copyWith(
          isBusy: false,
          clearResult: true,
          error:
              'El dibujo (${result.widthMm.toStringAsFixed(1)} × '
              '${result.heightMm.toStringAsFixed(1)} mm) excede el recorrido '
              'del perfil (${profile.travelXmm.toStringAsFixed(1)} × '
              '${profile.travelYmm.toStringAsFixed(1)} mm).',
        );
        return;
      }
      state = state.copyWith(
        isBusy: false,
        result: result,
        message:
            'Trazado generado: ${result.paths} trayectos, '
            '${result.points} puntos, ${result.lineCount} líneas '
            '(${result.mode.label}).',
      );
    } on PlotException catch (error) {
      state = state.copyWith(isBusy: false, error: error.message);
    } on Object catch (error) {
      state = state.copyWith(
        isBusy: false,
        error: 'No se pudo generar el trazado: $error',
      );
    }
  }

  /// Carga el resultado en el visor para revisarlo y ejecutarlo desde allí.
  void sendToViewer() {
    final PlotResult? result = state.result;
    if (result == null) {
      state = state.copyWith(error: 'Genera el trazado antes de enviarlo.');
      return;
    }
    final String base = (state.fileName ?? 'imagen').replaceAll(
      RegExp(r'\.[^.]+$'),
      '',
    );
    ref
        .read(viewerControllerProvider.notifier)
        .loadText(result.gcode, fileName: '${base}_trazado.gcode');
    state = state.copyWith(
      message:
          'Cargado en el Visor. Revisa el dibujo y los parámetros antes de '
          'ejecutar.',
      clearError: true,
    );
  }

  void clear() => state = const PlotUiState();
}

/// Estado de trazado observable por la UI.
final NotifierProvider<PlotController, PlotUiState> plotControllerProvider =
    NotifierProvider<PlotController, PlotUiState>(PlotController.new);
