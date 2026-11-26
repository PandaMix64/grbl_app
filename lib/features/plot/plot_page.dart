import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/services/plot_generator.dart';
import 'plot_controller.dart';

/// Trazado con plóter: rutas vectoriales optimizadas o bordado raster.
class PlotPage extends ConsumerStatefulWidget {
  const PlotPage({super.key});

  @override
  ConsumerState<PlotPage> createState() => _PlotPageState();
}

class _PlotPageState extends ConsumerState<PlotPage> {
  final TextEditingController _width = TextEditingController(text: '120');
  final TextEditingController _pixel = TextEditingController(text: '0.3');
  final TextEditingController _penDownS = TextEditingController(text: '1000');
  final TextEditingController _zUp = TextEditingController(text: '2');
  final TextEditingController _zDown = TextEditingController(text: '-0.3');
  final TextEditingController _drawFeed = TextEditingController(text: '1500');
  final TextEditingController _travelFeed = TextEditingController(text: '4000');
  final TextEditingController _simplify = TextEditingController(text: '0.15');
  final TextEditingController _smooth = TextEditingController(text: '0.4');
  final TextEditingController _spacing = TextEditingController(text: '1.5');
  final TextEditingController _angle = TextEditingController(text: '45');
  final TextEditingController _stitch = TextEditingController(text: '0');

  PlotMode _mode = PlotMode.vector;
  PenControl _pen = PenControl.spindle;
  double _threshold = 0.5;
  bool _invert = false;
  bool _optimize = true;

  /// `true` cuando el operario escribe en «Altura segura Z»: a partir de ahí la
  /// app no vuelve a proponer la del perfil.
  bool _safeZTouched = false;
  bool _safeZApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _applyProfileSafeZ(ref.read(activeProfileProvider).value);
      }
    });
  }

  /// Propone la altura segura del perfil como Z de viaje mientras el campo no
  /// se haya tocado: es la altura que la app ya considera libre de choques.
  void _applyProfileSafeZ(MachineProfile? profile) {
    if (profile == null ||
        _safeZTouched ||
        _safeZApplied ||
        profile.safeZmm <= 0) {
      return;
    }
    _safeZApplied = true;
    setState(() => _zUp.text = _formatMm(profile.safeZmm));
  }

  static String _formatMm(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  void dispose() {
    _width.dispose();
    _pixel.dispose();
    _penDownS.dispose();
    _zUp.dispose();
    _zDown.dispose();
    _drawFeed.dispose();
    _travelFeed.dispose();
    _simplify.dispose();
    _smooth.dispose();
    _spacing.dispose();
    _angle.dispose();
    _stitch.dispose();
    super.dispose();
  }

  static double _parse(TextEditingController controller, double fallback) {
    final double? value = double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    );
    return value == null || value <= 0 ? fallback : value;
  }

  static double _parseSigned(
    TextEditingController controller,
    double fallback,
  ) {
    final double? value = double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    );
    return value ?? fallback;
  }

  PlotSettings get _settings => PlotSettings(
    widthMm: _parse(_width, 120),
    pixelMm: _parse(_pixel, 0.3),
    threshold: _threshold,
    invert: _invert,
    mode: _mode,
    pen: _pen,
    penDownS: _parse(_penDownS, 1000).round(),
    zUpMm: _parseSigned(_zUp, 2),
    zDownMm: _parseSigned(_zDown, -0.3),
    drawFeedMmMin: _parse(_drawFeed, 1500),
    travelFeedMmMin: _parse(_travelFeed, 4000),
    simplifyMm: _parseSigned(_simplify, 0.15),
    smoothMm: _parseSigned(_smooth, 0.4),
    optimizeOrder: _optimize,
    hatchSpacingMm: _parse(_spacing, 1.5),
    hatchAngleDeg: _parseSigned(_angle, 45),
    stitchMm: _parseSigned(_stitch, 0),
  );

  Future<void> _pickImage() async {
    const XTypeGroup group = XTypeGroup(
      label: 'Imagen',
      extensions: <String>['png', 'jpg', 'jpeg', 'bmp'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    ref.read(plotControllerProvider.notifier).loadImage(bytes, file.name);
  }

  void _useProfileDefaults() {
    final MachineProfile? profile = ref.read(activeProfileProvider).value;
    if (profile == null) {
      return;
    }
    setState(() {
      _width.text = profile.travelXmm.clamp(5, 2000).toStringAsFixed(0);
      _drawFeed.text = profile.defaultFeedMmMin.toStringAsFixed(0);
      _travelFeed.text = (profile.defaultFeedMmMin * 2.5)
          .clamp(100, 30000)
          .toStringAsFixed(0);
      if (profile.safeZmm > 0) {
        _safeZApplied = true;
        _zUp.text = _formatMm(profile.safeZmm);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final PlotUiState state = ref.watch(plotControllerProvider);
    final MachineProfile? profile = ref.watch(activeProfileProvider).value;
    final ThemeData theme = Theme.of(context);
    // El perfil llega de forma asíncrona: se recoge aquí la primera vez.
    ref.listen<AsyncValue<MachineProfile?>>(activeProfileProvider, (
      AsyncValue<MachineProfile?>? previous,
      AsyncValue<MachineProfile?> next,
    ) {
      _applyProfileSafeZ(next.value);
    });

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Trazado · Plóter',
                    style: theme.textTheme.headlineMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: profile == null ? null : _useProfileDefaults,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Valores del perfil'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: state.isBusy ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    state.hasImage ? 'Cambiar imagen' : 'Elegir imagen',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _mode == PlotMode.vector
                  ? 'Rutas vectoriales: silueta vectorizada y ordenada por '
                        'proximidad para dibujar con el rotulador.'
                  : 'Bordado raster: líneas paralelas que rellenan las zonas '
                        'oscuras, con puntadas opcionales.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<PlotMode>(
              segments: <ButtonSegment<PlotMode>>[
                for (final PlotMode mode in PlotMode.values)
                  ButtonSegment<PlotMode>(value: mode, label: Text(mode.label)),
              ],
              selected: <PlotMode>{_mode},
              onSelectionChanged: (Set<PlotMode> selection) =>
                  setState(() => _mode = selection.first),
            ),
            const SizedBox(height: 16),
            if (state.error != null)
              _Notice(
                text: state.error!,
                icon: Icons.error_outline,
                color: theme.colorScheme.error,
              ),
            if (state.message != null)
              _Notice(
                text: state.message!,
                icon: Icons.info_outline,
                color: theme.colorScheme.primary,
              ),
            _Panel(
              icon: Icons.image_outlined,
              title: 'Imagen',
              child: Text(
                state.fileName ?? 'Sin imagen cargada',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: state.hasImage
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.tertiary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _params(theme),
            const SizedBox(height: 16),
            _result(theme, state),
          ],
        ),
      ),
    );
  }

  Widget _params(ThemeData theme) {
    return _Panel(
      icon: Icons.tune,
      title: 'Parámetros de trazado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: <Widget>[
              _Field(
                label: 'Ancho (mm)',
                controller: _width,
                width: 120,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'mm por celda',
                controller: _pixel,
                width: 120,
                onChanged: () => setState(() {}),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Rotulador', style: theme.textTheme.labelSmall),
                  DropdownButton<PenControl>(
                    value: _pen,
                    items: <DropdownMenuItem<PenControl>>[
                      for (final PenControl pen in PenControl.values)
                        DropdownMenuItem<PenControl>(
                          value: pen,
                          child: Text(pen.label),
                        ),
                    ],
                    onChanged: (PenControl? pen) {
                      if (pen != null) {
                        setState(() => _pen = pen);
                      }
                    },
                  ),
                ],
              ),
              if (_pen == PenControl.spindle)
                _Field(
                  label: 'S de bajada',
                  controller: _penDownS,
                  width: 120,
                  onChanged: () => setState(() {}),
                )
              else ...<Widget>[
                _Field(
                  label: 'Altura segura Z',
                  controller: _zUp,
                  width: 130,
                  onChanged: () => setState(() => _safeZTouched = true),
                ),
                _Field(
                  label: 'Z de dibujo',
                  controller: _zDown,
                  width: 110,
                  onChanged: () => setState(() {}),
                ),
              ],
              _Field(
                label: 'Avance dibujo',
                controller: _drawFeed,
                width: 130,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Avance viaje',
                controller: _travelFeed,
                width: 130,
                onChanged: () => setState(() {}),
              ),
              if (_mode == PlotMode.vector) ...<Widget>[
                _Field(
                  label: 'Simplificar (mm)',
                  controller: _simplify,
                  width: 140,
                  onChanged: () => setState(() {}),
                ),
                _Field(
                  label: 'Suavizar (mm)',
                  controller: _smooth,
                  width: 130,
                  onChanged: () => setState(() {}),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Optimizar orden', style: theme.textTheme.labelMedium),
                    Switch(
                      value: _optimize,
                      onChanged: (bool value) =>
                          setState(() => _optimize = value),
                    ),
                  ],
                ),
              ] else ...<Widget>[
                _Field(
                  label: 'Separación (mm)',
                  controller: _spacing,
                  width: 130,
                  onChanged: () => setState(() {}),
                ),
                _Field(
                  label: 'Ángulo (°)',
                  controller: _angle,
                  width: 100,
                  onChanged: () => setState(() {}),
                ),
                _Field(
                  label: 'Puntada (mm)',
                  controller: _stitch,
                  width: 120,
                  onChanged: () => setState(() {}),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _pen == PenControl.spindle
                ? 'Con «Husillo» la punta se controla con M3 S…/M5: el G-code no '
                      'emite ningún movimiento de Z. Si tu plóter la eleva con '
                      'el eje Z, elige «Eje Z».'
                : 'Cada trayecto se abre con G0 Z… (altura segura) y la punta '
                      'solo baja con G1 Z… mientras dibuja.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _pen == PenControl.spindle
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Umbral: ${(_threshold * 100).toStringAsFixed(0)} %',
            style: theme.textTheme.labelSmall,
          ),
          SizedBox(
            width: 360,
            child: Slider(
              value: _threshold,
              divisions: 20,
              label: '${(_threshold * 100).toStringAsFixed(0)} %',
              onChanged: (double value) => setState(() => _threshold = value),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Invertir', style: theme.textTheme.labelMedium),
              Switch(
                value: _invert,
                onChanged: (bool value) => setState(() => _invert = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _result(ThemeData theme, PlotUiState state) {
    return _Panel(
      icon: Icons.draw_outlined,
      title: 'Resultado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (state.result == null)
            Text(
              'Elige una imagen, ajusta los parámetros y pulsa «Generar». '
              'Después revisa el dibujo en el visor antes de ejecutarlo.',
              style: theme.textTheme.bodySmall,
            )
          else ...<Widget>[
            _PathPreview(
              png: state.result!.previewPng,
              caption: state.result!.mode == PlotMode.vector
                  ? 'Rutas vectoriales: ${state.result!.paths} trayectos'
                  : 'Bordado raster: ${state.result!.paths} pasadas',
            ),
            const SizedBox(height: 12),
            Text(
              'Tamaño: ${state.result!.widthMm.toStringAsFixed(1)} × '
              '${state.result!.heightMm.toStringAsFixed(1)} mm · '
              '${state.result!.points} puntos',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${state.result!.lineCount} líneas · '
              '${state.result!.paths} trayectos · ${state.result!.mode.label}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: state.isBusy || !state.hasImage
                    ? null
                    : () => ref
                          .read(plotControllerProvider.notifier)
                          .generate(_settings),
                icon: state.isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(state.isBusy ? 'Generando…' : 'Generar'),
              ),
              FilledButton.tonalIcon(
                onPressed: !state.hasResult
                    ? null
                    : () => ref
                          .read(plotControllerProvider.notifier)
                          .sendToViewer(),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Enviar al visor'),
              ),
              if (state.hasImage)
                TextButton.icon(
                  onPressed: () =>
                      ref.read(plotControllerProvider.notifier).clear(),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Descartar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Vista previa del dibujo sobre fondo claro.
class _PathPreview extends StatelessWidget {
  const _PathPreview({required this.png, required this.caption});

  final Uint8List png;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(
          child: Container(
            width: 420,
            height: 300,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F2EA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Image.memory(
              png,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              gaplessPlayback: true,
              semanticLabel: 'Vista previa del trazado',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(child: Text(caption, style: theme.textTheme.labelSmall)),
      ],
    );
  }
}

/// Tarjeta con icono y título.
class _Panel extends StatelessWidget {
  const _Panel({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Campo numérico con etiqueta.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.width,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final double width;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelSmall),
        SizedBox(
          width: width,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

/// Aviso de una línea con icono.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon, required this.color});

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
