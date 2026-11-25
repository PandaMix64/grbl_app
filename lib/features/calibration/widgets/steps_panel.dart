import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/axis.dart';
import '../../../domain/services/steps_per_mm_calibration.dart';
import '../../connection/connection_controller.dart';
import '../calibration_controller.dart';

/// Calibración de pasos/mm guiada: avance teórico frente a medida real.
class StepsCalibrationPanel extends ConsumerStatefulWidget {
  const StepsCalibrationPanel({super.key});

  @override
  ConsumerState<StepsCalibrationPanel> createState() =>
      _StepsCalibrationPanelState();
}

class _StepsCalibrationPanelState extends ConsumerState<StepsCalibrationPanel> {
  final TextEditingController _commanded = TextEditingController(text: '10');
  final TextEditingController _measured = TextEditingController();
  MachineAxis _axis = MachineAxis.x;

  @override
  void dispose() {
    _commanded.dispose();
    _measured.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    final String text = controller.text.trim().replaceAll(',', '.');
    final double? value = double.tryParse(text);
    return (value == null || value <= 0) ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final CalibrationUiState state = ref.watch(calibrationControllerProvider);
    final CalibrationController controller = ref.read(
      calibrationControllerProvider.notifier,
    );
    final bool connected = ref.watch(connectionControllerProvider).isConnected;
    final ThemeData theme = Theme.of(context);

    final double? current = state.settings?.stepsPerMm(_axis);
    final double? commanded = _parse(_commanded);
    final double? measured = _parse(_measured);
    final double? preview =
        (current != null && commanded != null && measured != null)
        ? StepsPerMmCalibration(
            currentStepsPerMm: current,
            commandedMm: commanded,
            measuredMm: measured,
          ).newStepsPerMm
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.straighten, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Pasos por milímetro', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ordena un avance, mide el desplazamiento real y aplica la '
              'corrección. Se escribe solo el parámetro del eje elegido.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: <Widget>[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Eje', style: theme.textTheme.labelSmall),
                    DropdownButton<MachineAxis>(
                      value: _axis,
                      onChanged: (MachineAxis? axis) {
                        if (axis != null) {
                          setState(() => _axis = axis);
                        }
                      },
                      items: <DropdownMenuItem<MachineAxis>>[
                        for (final MachineAxis axis in MachineAxis.values)
                          DropdownMenuItem<MachineAxis>(
                            value: axis,
                            child: Text(axis.letter),
                          ),
                      ],
                    ),
                  ],
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _commanded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Avance (mm)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _measured,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Medido (mm)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              current == null
                  ? 'Sin lectura de la EEPROM: pulsa "Leer" en parámetros.'
                  : 'Valor actual del eje ${_axis.letter}: '
                        '${current.toStringAsFixed(3)} pasos/mm',
              style: theme.textTheme.bodySmall,
            ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Nuevo valor: ${preview.toStringAsFixed(3)} pasos/mm',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: connected && preview != null
                  ? () => controller.calibrateSteps(
                      axis: _axis,
                      commandedMm: commanded!,
                      measuredMm: measured!,
                    )
                  : null,
              icon: const Icon(Icons.check),
              label: const Text('Aplicar corrección'),
            ),
          ],
        ),
      ),
    );
  }
}
