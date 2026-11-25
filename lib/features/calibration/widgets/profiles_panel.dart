import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/machine_profile.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../connection/connection_controller.dart';
import '../calibration_controller.dart';
import 'profile_dialog.dart';

/// Lista de perfiles de máquina con creación, edición y borrado.
class ProfilesPanel extends ConsumerWidget {
  const ProfilesPanel({super.key});

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
                Icon(
                  Icons.precision_manufacturing_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Perfiles de máquina', style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo'),
                ),
              ],
            ),
            if (state.profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Sin perfiles: crea uno para que la app conozca el volumen de '
                  'trabajo, la herramienta y la holgura de tu máquina.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              for (final MachineProfile profile in state.profiles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: profile.id == state.selectedProfileId,
                  leading: Icon(
                    profile.usesLaserMode ? Icons.flash_on : Icons.cut,
                  ),
                  title: Text(profile.name),
                  subtitle: Text(
                    '${profile.tool.name} · '
                    '${profile.travelXmm.toStringAsFixed(0)}×'
                    '${profile.travelYmm.toStringAsFixed(0)}×'
                    '${profile.travelZmm.toStringAsFixed(0)} mm · '
                    'holgura ${profile.backlashXmm.toStringAsFixed(2)}/'
                    '${profile.backlashYmm.toStringAsFixed(2)} mm',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, ref, profile: profile),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => controller.deleteProfile(profile.id),
                      ),
                    ],
                  ),
                  onTap: () => controller.selectProfile(profile.id),
                ),
            if (state.selectedProfile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.tonalIcon(
                  onPressed: connected
                      ? () =>
                            _applyProfile(context, ref, state.selectedProfile!)
                      : null,
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Aplicar perfil a la máquina'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _applyProfile(
    BuildContext context,
    WidgetRef ref,
    MachineProfile profile,
  ) async {
    final bool ok = await confirmAction(
      context,
      title: 'Aplicar perfil a la máquina',
      message:
          'Se escribirán en la EEPROM el modo de herramienta, las RPM máximas '
          'y el recorrido (límites del volumen) del perfil «${profile.name}». '
          'Solo se envían los valores que difieran de la máquina.',
      confirmLabel: 'Aplicar',
    );
    if (!ok) {
      return;
    }
    await ref
        .read(calibrationControllerProvider.notifier)
        .applyProfileToSettings();
  }

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    MachineProfile? profile,
  }) async {
    final MachineProfile? result = await showDialog<MachineProfile>(
      context: context,
      builder: (BuildContext dialogContext) => ProfileDialog(profile: profile),
    );
    if (result != null) {
      await ref
          .read(calibrationControllerProvider.notifier)
          .saveProfile(result);
    }
  }
}
