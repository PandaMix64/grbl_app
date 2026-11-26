import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Qué capas de previsualización se dibujan sobre la trayectoria.
///
/// Ver una estela de simulación, el avance real de un trabajo y la trayectoria a
/// la vez satura el lienzo: cada capa se puede apagar sin perder su estado (la
/// reproducción sigue donde estaba aunque no se vea).
@immutable
class PreviewVisibility {
  const PreviewVisibility({
    this.showExecution = true,
    this.showSimulation = true,
  });

  /// Avance del trabajo real (`executedUpToLine`) y cabezal de la máquina.
  final bool showExecution;

  /// Estela y cabezal del simulador.
  final bool showSimulation;

  PreviewVisibility copyWith({bool? showExecution, bool? showSimulation}) {
    return PreviewVisibility(
      showExecution: showExecution ?? this.showExecution,
      showSimulation: showSimulation ?? this.showSimulation,
    );
  }
}

/// Alterna las capas de previsualización del visor.
class PreviewVisibilityController extends Notifier<PreviewVisibility> {
  @override
  PreviewVisibility build() => const PreviewVisibility();

  void toggleExecution() =>
      state = state.copyWith(showExecution: !state.showExecution);

  void toggleSimulation() =>
      state = state.copyWith(showSimulation: !state.showSimulation);
}

/// Previsualizaciones activas del visor.
final NotifierProvider<PreviewVisibilityController, PreviewVisibility>
previewVisibilityProvider =
    NotifierProvider<PreviewVisibilityController, PreviewVisibility>(
      PreviewVisibilityController.new,
    );
