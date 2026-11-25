import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../domain/entities/machine_state.dart';
import '../../../domain/entities/project_file.dart';
import '../../calibration/calibration_controller.dart';
import '../../connection/connection_controller.dart';
import '../execution_controller.dart';
import '../viewer_controller.dart';

/// Barra de ejecución compacta, superpuesta al lienzo del visor.
///
/// Ocupa una sola fila para no robar viewport al trazado; los detalles (línea,
/// compensaciones, avisos) van en el texto bajo la barra de progreso. Ejecutar y
/// detener siguen exigiendo confirmación explícita.
class ExecutionBar extends ConsumerWidget {
  const ExecutionBar({super.key, this.onFitView});

  /// Centra el trazado; lo aporta la página para reutilizar la clave del lienzo.
  final VoidCallback? onFitView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ViewerUiState viewer = ref.watch(viewerControllerProvider);
    final ExecutionUiState execution = ref.watch(executionControllerProvider);
    final ConnectionUiState connection = ref.watch(
      connectionControllerProvider,
    );
    final ExecutionController controller = ref.read(
      executionControllerProvider.notifier,
    );
    final ProjectFile? resumable = ref.watch(resumableProjectProvider).value;
    final ThemeData theme = Theme.of(context);

    final bool connected = connection.isConnected;
    final bool idle = connection.machineState == MachineState.idle;
    final bool canStart =
        viewer.source != null &&
        viewer.program != null &&
        connected &&
        idle &&
        !execution.isActive;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Ejecutar programa',
                  visualDensity: VisualDensity.compact,
                  onPressed: canStart
                      ? () => _start(context, ref, viewer)
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  color: theme.colorScheme.primary,
                ),
                if (execution.status == ExecutionStatus.running)
                  IconButton(
                    tooltip: 'Pausa',
                    visualDensity: VisualDensity.compact,
                    onPressed: controller.pause,
                    icon: const Icon(Icons.pause),
                  ),
                if (execution.status == ExecutionStatus.paused)
                  IconButton(
                    tooltip: 'Reanudar',
                    visualDensity: VisualDensity.compact,
                    onPressed: controller.resume,
                    icon: const Icon(Icons.play_circle_outline),
                    color: theme.colorScheme.primary,
                  ),
                if (execution.isActive)
                  IconButton(
                    tooltip: 'Detener',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _stop(context, controller),
                    icon: const Icon(Icons.stop),
                    color: theme.colorScheme.error,
                  ),
                if (!execution.isActive && resumable != null)
                  IconButton(
                    tooltip: 'Reanudar trabajo guardado',
                    visualDensity: VisualDensity.compact,
                    onPressed: connected && idle
                        ? () => _restart(context, ref, resumable)
                        : null,
                    icon: const Icon(Icons.history),
                  ),
                if (!execution.isActive &&
                    (resumable?.resume?.workPosition.length ?? 0) >= 2)
                  IconButton(
                    tooltip: 'Llevar al punto guardado',
                    visualDensity: VisualDensity.compact,
                    onPressed: connected && idle
                        ? () => _goToSavedPoint(
                            context,
                            ref,
                            resumable!.resume!.workPosition,
                          )
                        : null,
                    icon: const Icon(Icons.my_location),
                  ),
                const SizedBox(width: 8),
                Expanded(child: _progress(theme, execution)),
                if (onFitView != null)
                  IconButton(
                    tooltip: 'Centrar trazado',
                    visualDensity: VisualDensity.compact,
                    onPressed: onFitView,
                    icon: const Icon(Icons.fit_screen),
                  ),
              ],
            ),
            _hint(theme, execution, connection, resumable, connected, idle),
          ],
        ),
      ),
    );
  }

  /// Progreso fino con el estado y la línea actual.
  Widget _progress(ThemeData theme, ExecutionUiState execution) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: execution.progress,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: <Widget>[
            Icon(
              Icons.circle,
              size: 8,
              color: _statusColor(theme, execution.status),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _statusLine(execution),
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Una sola línea de aviso: error, falta de conexión o trabajo guardado.
  Widget _hint(
    ThemeData theme,
    ExecutionUiState execution,
    ConnectionUiState connection,
    ProjectFile? resumable,
    bool connected,
    bool idle,
  ) {
    final String? text;
    final Color color;
    if (execution.error != null) {
      text = execution.error;
      color = theme.colorScheme.error;
    } else if (!connected) {
      text = 'Conecta la máquina para ejecutar.';
      color = theme.colorScheme.tertiary;
    } else if (!idle && !execution.isActive) {
      text =
          'La máquina está en ${connection.machineState.label}: '
          'espera a Idle.';
      color = theme.colorScheme.tertiary;
    } else if (!execution.isActive && resumable != null) {
      text =
          'Trabajo guardado: ${resumable.name} · '
          'línea ${(resumable.resume?.lineIndex ?? 0) + 1}';
      color = theme.colorScheme.tertiary;
    } else if (execution.message != null) {
      text = execution.message;
      color = theme.colorScheme.primary;
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text!,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  static Color _statusColor(ThemeData theme, ExecutionStatus status) {
    return switch (status) {
      ExecutionStatus.running => theme.colorScheme.primary,
      ExecutionStatus.paused => theme.colorScheme.tertiary,
      ExecutionStatus.completed => theme.colorScheme.secondary,
      ExecutionStatus.interrupted ||
      ExecutionStatus.error => theme.colorScheme.error,
      _ => theme.colorScheme.outline,
    };
  }

  static String _statusLine(ExecutionUiState execution) {
    final int line = (execution.executedLine ?? 0) + 1;
    return switch (execution.status) {
      ExecutionStatus.idle =>
        execution.totalLines == 0 ? 'Sin trabajo' : 'Listo para ejecutar',
      ExecutionStatus.running =>
        'Ejecutando · línea $line/${execution.totalLines}'
            '${execution.compensations > 0 ? ' · ${execution.compensations} comp.' : ''}',
      ExecutionStatus.paused => 'Pausado · línea $line/${execution.totalLines}',
      ExecutionStatus.stopped => 'Detenido · línea $line',
      ExecutionStatus.completed => 'Completado',
      ExecutionStatus.interrupted => 'Interrumpido · línea $line',
      ExecutionStatus.error => 'Error',
    };
  }

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    ViewerUiState viewer,
  ) async {
    final bool ok = await confirmAction(
      context,
      title: 'Ejecutar programa',
      message:
          'La máquina se moverá y la herramienta se activará según el perfil. '
          'Comprueba el origen, la sujeción de la pieza y que la herramienta '
          'está libre de obstáculos.',
      confirmLabel: 'Ejecutar',
    );
    if (!ok) {
      return;
    }
    await ref
        .read(executionControllerProvider.notifier)
        .start(
          program: viewer.program!,
          source: viewer.source!,
          fileName: viewer.fileName,
        );
  }

  Future<void> _restart(
    BuildContext context,
    WidgetRef ref,
    ProjectFile project,
  ) async {
    final ResumeState resume = project.resume!;
    final String position = resume.workPosition.length >= 2
        ? resume.workPosition
              .take(2)
              .map((double value) => value.toStringAsFixed(2))
              .join(', ')
        : 'desconocida';
    final bool ok = await confirmAction(
      context,
      title: 'Reanudar trabajo guardado',
      message:
          '«${project.name}» se reanudará desde la línea '
          '${resume.lineIndex + 1} en el punto ($position).\n\n'
          'Antes de continuar comprueba que la máquina está en Idle y con '
          'homing hecho, que el cero de trabajo es el mismo del trabajo y que '
          'la herramienta está montada y libre de obstáculos.\n\n'
          'Se verifican \$G y \$# contra lo guardado: si no coinciden, se cancela.',
      confirmLabel: 'Reanudar',
    );
    if (!ok) {
      return;
    }
    await ref.read(executionControllerProvider.notifier).restartFromSaved();
  }

  Future<void> _goToSavedPoint(
    BuildContext context,
    WidgetRef ref,
    List<double> target,
  ) async {
    final String point = target
        .take(2)
        .map((double value) => value.toStringAsFixed(2))
        .join(', ');
    final bool ok = await confirmAction(
      context,
      title: 'Llevar al punto guardado',
      message:
          'La máquina se desplazará al punto ($point) del sistema de trabajo '
          'actual. Retira obstáculos del recorrido antes de continuar.',
      confirmLabel: 'Mover',
    );
    if (!ok) {
      return;
    }
    await ref
        .read(calibrationControllerProvider.notifier)
        .jogToWorkPosition(target, label: 'al punto guardado');
  }

  Future<void> _stop(
    BuildContext context,
    ExecutionController controller,
  ) async {
    final bool ok = await confirmAction(
      context,
      title: 'Detener el trabajo',
      message:
          'Se guardará el progreso antes de resetear el controlador. '
          'Consecuencias: se pierde la posición de máquina, el trabajo queda '
          'interrumpido y necesitarás re-homing o redefinir el origen para '
          'volver a ejecutar.',
      confirmLabel: 'Detener',
    );
    if (!ok) {
      return;
    }
    await controller.stop();
  }
}
