import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/services/contour_generator.dart';
import '../../domain/services/engraving_generator.dart';
import '../viewer/viewer_controller.dart';

/// Operación CAM seleccionada.
enum CamOperation {
  engrave,
  contour;

  String get label => switch (this) {
    CamOperation.engrave => 'Grabado',
    CamOperation.contour => 'Contorno',
  };
}

/// Estado de la pantalla CAM.
@immutable
class CamUiState {
  const CamUiState({
    this.imageBytes,
    this.fileName,
    this.operation = CamOperation.engrave,
    this.engraveResult,
    this.contourResult,
    this.isBusy = false,
    this.error,
    this.message,
  });

  final Uint8List? imageBytes;
  final String? fileName;
  final CamOperation operation;
  final EngravingResult? engraveResult;
  final ContourResult? contourResult;
  final bool isBusy;
  final String? error;
  final String? message;

  bool get hasImage => imageBytes != null;

  bool get hasResult => engraveResult != null || contourResult != null;

  /// Vista previa de la operación activa.
  Uint8List? get previewPng =>
      engraveResult?.previewPng ?? contourResult?.previewPng;

  /// G-code de la operación activa.
  String? get gcode => engraveResult?.gcode ?? contourResult?.gcode;

  CamUiState copyWith({
    Uint8List? imageBytes,
    String? fileName,
    CamOperation? operation,
    EngravingResult? engraveResult,
    ContourResult? contourResult,
    bool? isBusy,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
    bool clearImage = false,
    bool clearEngrave = false,
    bool clearContour = false,
  }) {
    return CamUiState(
      imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
      fileName: clearImage ? null : (fileName ?? this.fileName),
      operation: operation ?? this.operation,
      engraveResult: clearEngrave
          ? null
          : (engraveResult ?? this.engraveResult),
      contourResult: clearContour
          ? null
          : (contourResult ?? this.contourResult),
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// CAM: imagen → trabajo de grabado (raster) o de contorno (corte).
///
/// Las dos generaciones corren en isolates y el resultado se previsualiza en el
/// visor antes de cualquier envío: la app nunca ejecuta algo que no se haya
/// visto.
class CamController extends Notifier<CamUiState> {
  static const EngravingGenerator _engraver = EngravingGenerator();
  static const ContourGenerator _contour = ContourGenerator();

  @override
  CamUiState build() => const CamUiState();

  void setOperation(CamOperation operation) {
    if (operation == state.operation) {
      return;
    }
    // Los resultados de una operación no valen para la otra.
    state = state.copyWith(
      operation: operation,
      clearEngrave: true,
      clearContour: true,
      clearError: true,
      clearMessage: true,
    );
  }

  void loadImage(Uint8List bytes, String fileName) {
    state = CamUiState(
      imageBytes: bytes,
      fileName: fileName,
      operation: state.operation,
      message: 'Imagen cargada: $fileName',
    );
  }

  /// Genera el G-code de grabado validando perfil, modo y volumen.
  Future<void> generate(EngravingSettings settings) async {
    final MachineProfile? profile = await _profileForLaser();
    if (profile == null) {
      return;
    }
    final Uint8List? bytes = state.imageBytes;
    if (bytes == null) {
      state = state.copyWith(error: 'Elige una imagen primero.');
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final EngravingResult result = await _engraver.generateAsync(
        EngravingJob(bytes: bytes, settings: settings),
      );
      final String? outOfVolume = _outOfVolume(
        result.widthMm,
        result.heightMm,
        profile,
      );
      if (outOfVolume != null) {
        state = state.copyWith(
          isBusy: false,
          clearEngrave: true,
          error: outOfVolume,
        );
        return;
      }
      state = state.copyWith(
        isBusy: false,
        engraveResult: result,
        clearContour: true,
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

  /// Genera el contorno (corte de la silueta) con pasadas y pestañas.
  Future<void> generateContour(ContourSettings settings) async {
    final MachineProfile? profile = ref.read(activeProfileProvider).value;
    if (profile == null) {
      state = state.copyWith(
        error: 'Crea o selecciona un perfil de máquina antes de generar.',
      );
      return;
    }
    if (settings.tool.isLaser && !profile.usesLaserMode) {
      state = state.copyWith(
        error:
            'El contorno con láser requiere un perfil de tipo láser (M4). '
            'Cambia la herramienta del contorno a husillo o usa otro perfil.',
      );
      return;
    }
    final Uint8List? bytes = state.imageBytes;
    if (bytes == null) {
      state = state.copyWith(error: 'Elige una imagen primero.');
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final ContourResult result = await _contour.generateAsync(
        ContourJob(bytes: bytes, settings: settings),
      );
      final String? outOfVolume = _outOfVolume(
        result.widthMm,
        result.heightMm,
        profile,
      );
      if (outOfVolume != null) {
        state = state.copyWith(
          isBusy: false,
          clearContour: true,
          error: outOfVolume,
        );
        return;
      }
      state = state.copyWith(
        isBusy: false,
        contourResult: result,
        clearEngrave: true,
        message:
            'Contorno generado: ${result.loops} vueltas, '
            '${result.points} puntos, ${result.passes} pasadas, '
            '${result.lineCount} líneas.',
      );
    } on ContourException catch (error) {
      state = state.copyWith(isBusy: false, error: error.message);
    } on Object catch (error) {
      state = state.copyWith(
        isBusy: false,
        error: 'No se pudo generar el contorno: $error',
      );
    }
  }

  /// Carga el resultado activo en el visor para revisarlo (y ejecutarlo allí).
  void sendToViewer() {
    final String? gcode = state.gcode;
    if (gcode == null) {
      state = state.copyWith(error: 'Genera el G-code antes de enviarlo.');
      return;
    }
    final String base = (state.fileName ?? 'imagen').replaceAll(
      RegExp(r'\.[^.]+$'),
      '',
    );
    final String suffix = state.operation == CamOperation.contour
        ? '_contorno'
        : '_grabado';
    ref
        .read(viewerControllerProvider.notifier)
        .loadText(gcode, fileName: '$base$suffix.gcode');
    state = state.copyWith(
      message:
          'Cargado en el Visor. Revisa la trayectoria y los parámetros antes '
          'de ejecutar.',
      clearError: true,
    );
  }

  void clear() => state = CamUiState(operation: state.operation);

  /// Perfil activo, exigiendo que sea láser (lo necesita el grabado `M4`).
  Future<MachineProfile?> _profileForLaser() async {
    final MachineProfile? profile = ref.read(activeProfileProvider).value;
    if (profile == null) {
      state = state.copyWith(
        error: 'Crea o selecciona un perfil de máquina antes de generar.',
      );
      return null;
    }
    if (!profile.usesLaserMode) {
      state = state.copyWith(
        error:
            'El grabado por potencia usa M4 y requiere un perfil con '
            'herramienta de tipo láser.',
      );
      return null;
    }
    return profile;
  }

  static String? _outOfVolume(
    double widthMm,
    double heightMm,
    MachineProfile profile,
  ) {
    if (widthMm <= profile.travelXmm && heightMm <= profile.travelYmm) {
      return null;
    }
    return 'El trabajo (${widthMm.toStringAsFixed(1)} × '
        '${heightMm.toStringAsFixed(1)} mm) excede el recorrido del perfil '
        '(${profile.travelXmm.toStringAsFixed(1)} × '
        '${profile.travelYmm.toStringAsFixed(1)} mm).';
  }
}

/// Estado CAM observable por la UI.
final NotifierProvider<CamController, CamUiState> camControllerProvider =
    NotifierProvider<CamController, CamUiState>(CamController.new);
