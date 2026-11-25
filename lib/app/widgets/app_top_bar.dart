import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/confirm_dialog.dart';
import '../../data/serial/grbl_worker_client.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/entities/machine_state.dart';
import '../../domain/services/profile_consistency.dart';
import '../../features/calibration/calibration_controller.dart';
import '../../features/connection/connection_controller.dart';
import '../../features/console/console_controller.dart';
import '../../features/console/console_panel.dart';
import '../../features/viewer/execution_controller.dart';
import '../providers.dart';

/// Barra superior persistente: estado de la máquina, perfil activo, consola y
/// comandos básicos (`$X`, soft reset).
///
/// Vive por encima del enrutador para que el operario tenga siempre a la vista el
/// estado real y una salida de emergencia sin cambiar de módulo.
class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ConnectionUiState connection = ref.watch(
      connectionControllerProvider,
    );
    final ExecutionUiState execution = ref.watch(executionControllerProvider);
    final List<MachineProfile> profiles =
        ref.watch(profilesProvider).value ?? const <MachineProfile>[];
    final String? activeId = ref.watch(activeProfileIdProvider);
    // Mantiene viva la captura de logs desde el arranque, no solo al abrirla.
    ref.watch(consoleControllerProvider);

    final ThemeData theme = Theme.of(context);
    final String? selectedId = _selectedProfileId(profiles, activeId);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.precision_manufacturing_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              _MachineBadge(state: connection.machineState),
              const SizedBox(width: 8),
              Icon(
                connection.isConnected ? Icons.usb : Icons.usb_off,
                size: 18,
                color: connection.isConnected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 16),
              if (profiles.isEmpty)
                Text(
                  'Sin perfil de máquina',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                )
              else
                Row(
                  children: <Widget>[
                    Text('Perfil', style: theme.textTheme.labelSmall),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedId,
                      underline: const SizedBox.shrink(),
                      items: <DropdownMenuItem<String>>[
                        for (final MachineProfile profile in profiles)
                          DropdownMenuItem<String>(
                            value: profile.id,
                            child: Text(profile.name),
                          ),
                      ],
                      onChanged: (String? id) => _selectProfile(ref, id),
                    ),
                  ],
                ),
              if (connection.issues.isNotEmpty)
                Tooltip(
                  message: connection.issues
                      .map((ConsistencyIssue issue) => issue.message)
                      .join('\n'),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                key: const Key('topbar-console'),
                tooltip: 'Consola y logs',
                onPressed: () => _openConsole(context),
                icon: const Icon(Icons.terminal),
              ),
              IconButton(
                key: const Key('topbar-unlock'),
                tooltip: 'Desbloquear alarma (\$X)',
                onPressed:
                    connection.isConnected && connection.machineState.isBlocked
                    ? () => _unlock(context, ref)
                    : null,
                icon: const Icon(Icons.lock_open),
              ),
              IconButton(
                key: const Key('topbar-soft-reset'),
                tooltip: 'Soft reset (0x18)',
                onPressed: connection.isConnected
                    ? () => _softReset(context, ref, execution)
                    : null,
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _selectedProfileId(
    List<MachineProfile> profiles,
    String? activeId,
  ) {
    if (activeId != null &&
        profiles.any((MachineProfile p) => p.id == activeId)) {
      return activeId;
    }
    return profiles.isEmpty ? null : profiles.first.id;
  }

  void _selectProfile(WidgetRef ref, String? id) {
    ref.read(activeProfileIdProvider.notifier).select(id);
    ref.read(calibrationControllerProvider.notifier).selectProfile(id);
    final settings = ref.read(connectionControllerProvider).handshake?.settings;
    if (settings != null) {
      // Al cambiar de perfil el aviso de discrepancias debe recalcularse ya.
      unawaited(
        ref.read(connectionControllerProvider.notifier).revalidate(settings),
      );
    }
  }

  Future<void> _openConsole(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 580),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: ConsolePanel(),
          ),
        ),
      ),
    );
  }

  Future<void> _unlock(BuildContext context, WidgetRef ref) async {
    final bool ok = await confirmAction(
      context,
      title: 'Desbloquear alarma',
      message:
          'Se enviará \$X para salir del estado bloqueado. La causa de la '
          'alarma sigue ahí: verifica topes, límites y la pieza antes de mover.',
      confirmLabel: 'Desbloquear',
    );
    if (!ok || !context.mounted) {
      return;
    }
    final GrblWorkerClient? client = ref.read(grblWorkerProvider).value;
    if (client == null) {
      return;
    }
    try {
      await client.unlock();
    } on Object catch (error) {
      if (context.mounted) {
        _report(context, 'No se pudo desbloquear: $error');
      }
    }
  }

  Future<void> _softReset(
    BuildContext context,
    WidgetRef ref,
    ExecutionUiState execution,
  ) async {
    if (execution.isActive) {
      _report(
        context,
        'Hay un trabajo en curso: usa «Detener» en el visor para guardar el '
        'progreso antes de resetear.',
      );
      return;
    }
    final bool ok = await confirmAction(
      context,
      title: 'Soft reset',
      message:
          'El controlador se reiniciará: se pierde la posición, el estado modal '
          'y cualquier referencia de origen hasta re-hacer homing. No es una '
          'pausa.',
      confirmLabel: 'Resetear',
    );
    if (!ok || !context.mounted) {
      return;
    }
    final GrblWorkerClient? client = ref.read(grblWorkerProvider).value;
    if (client == null) {
      return;
    }
    try {
      await client.softReset();
      if (context.mounted) {
        _report(
          context,
          'Controlador reiniciado. Revisa el estado y el origen.',
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        _report(context, 'Soft reset fallido: $error');
      }
    }
  }

  static void _report(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Estado de la máquina en formato compacto.
class _MachineBadge extends StatelessWidget {
  const _MachineBadge({required this.state});

  final MachineState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = switch (state) {
      MachineState.idle => theme.colorScheme.primary,
      MachineState.run || MachineState.jog => theme.colorScheme.secondary,
      MachineState.hold || MachineState.door => theme.colorScheme.tertiary,
      MachineState.alarm => theme.colorScheme.error,
      _ => theme.colorScheme.outline,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(
          state.label,
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
