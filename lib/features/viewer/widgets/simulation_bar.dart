import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../execution_controller.dart';
import '../preview_visibility.dart';
import '../simulation_controller.dart';

/// Barra del simulador: reproducir, avanzar bloque a bloque y línea de tiempo.
///
/// Es una sola fila superpuesta al lienzo (abajo) para no robar viewport. El
/// reloj lo mueve un [Ticker] propio que se detiene al pausar o al final; el
/// estado vive en `simulationControllerProvider`, así que la barra solo pinta.
class SimulationBar extends ConsumerStatefulWidget {
  const SimulationBar({super.key});

  @override
  ConsumerState<SimulationBar> createState() => _SimulationBarState();
}

class _SimulationBarState extends ConsumerState<SimulationBar>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _resumeAfterSeek = false;

  /// Paso máximo de reloj por fotograma (tirones, segundo plano, pestaña oculta).
  static const Duration _maxTickStep = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncTicker(ref.read(simulationControllerProvider).playing);
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    Duration delta = elapsed - _last;
    _last = elapsed;
    if (delta <= Duration.zero) {
      return;
    }
    // Un tirón de fotograma (o volver de segundo plano) no debe teletransportar
    // el cabezal: se limita el paso máximo por tick.
    if (delta > _maxTickStep) {
      delta = _maxTickStep;
    }
    ref
        .read(simulationControllerProvider.notifier)
        .advance(delta.inMicroseconds / Duration.microsecondsPerSecond);
  }

  void _syncTicker(bool playing) {
    if (playing && !_ticker.isActive) {
      // El ticker reinicia su cronómetro en cada `start()`.
      _last = Duration.zero;
      _ticker.start();
    } else if (!playing && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SimulationUiState simulation = ref.watch(
      simulationControllerProvider,
    );
    final bool jobActive = ref.watch(
      executionControllerProvider.select(
        (ExecutionUiState state) => state.isActive,
      ),
    );
    final SimulationController controller = ref.read(
      simulationControllerProvider.notifier,
    );
    final PreviewVisibility visibility = ref.watch(previewVisibilityProvider);

    ref.listen<bool>(
      simulationControllerProvider.select(
        (SimulationUiState state) => state.playing,
      ),
      (bool? previous, bool next) => _syncTicker(next),
    );
    // Durante un trabajo real la simulación se aparta: dos cabezales en el mismo
    // lienzo confunden y el operario debe mirar la máquina.
    ref.listen<bool>(
      executionControllerProvider.select(
        (ExecutionUiState state) => state.isActive,
      ),
      (bool? previous, bool next) {
        if (next) {
          controller.pause();
        }
      },
    );

    final bool enabled = simulation.isReady && !jobActive;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            _button(
              icon: Icons.skip_previous,
              tooltip: 'Bloque anterior',
              onPressed: enabled ? controller.stepBack : null,
            ),
            _button(
              icon: simulation.playing ? Icons.pause : Icons.play_arrow,
              tooltip: simulation.playing
                  ? 'Pausar simulación'
                  : 'Reproducir simulación',
              onPressed: enabled ? controller.toggle : null,
              color: theme.colorScheme.tertiary,
            ),
            _button(
              icon: Icons.skip_next,
              tooltip: 'Bloque siguiente',
              onPressed: enabled ? controller.stepForward : null,
            ),
            Expanded(
              child: SizedBox(
                height: 34,
                child: _timeline(theme, simulation, controller, enabled),
              ),
            ),
            _speedMenu(theme, simulation, controller, enabled),
            _button(
              icon: visibility.showSimulation
                  ? Icons.visibility
                  : Icons.visibility_off,
              tooltip: visibility.showSimulation
                  ? 'Ocultar simulación'
                  : 'Mostrar simulación',
              onPressed: () => ref
                  .read(previewVisibilityProvider.notifier)
                  .toggleSimulation(),
            ),
            _time(theme, simulation),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 32),
      iconSize: 20,
      onPressed: onPressed,
      icon: Icon(icon),
      color: color,
    );
  }

  Widget _timeline(
    ThemeData theme,
    SimulationUiState simulation,
    SimulationController controller,
    bool enabled,
  ) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6,
          disabledThumbRadius: 4,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: theme.colorScheme.tertiary,
        thumbColor: theme.colorScheme.tertiary,
        inactiveTrackColor: theme.colorScheme.outlineVariant,
      ),
      child: Slider(
        value: simulation.progress,
        onChangeStart: enabled
            ? (double _) {
                _resumeAfterSeek = simulation.playing;
                controller.pause();
              }
            : null,
        onChanged: enabled
            ? (double value) => controller.seekFraction(value)
            : null,
        onChangeEnd: enabled
            ? (double _) {
                if (_resumeAfterSeek) {
                  controller.play();
                }
                _resumeAfterSeek = false;
              }
            : null,
      ),
    );
  }

  Widget _speedMenu(
    ThemeData theme,
    SimulationUiState simulation,
    SimulationController controller,
    bool enabled,
  ) {
    return PopupMenuButton<double>(
      enabled: enabled,
      tooltip: 'Velocidad de simulación',
      initialValue: simulation.speed,
      onSelected: controller.setSpeed,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
        for (final double speed in SimulationController.speeds)
          PopupMenuItem<double>(
            value: speed,
            child: Text('${_speedLabel(speed)}×'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          '${_speedLabel(simulation.speed)}×',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        ),
      ),
    );
  }

  Widget _time(ThemeData theme, SimulationUiState simulation) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 126),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          '${simulation.seconds.toStringAsFixed(1)}/'
          '${simulation.totalSeconds.toStringAsFixed(1)} s · L${simulation.line}',
          style: theme.textTheme.labelSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
        ),
      ),
    );
  }

  static String _speedLabel(double speed) {
    if (speed == speed.roundToDouble()) {
      return speed.toStringAsFixed(0);
    }
    return speed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
