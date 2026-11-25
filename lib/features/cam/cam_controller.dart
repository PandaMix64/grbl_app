import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/services/engraving_generator.dart';
import '../viewer/viewer_controller.dart';

/// Estado de la pantalla CAM.
@immutable
class CamUiState {
  const CamUiState({
    this.imageBytes,
    this.fileName,
    this.result,
    this.isBusy = false,
    this.error,
    this.message,
  });

  final Uint8List? imageBytes;
  final String? fileName;
  final EngravingResult? result;
  final bool isBusy;
  final String? error;
  final String? message;

  bool get hasImage => imageBytes != null;

  CamUiState copyWith({
    Uint8List? imageBytes,
    String? fileName,
    EngravingResult? result,
    bool? isBusy,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
    bool clearImage = false,
    bool clearResult = false,
  }) {
    return CamUiState(
      imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
      fileName: clearImage ? null : (fileName ?? this.fileName),
      result: clearResult ? null : (result ?? this.result),
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// CAM: convierte una imagen en un trabajo de grabado láser.
///
/// La generación corre en un isolate ([EngravingGenerator.generateAsync]) y el
/// resultado se previsualiza en el visor antes de cualquier envío: la app nunca
/// ejecuta un trabajo que no se haya visto.
class CamController extends Notifier<CamUiState> {
  static const EngravingGenerator _generator = EngravingGenerator();

  @override
  CamUiState build() => const CamUiState();

  void loadImage(Uint8List bytes, String fileName) {
    state = CamUiState(
      imageBytes: bytes,
      fileName: fileName,
      message: 'Imagen cargada: $fileName',
    );
  }

  /// Genera el G-code validando antes perfil, modo y volumen de trabajo.
  Future<void> generate(EngravingSettings settings) async {
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
    if (!profile.usesLaserMode) {
      state = state.copyWith(
        error:
            'El grabado por potencia usa M4 y requiere un perfil con '
            'herramienta de tipo láser.',
      );
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final EngravingResult result = await _generator.generateAsync(
        EngravingJob(bytes: bytes, settings: settings),
      );
      if (result.widthMm > profile.travelXmm ||
          result.heightMm > profile.travelYmm) {
        state = state.copyWith(
          isBusy: false,
          clearResult: true,
          error:
              'El grabado (${result.widthMm.toStringAsFixed(1)} × '
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
            'G-code generado: ${result.columns}×${result.rows} celdas, '
            '${result.lineCount} líneas, '
            '${(result.litRatio * 100).toStringAsFixed(0)} % grabado.',
      );
    } on EngravingException catch (error) {
      state = state.copyWith(isBusy: false, error: error.message);
    } on Object catch (error) {
      state = state.copyWith(
        isBusy: false,
        error: 'No se pudo generar el G-code: $error',
      );
    }
  }

  /// Carga el resultado en el visor para revisarlo (y ejecutarlo desde allí).
  void sendToViewer() {
    final EngravingResult? result = state.result;
    if (result == null) {
      state = state.copyWith(error: 'Genera el G-code antes de enviarlo.');
      return;
    }
    final String base = (state.fileName ?? 'imagen').replaceAll(
      RegExp(r'\.[^.]+$'),
      '',
    );
    ref
        .read(viewerControllerProvider.notifier)
        .loadText(result.gcode, fileName: '${base}_grabado.gcode');
    state = state.copyWith(
      message:
          'Cargado en el Visor. Revisa la trayectoria y los parámetros antes '
          'de ejecutar.',
      clearError: true,
    );
  }

  void clear() => state = const CamUiState();
}

/// Estado CAM observable por la UI.
final NotifierProvider<CamController, CamUiState> camControllerProvider =
    NotifierProvider<CamController, CamUiState>(CamController.new);
