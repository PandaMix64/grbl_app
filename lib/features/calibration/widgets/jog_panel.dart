import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/axis.dart';
import '../../connection/connection_controller.dart';
import '../calibration_controller.dart';

/// Control manual de ejes con `$J=` y cancelación con `0x85`.
class JogPanel extends ConsumerWidget {
  const JogPanel({super.key});

  static const List<double> steps = <double>[0.1, 1, 10, 100];
  static const List<double> feeds = <double>[100, 500, 1000, 2000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalibrationUiState state = ref.watch(calibrationControllerProvider);
    final CalibrationController controller = ref.read(
      calibrationControllerProvider.notifier,
    );
    final bool connected = ref.watch(connectionControllerProvider).isConnected;
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.open_with, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Control manual (jog)',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: connected ? controller.cancelJog : null,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancelar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: <Widget>[
                _Choice<double>(
                  label: 'Paso (mm)',
                  value: state.jogStepMm,
                  options: steps,
                  enabled: !state.isBusy,
                  format: (double value) =>
                      value.toStringAsFixed(value < 1 ? 1 : 0),
                  onChanged: controller.setJogStep,
                ),
                _Choice<double>(
                  label: 'Avance (mm/min)',
                  value: state.jogFeedMmMin,
                  options: feeds,
                  enabled: !state.isBusy,
                  format: (double value) => value.toStringAsFixed(0),
                  onChanged: controller.setJogFeed,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final MachineAxis axis in MachineAxis.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 24,
                      child: Text(
                        axis.letter,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: connected
                            ? () => controller.jog(axis: axis, direction: -1)
                            : null,
                        icon: const Icon(Icons.remove),
                        label: Text('-${_stepLabel(state.jogStepMm)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: connected
                            ? () => controller.jog(axis: axis, direction: 1)
                            : null,
                        icon: const Icon(Icons.add),
                        label: Text('+${_stepLabel(state.jogStepMm)}'),
                      ),
                    ),
                  ],
                ),
              ),
            if (!connected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Conecta la máquina para mover los ejes.',
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

  static String _stepLabel(double step) =>
      '${step.toStringAsFixed(step < 1 ? 1 : 0)} mm';
}

/// Selector compacto con etiqueta.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.format,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<T> options;
  final ValueChanged<T> onChanged;
  final String Function(T value) format;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelSmall),
        DropdownButton<T>(
          value: value,
          onChanged: enabled
              ? (T? selected) {
                  if (selected != null) {
                    onChanged(selected);
                  }
                }
              : null,
          items: <DropdownMenuItem<T>>[
            for (final T option in options)
              DropdownMenuItem<T>(value: option, child: Text(format(option))),
          ],
        ),
      ],
    );
  }
}
