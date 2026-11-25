import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/grbl_handshake.dart';
import '../../../domain/entities/machine_state.dart';
import '../../../domain/repositories/serial_port_repository.dart';
import '../../../domain/services/profile_consistency.dart';
import '../connection_controller.dart';

/// Barra de conexión: puerto, velocidad, estado de la máquina y avisos del
/// handshake (búfer real, versión del firmware y discrepancias de perfil).
class ConnectionBar extends ConsumerStatefulWidget {
  const ConnectionBar({super.key});

  @override
  ConsumerState<ConnectionBar> createState() => _ConnectionBarState();
}

class _ConnectionBarState extends ConsumerState<ConnectionBar> {
  static const List<int> _baudRates = <int>[9600, 57600, 115200, 250000];

  @override
  void initState() {
    super.initState();
    // La enumeración FFI puede tardar; se lanza después del primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(connectionControllerProvider.notifier).refreshPorts());
    });
  }

  @override
  Widget build(BuildContext context) {
    final ConnectionUiState state = ref.watch(connectionControllerProvider);
    final ConnectionController controller = ref.read(
      connectionControllerProvider.notifier,
    );
    final ThemeData theme = Theme.of(context);
    final bool locked = state.isConnected || state.isBusy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.usb, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Conexión', style: theme.textTheme.titleMedium),
                const Spacer(),
                _StateChip(state: state.machineState),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _Labeled(
                  label: 'Puerto',
                  child: DropdownButton<String>(
                    value: state.selectedPort,
                    hint: Text(state.ports.isEmpty ? 'Sin puertos' : 'Elegir'),
                    items: <DropdownMenuItem<String>>[
                      for (final SerialPortInfo port in state.ports)
                        DropdownMenuItem<String>(
                          value: port.name,
                          child: Text(port.name),
                        ),
                    ],
                    onChanged: locked ? null : controller.selectPort,
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar puertos',
                  onPressed: state.isBusy ? null : controller.refreshPorts,
                  icon: const Icon(Icons.refresh),
                ),
                _Labeled(
                  label: 'Baudios',
                  child: DropdownButton<int>(
                    value: state.baudRate,
                    items: <DropdownMenuItem<int>>[
                      for (final int baud in _baudRates)
                        DropdownMenuItem<int>(
                          value: baud,
                          child: Text('$baud'),
                        ),
                    ],
                    onChanged: locked
                        ? null
                        : (int? baud) {
                            if (baud != null) {
                              controller.selectBaudRate(baud);
                            }
                          },
                  ),
                ),
                FilledButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : (state.isConnected
                            ? controller.disconnect
                            : controller.connect),
                  icon: Icon(state.isConnected ? Icons.link_off : Icons.link),
                  label: Text(state.isConnected ? 'Desconectar' : 'Conectar'),
                ),
              ],
            ),
            if (state.isBusy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            ..._details(theme, state),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(ThemeData theme, ConnectionUiState state) {
    final List<Widget> widgets = <Widget>[];
    final GrblHandshake? handshake = state.handshake;

    if (handshake != null) {
      final String info =
          'GRBL ${handshake.firmwareVersion} · '
          'búfer ${handshake.rxBufferSize} B · '
          '${handshake.settings.codes.length} parámetros';
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(info, style: theme.textTheme.bodySmall),
        ),
      );
    }

    final List<double>? position = state.workPosition;
    if (position != null && position.length >= 3) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'WPos: ${position[0].toStringAsFixed(3)}, '
            '${position[1].toStringAsFixed(3)}, '
            '${position[2].toStringAsFixed(3)} mm',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    if (state.error != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (final ConsistencyIssue issue in state.issues) {
      final bool blocking = issue.blocks;
      final Color color = blocking
          ? theme.colorScheme.error
          : theme.colorScheme.tertiary;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                blocking ? Icons.block : Icons.warning_amber_outlined,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  issue.message,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }
}

/// Distintivo del estado reportado por la máquina.
class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

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
    return Chip(
      avatar: Icon(Icons.circle, size: 12, color: color),
      label: Text(state.label),
      labelStyle: theme.textTheme.labelMedium?.copyWith(color: color),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}

/// Etiqueta pequeña encima de un control.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelSmall),
        child,
      ],
    );
  }
}
