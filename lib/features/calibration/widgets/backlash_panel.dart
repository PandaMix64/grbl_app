import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/axis.dart';
import '../../../domain/services/backlash_estimate.dart';
import '../calibration_controller.dart';

/// Prueba guiada de holgura: avance, retroceso, medida y guardado en el perfil.
///
/// La compensación en sí la aplica el post-procesador con movimiento real
/// (`BacklashCompensator`); aquí solo se mide y se guarda.
class BacklashPanel extends ConsumerStatefulWidget {
  const BacklashPanel({super.key});

  @override
  ConsumerState<BacklashPanel> createState() => _BacklashPanelState();
}

class _BacklashPanelState extends ConsumerState<BacklashPanel> {
  static const List<MachineAxis> _axes = <MachineAxis>[
    MachineAxis.x,
    MachineAxis.y,
  ];

  final TextEditingController _commanded = TextEditingController(text: '5');
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
    return (value == null || value < 0) ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final CalibrationUiState state = ref.watch(calibrationControllerProvider);
    final CalibrationController controller = ref.read(
      calibrationControllerProvider.notifier,
    );
    final ThemeData theme = Theme.of(context);

    final double? commanded = _parse(_commanded);
    final double? measured = _parse(_measured);
    final BacklashEstimate? estimate =
        (commanded != null && commanded > 0 && measured != null)
        ? BacklashEstimate(commandedMm: commanded, measuredMm: measured)
        : null;
    final double? current = state.selectedProfile == null
        ? null
        : (_axis == MachineAxis.x
              ? state.selectedProfile!.backlashXmm
              : state.selectedProfile!.backlashYmm);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.compare_arrows, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Holgura mecánica (backlash)',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '1) Haz homing y apoya la herramienta. 2) Avanza con el jog la '
              'distancia indicada y marca el punto. 3) Retrocede lo mismo y '
              'mide cuánto se movió de verdad. 4) Guarda el resultado: se '
              'compensa con movimiento real, nunca con G92.',
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
                        for (final MachineAxis axis in _axes)
                          DropdownMenuItem<MachineAxis>(
                            value: axis,
                            child: Text(axis.letter),
                          ),
                      ],
                    ),
                  ],
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _commanded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Ida y vuelta (mm)',
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
                  ? 'Sin perfil seleccionado: elige uno en la lista inferior.'
                  : 'Holgura guardada en el perfil para ${_axis.letter}: '
                        '${current.toStringAsFixed(3)} mm',
              style: theme.textTheme.bodySmall,
            ),
            if (estimate != null && estimate.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Holgura estimada: ${estimate.toProfileValue()} mm',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            if (estimate != null && !estimate.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  estimate.validate().first,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  state.selectedProfile != null &&
                      estimate != null &&
                      estimate.isValid
                  ? () => controller.calibrateBacklash(
                      axis: _axis,
                      commandedMm: commanded!,
                      measuredMm: measured!,
                    )
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar holgura en el perfil'),
            ),
          ],
        ),
      ),
    );
  }
}
