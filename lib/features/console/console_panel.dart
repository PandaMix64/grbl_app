import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/machine_state.dart';
import '../connection/connection_controller.dart';
import 'console_controller.dart';

/// Consola de comandos con el tráfico del puerto y envío de líneas sueltas.
class ConsolePanel extends ConsumerStatefulWidget {
  const ConsolePanel({super.key});

  @override
  ConsumerState<ConsolePanel> createState() => _ConsolePanelState();
}

class _ConsolePanelState extends ConsumerState<ConsolePanel> {
  final TextEditingController _command = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _command.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  Future<void> _send([String? text]) async {
    final String command = text ?? _command.text;
    if (command.trim().isEmpty) {
      return;
    }
    await ref.read(consoleControllerProvider.notifier).send(command);
    if (!mounted) {
      return;
    }
    setState(() {
      _command.clear();
      _autoScroll = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
  }

  @override
  Widget build(BuildContext context) {
    final ConsoleUiState console = ref.watch(consoleControllerProvider);
    final ConnectionUiState connection = ref.watch(
      connectionControllerProvider,
    );
    final ThemeData theme = Theme.of(context);
    final TextStyle mono = (theme.textTheme.bodySmall ?? const TextStyle())
        .copyWith(fontFamily: 'monospace');

    ref.listen(consoleControllerProvider, (previous, next) {
      if (_autoScroll &&
          next.entries.length != (previous?.entries.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.terminal, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Consola', style: theme.textTheme.titleMedium),
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(consoleControllerProvider.notifier).clear(),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Limpiar'),
            ),
            IconButton(
              tooltip: _autoScroll ? 'Seguir el final' : 'Reanudar el scroll',
              onPressed: () => setState(() => _autoScroll = !_autoScroll),
              icon: Icon(
                _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                size: 20,
              ),
            ),
          ],
        ),
        Text(
          connection.isConnected
              ? 'Estado ${connection.machineState.label}. Los comandos con "\$" '
                    'se aceptan siempre; el resto exige Idle.'
              : 'Sin conexión: conecta la máquina para enviar comandos.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Expanded(child: _log(theme, mono, console)),
        // __CONSOLE_INPUT__
        if (console.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              console.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            if (console.sent.isNotEmpty)
              PopupMenuButton<String>(
                tooltip: 'Historial',
                onSelected: (String value) {
                  _command.text = value;
                  _command.selection = TextSelection.collapsed(
                    offset: value.length,
                  );
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  for (final String value in console.sent)
                    PopupMenuItem<String>(
                      value: value,
                      child: Text(value, style: mono),
                    ),
                ],
              ),
            Expanded(
              child: TextField(
                controller: _command,
                enabled: connection.isConnected,
                style: mono,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: r'Comando: $$ · $G · $I · ?',
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: connection.isConnected ? () => _send() : null,
              icon: const Icon(Icons.send),
              label: const Text('Enviar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          connection.isConnected && connection.machineState != MachineState.idle
              ? 'Con la máquina fuera de Idle solo se envían comandos "\$".'
              : 'La consola habla directamente con GRBL: verifica cada comando.',
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }

  Widget _log(ThemeData theme, TextStyle mono, ConsoleUiState console) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: console.entries.isEmpty
          ? Center(
              child: Text(
                'Sin tráfico todavía.',
                style: theme.textTheme.bodySmall,
              ),
            )
          : SelectionArea(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(8),
                itemCount: console.entries.length,
                itemBuilder: (BuildContext context, int index) {
                  final String line = console.entries[index];
                  final Color color = line.startsWith('→')
                      ? theme.colorScheme.primary
                      : line.startsWith('←')
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.tertiary;
                  return Text(
                    line,
                    style: mono.copyWith(color: color),
                    softWrap: true,
                  );
                },
              ),
            ),
    );
  }
}
