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

/// Barra de ejecución del programa del visor.
///
/// Ejecutar y detener exigen confirmación explícita: mueven la máquina y
/// activan la herramienta.
class ExecutionBar extends ConsumerWidget {
  const ExecutionBar({super.key});

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.play_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ejecución',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(status: execution.status),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: execution.progress),
            const SizedBox(height: 8),
            Text(
              execution.totalLines == 0
                  ? 'Sin programa en ejecución.'
                  : 'Línea ${(execution.executedLine ?? -1) + 1} de '
                        '${execution.totalLines} · ${execution.sentLines} '
                        'bloques · ${execution.compensations} compensaciones',
              style: theme.textTheme.bodySmall,
            ),
            if (execution.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  execution.message!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            if (execution.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  execution.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: canStart
                      ? () => _start(context, ref, viewer)
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Ejecutar'),
                ),
                if (execution.status == ExecutionStatus.running)
                  OutlinedButton.icon(
                    onPressed: controller.pause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pausa'),
                  ),
                if (execution.status == ExecutionStatus.paused)
                  FilledButton.tonalIcon(
                    onPressed: controller.resume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Reanudar'),
                  ),
                if (execution.isActive)
                  OutlinedButton.icon(
                    onPressed: () => _stop(context, controller),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener'),
                  ),
                if (!execution.isActive && resumable != null)
                  OutlinedButton.icon(
                    onPressed: connected && idle
                        ? () => _restart(context, ref, resumable)
                        : null,
                    icon: const Icon(Icons.history),
                    label: const Text('Reanudar trabajo guardado'),
                  ),
                if (!execution.isActive &&
                    (resumable?.resume?.workPosition.length ?? 0) >= 2)
                  TextButton.icon(
                    onPressed: connected && idle
                        ? () => _goToSavedPoint(
                            context,
                            ref,
                            resumable!.resume!.workPosition,
                          )
                        : null,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Llevar al punto guardado'),
                  ),
              ],
            ),
            if (!execution.isActive && resumable != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Trabajo guardado: ${resumable.name} · '
                  'línea ${(resumable.resume?.lineIndex ?? 0) + 1} de '
                  '${resumable.blockCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            if (!connected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Conecta la máquina para ejecutar el programa.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              )
            else if (!idle && !execution.isActive)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'La máquina está en ${connection.machineState.label}: '
                  'espera a Idle.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ExecutionStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = switch (status) {
      ExecutionStatus.running => theme.colorScheme.primary,
      ExecutionStatus.paused => theme.colorScheme.tertiary,
      ExecutionStatus.completed => theme.colorScheme.secondary,
      ExecutionStatus.interrupted => theme.colorScheme.error,
      ExecutionStatus.error => theme.colorScheme.error,
      _ => theme.colorScheme.outline,
    };
    final String label = switch (status) {
      ExecutionStatus.idle => 'Inactivo',
      ExecutionStatus.running => 'Ejecutando',
      ExecutionStatus.paused => 'Pausado',
      ExecutionStatus.stopped => 'Detenido',
      ExecutionStatus.completed => 'Completado',
      ExecutionStatus.interrupted => 'Interrumpido',
      ExecutionStatus.error => 'Error',
    };
    return Chip(
      label: Text(label),
      labelStyle: theme.textTheme.labelSmall?.copyWith(color: color),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      visualDensity: VisualDensity.compact,
    );
  }
}
