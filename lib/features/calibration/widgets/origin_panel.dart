import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../domain/entities/axis.dart';
import '../../connection/connection_controller.dart';
import '../calibration_controller.dart';

/// Homing (`$H`) y definición del cero de trabajo (`G10 L20 P1`, nunca `G92`).
class OriginPanel extends ConsumerStatefulWidget {
  const OriginPanel({super.key});

  @override
  ConsumerState<OriginPanel> createState() => _OriginPanelState();
}

class _OriginPanelState extends ConsumerState<OriginPanel> {
  bool _x = true;
  bool _y = true;
  bool _z = false;

  Future<void> _goToZero() async {
    final bool ok = await confirmAction(
      context,
      title: 'Ir al cero de trabajo',
      message:
          'La máquina se desplazará a X0 Y0 del sistema de trabajo actual a '
          '${ref.read(calibrationControllerProvider).jogFeedMmMin} mm/min. '
          'Retira obstáculos del recorrido antes de continuar.',
      confirmLabel: 'Ir al cero',
    );
    if (!ok || !mounted) {
      return;
    }
    await ref.read(calibrationControllerProvider.notifier).goToWorkZero();
  }

  Future<void> _home() async {
    final bool ok = await confirmAction(
      context,
      title: 'Ejecutar homing',
      message:
          'La máquina se moverá hasta los finales de carrera. Retira la pieza '
          'y las abrazaderas del recorrido antes de continuar.',
      confirmLabel: 'Hacer homing',
    );
    if (!ok || !mounted) {
      return;
    }
    await ref.read(calibrationControllerProvider.notifier).home();
  }

  Future<void> _setZero() async {
    final List<String> axes = <String>[if (_x) 'X', if (_y) 'Y', if (_z) 'Z'];
    if (axes.isEmpty) {
      return;
    }
    final bool ok = await confirmAction(
      context,
      title: 'Fijar cero de trabajo',
      message:
          'La posición actual pasará a ser el cero de G54 en los ejes '
          '${axes.join(', ')}. Se usa G10 L20, que GRBL guarda en EEPROM.',
      confirmLabel: 'Fijar cero',
    );
    if (!ok || !mounted) {
      return;
    }
    await ref
        .read(calibrationControllerProvider.notifier)
        .setWorkZero(x: _x, y: _y, z: _z);
  }

  @override
  Widget build(BuildContext context) {
    final ConnectionUiState connection = ref.watch(
      connectionControllerProvider,
    );
    final CalibrationUiState state = ref.watch(calibrationControllerProvider);
    final ThemeData theme = Theme.of(context);
    final bool connected = connection.isConnected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.home_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Origen y homing',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: connected ? _goToZero : null,
                  icon: const Icon(Icons.center_focus_strong, size: 18),
                  label: const Text('Ir a X0 Y0'),
                ),
                TextButton.icon(
                  onPressed: connected ? _home : null,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Homing'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'El homing lleva los ejes a los finales de carrera. Después, '
              'posiciona la herramienta y fija aquí el cero de trabajo.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final MachineAxis axis in MachineAxis.values)
                  FilterChip(
                    label: Text(axis.letter),
                    selected: switch (axis) {
                      MachineAxis.x => _x,
                      MachineAxis.y => _y,
                      MachineAxis.z => _z,
                    },
                    onSelected: (bool selected) {
                      setState(() {
                        switch (axis) {
                          case MachineAxis.x:
                            _x = selected;
                          case MachineAxis.y:
                            _y = selected;
                          case MachineAxis.z:
                            _z = selected;
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (connection.workPosition != null &&
                connection.workPosition!.length >= 3)
              Text(
                'WPos ${connection.positionIsLive ? 'actual' : '(última lectura)'}: '
                '${connection.workPosition![0].toStringAsFixed(2)}, '
                '${connection.workPosition![1].toStringAsFixed(2)}, '
                '${connection.workPosition![2].toStringAsFixed(2)} mm',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: connected ? _setZero : null,
              icon: const Icon(Icons.my_location),
              label: const Text('Fijar cero de trabajo (G10 L20)'),
            ),
            if (state.error == null && !connected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Conecta la máquina para hacer homing o fijar el origen.',
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
}
