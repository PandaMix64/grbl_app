import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/grbl_settings.dart';
import '../../connection/connection_controller.dart';
import '../calibration_controller.dart';

/// Parámetros `$` de la EEPROM: lectura, edición y escritura por diferencias.
class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  /// Códigos con impacto directo en la operación diaria.
  static const List<int> visibleCodes = <int>[
    0,
    1,
    3,
    10,
    20,
    21,
    22,
    24,
    25,
    27,
    30,
    31,
    32,
    100,
    101,
    102,
    110,
    111,
    112,
    120,
    121,
    122,
    130,
    131,
    132,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalibrationUiState state = ref.watch(calibrationControllerProvider);
    final CalibrationController controller = ref.read(
      calibrationControllerProvider.notifier,
    );
    final bool connected = ref.watch(connectionControllerProvider).isConnected;
    final ThemeData theme = Theme.of(context);
    final GrblSettings? settings = state.settings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.tune, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Parámetros de GRBL', style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: connected ? controller.refreshSettings : null,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(settings == null ? 'Leer' : 'Recargar'),
                ),
              ],
            ),
            if (settings == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  connected
                      ? 'Pulsa "Leer" para cargar la EEPROM.'
                      : 'Conecta la máquina para leer la EEPROM.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else ...<Widget>[
              Text(
                '${state.draft.length} parámetros · '
                '${state.pending.length} pendientes de escribir',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final int code in visibleCodes)
                if (state.draft.containsKey(code))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: <Widget>[
                        SizedBox(width: 52, child: Text('\$$code')),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey<String>(
                              'param_${code}_${state.settingsRevision}',
                            ),
                            initialValue: state.draft[code],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: const OutlineInputBorder(),
                              labelText:
                                  GrblSettings.labels[code] ??
                                  'Parámetro $code',
                            ),
                            onChanged: (String value) =>
                                controller.setDraftValue(code, value.trim()),
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: connected && state.hasPendingChanges
                    ? controller.applyDraft
                    : null,
                icon: const Icon(Icons.save_outlined),
                label: Text('Escribir ${state.pending.length} cambios'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
