import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/services/contour_generator.dart';
import '../../domain/services/engraving_generator.dart';
import '../../domain/services/relief_generator.dart';
import 'cam_controller.dart';

/// Vista previa del trabajo: el resultado sobre el material.
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
              // Fondo claro: el trabajo se ve como sobre la pieza.
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
              semanticLabel: 'Vista previa del trabajo',
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

/// CAM: imagen → G-code de grabado láser, con previsualización en el visor.
class CamPage extends ConsumerStatefulWidget {
  const CamPage({super.key});

  @override
  ConsumerState<CamPage> createState() => _CamPageState();
}

class _CamPageState extends ConsumerState<CamPage> {
  final TextEditingController _width = TextEditingController(text: '80');
  final TextEditingController _pixel = TextEditingController(text: '0.5');
  final TextEditingController _power = TextEditingController(text: '1000');
  final TextEditingController _feed = TextEditingController(text: '1200');
  final TextEditingController _cutZ = TextEditingController(text: '-1');
  final TextEditingController _passDepth = TextEditingController(text: '0.5');
  final TextEditingController _safeZ = TextEditingController(text: '2');
  final TextEditingController _tabs = TextEditingController(text: '0');
  final TextEditingController _tabWidth = TextEditingController(text: '3');
  final TextEditingController _tabHeight = TextEditingController(text: '0.8');
  final TextEditingController _levels = TextEditingController(text: '8');
  final TextEditingController _maxDepth = TextEditingController(text: '3');

  EngravingMode _mode = EngravingMode.threshold;
  ContourTool _contourTool = ContourTool.laser;
  double _threshold = 0.5;
  bool _invert = false;

  @override
  void dispose() {
    _width.dispose();
    _pixel.dispose();
    _power.dispose();
    _feed.dispose();
    _cutZ.dispose();
    _passDepth.dispose();
    _safeZ.dispose();
    _tabs.dispose();
    _tabWidth.dispose();
    _tabHeight.dispose();
    _levels.dispose();
    _maxDepth.dispose();
    super.dispose();
  }

  static double _parse(TextEditingController controller, double fallback) {
    final double? value = double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    );
    return value == null || value <= 0 ? fallback : value;
  }

  /// Igual que [_parse] pero admite negativos (profundidad de corte).
  static double _parseSigned(
    TextEditingController controller,
    double fallback,
  ) {
    final double? value = double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    );
    return value ?? fallback;
  }

  static int _parseCount(TextEditingController controller) {
    final int? value = int.tryParse(controller.text.trim());
    return value == null || value < 0 ? 0 : value;
  }

  Widget _reliefPanel(ThemeData theme) {
    return _Panel(
      icon: Icons.landscape_outlined,
      title: 'Parámetros de relieve',
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
              _Field(
                label: 'Niveles',
                controller: _levels,
                width: 90,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Profundidad (mm)',
                controller: _maxDepth,
                width: 140,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Paso por pasada',
                controller: _passDepth,
                width: 130,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'RPM',
                controller: _power,
                width: 110,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Avance (mm/min)',
                controller: _feed,
                width: 140,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Z segura',
                controller: _safeZ,
                width: 110,
                onChanged: () => setState(() {}),
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
          const SizedBox(height: 8),
          Text(
            'Claro = sin fresar; oscuro = profundidad máxima. Cada nivel se '
            'fresa con pasadas hasta su cota, así que el acabado es una '
            'escalera de profundidad (requiere fresadora).',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _contourPanel(ThemeData theme) {
    return _Panel(
      icon: Icons.content_cut,
      title: 'Parámetros de corte',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Herramienta', style: theme.textTheme.labelSmall),
                  DropdownButton<ContourTool>(
                    value: _contourTool,
                    items: <DropdownMenuItem<ContourTool>>[
                      for (final ContourTool tool in ContourTool.values)
                        DropdownMenuItem<ContourTool>(
                          value: tool,
                          child: Text(tool.label),
                        ),
                    ],
                    onChanged: (ContourTool? tool) {
                      if (tool != null) {
                        setState(() => _contourTool = tool);
                      }
                    },
                  ),
                ],
              ),
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
              _Field(
                label: 'Potencia / RPM',
                controller: _power,
                width: 130,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Avance (mm/min)',
                controller: _feed,
                width: 140,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Profundidad Z',
                controller: _cutZ,
                width: 130,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Paso por pasada',
                controller: _passDepth,
                width: 130,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Z segura',
                controller: _safeZ,
                width: 110,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Pestañas',
                controller: _tabs,
                width: 90,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Ancho pestaña',
                controller: _tabWidth,
                width: 130,
                onChanged: () => setState(() {}),
              ),
              _Field(
                label: 'Alto pestaña',
                controller: _tabHeight,
                width: 120,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Umbral: ${(_threshold * 100).toStringAsFixed(0)} % '
            '(compartido con el grabado)',
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
          Text(
            'La profundidad y las pasadas solo afectan al husillo; en láser las '
            'pestañas apagan el haz (tolerancia de simplificación 0.2 mm).',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  List<Widget> _resultSummary(CamUiState state, ThemeData theme) {
    final EngravingResult? engrave = state.engraveResult;
    if (engrave != null) {
      return <Widget>[
        Text(
          'Tamaño: ${engrave.widthMm.toStringAsFixed(1)} × '
          '${engrave.heightMm.toStringAsFixed(1)} mm · '
          '${engrave.columns}×${engrave.rows} celdas',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${engrave.lineCount} líneas · '
          '${(engrave.litRatio * 100).toStringAsFixed(0)} % grabado · '
          '${engrave.mode.label} · S máx. ${engrave.maxPower}',
          style: theme.textTheme.bodySmall,
        ),
      ];
    }
    final ContourResult? contour = state.contourResult;
    if (contour != null) {
      return <Widget>[
        Text(
          'Tamaño: ${contour.widthMm.toStringAsFixed(1)} × '
          '${contour.heightMm.toStringAsFixed(1)} mm · '
          '${contour.loops} vueltas · ${contour.points} puntos',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${contour.lineCount} líneas · ${contour.passes} pasadas · '
          '${contour.tabs} pestañas · ${contour.tool.label}',
          style: theme.textTheme.bodySmall,
        ),
      ];
    }
    final ReliefResult? relief = state.reliefResult;
    if (relief != null) {
      return <Widget>[
        Text(
          'Tamaño: ${relief.widthMm.toStringAsFixed(1)} × '
          '${relief.heightMm.toStringAsFixed(1)} mm · '
          '${relief.columns}×${relief.rows} celdas',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${relief.lineCount} líneas · ${relief.levels} niveles · '
          'profundidad ${relief.maxDepthMm.toStringAsFixed(2)} mm · '
          '${(relief.cutRatio * 100).toStringAsFixed(0)} % fresado',
          style: theme.textTheme.bodySmall,
        ),
      ];
    }
    return const <Widget>[];
  }

  ReliefSettings get _reliefSettings => ReliefSettings(
    widthMm: _parse(_width, 80),
    pixelMm: _parse(_pixel, 1),
    levels: _parseCount(_levels).clamp(2, 16),
    maxDepthMm: _parse(_maxDepth, 3),
    passDepthMm: _parse(_passDepth, 0.5),
    rpm: _parse(_power, 8000).round(),
    feedMmMin: _parse(_feed, 600),
    safeZmm: _parseSigned(_safeZ, 2),
    invert: _invert,
  );

  ContourSettings get _contourSettings {
    final double cutZ = _parseSigned(_cutZ, -1);
    return ContourSettings(
      widthMm: _parse(_width, 80),
      pixelMm: _parse(_pixel, 0.5),
      threshold: _threshold,
      invert: _invert,
      tool: _contourTool,
      power: _parse(_power, 1000).round(),
      feedMmMin: _parse(_feed, 600),
      plungeMmMin: 200,
      safeZmm: _parseSigned(_safeZ, 2),
      cutZmm: cutZ < 0 ? cutZ : -1,
      passDepthMm: _parse(_passDepth, 0.5),
      tabs: _parseCount(_tabs),
      tabWidthMm: _parse(_tabWidth, 3),
      tabHeightMm: _parseSigned(_tabHeight, 0.8),
    );
  }

  EngravingSettings get _settings => EngravingSettings(
    widthMm: _parse(_width, 80),
    pixelMm: _parse(_pixel, 0.5),
    mode: _mode,
    threshold: _threshold,
    maxPower: _parse(_power, 1000).round(),
    feedMmMin: _parse(_feed, 1200),
    invert: _invert,
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
    ref.read(camControllerProvider.notifier).loadImage(bytes, file.name);
  }

  void _useProfileDefaults() {
    final MachineProfile? profile = ref.read(activeProfileProvider).value;
    if (profile == null) {
      return;
    }
    setState(() {
      _power.text = profile.maxSpindleRpm.toStringAsFixed(0);
      _feed.text = profile.defaultFeedMmMin.toStringAsFixed(0);
      _width.text = profile.travelXmm.clamp(5, 2000).toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final CamUiState state = ref.watch(camControllerProvider);
    final MachineProfile? profile = ref.watch(activeProfileProvider).value;
    final ThemeData theme = Theme.of(context);

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
                    'CAM · Imagen → G-code',
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
            Text(switch (state.operation) {
              CamOperation.engrave =>
                'Grabado: la imagen se convierte en potencia del láser '
                    '(M4), con umbral, tramado o escala de grises.',
              CamOperation.contour =>
                'Contorno: se vectoriza la silueta y se corta con pasadas '
                    'en Z y pestañas de sujeción.',
              CamOperation.relief =>
                'Relieve: mapa de altura por niveles, fresado con el husillo '
                    'hasta la profundidad de cada banda.',
            }, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            SegmentedButton<CamOperation>(
              segments: <ButtonSegment<CamOperation>>[
                for (final CamOperation operation in CamOperation.values)
                  ButtonSegment<CamOperation>(
                    value: operation,
                    label: Text(operation.label),
                  ),
              ],
              selected: <CamOperation>{state.operation},
              onSelectionChanged: (Set<CamOperation> selection) => ref
                  .read(camControllerProvider.notifier)
                  .setOperation(selection.first),
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
            if (profile != null &&
                !profile.usesLaserMode &&
                state.operation == CamOperation.engrave)
              _Notice(
                text:
                    'El perfil activo no es láser: el grabado por potencia '
                    'requiere M4. Crea un perfil con herramienta láser.',
                icon: Icons.warning_amber_rounded,
                color: theme.colorScheme.tertiary,
              ),
            const SizedBox(height: 8),
            _Panel(
              icon: Icons.image_outlined,
              title: 'Imagen',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    state.fileName ?? 'Sin imagen cargada',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: state.hasImage
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PNG, JPG o BMP. El ancho se define abajo; el alto sale de '
                    'la proporción de la imagen.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (state.operation == CamOperation.engrave)
              _Panel(
                icon: Icons.tune,
                title: 'Parámetros de grabado',
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
                        _Field(
                          label: 'Potencia S máx.',
                          controller: _power,
                          width: 130,
                          onChanged: () => setState(() {}),
                        ),
                        _Field(
                          label: 'Avance (mm/min)',
                          controller: _feed,
                          width: 140,
                          onChanged: () => setState(() {}),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Modo', style: theme.textTheme.labelSmall),
                            DropdownButton<EngravingMode>(
                              value: _mode,
                              items: <DropdownMenuItem<EngravingMode>>[
                                for (final EngravingMode mode
                                    in EngravingMode.values)
                                  DropdownMenuItem<EngravingMode>(
                                    value: mode,
                                    child: Text(mode.label),
                                  ),
                              ],
                              onChanged: (EngravingMode? mode) {
                                if (mode != null) {
                                  setState(() => _mode = mode);
                                }
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Invertir',
                              style: theme.textTheme.labelMedium,
                            ),
                            Switch(
                              value: _invert,
                              onChanged: (bool value) =>
                                  setState(() => _invert = value),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_mode == EngravingMode.threshold) ...<Widget>[
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
                          onChanged: (double value) =>
                              setState(() => _threshold = value),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (state.operation == CamOperation.contour) _contourPanel(theme),
            if (state.operation == CamOperation.relief) _reliefPanel(theme),
            const SizedBox(height: 16),
            _Panel(
              icon: Icons.play_circle_outline,
              title: 'Resultado',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!state.hasResult)
                    Text(
                      'Elige una imagen, ajusta los parámetros y pulsa '
                      '«Generar». La previsualización es obligatoria: el '
                      'trabajo se revisa en el visor antes de ejecutar.',
                      style: theme.textTheme.bodySmall,
                    )
                  else ...<Widget>[
                    _PathPreview(
                      png: state.previewPng!,
                      caption: switch (state.operation) {
                        CamOperation.engrave =>
                          'Resultado del grabado: 1 celda = 1 píxel · '
                              '${state.engraveResult!.columns} × '
                              '${state.engraveResult!.rows}',
                        CamOperation.contour =>
                          'Contorno vectorizado: 1 píxel = 1 celda',
                        CamOperation.relief =>
                          'Mapa de altura: oscuro = más profundo · '
                              '${state.reliefResult!.levels} niveles',
                      },
                    ),
                    const SizedBox(height: 12),
                    ..._resultSummary(state, theme),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: state.isBusy || !state.hasImage
                            ? null
                            : () {
                                final CamController controller = ref.read(
                                  camControllerProvider.notifier,
                                );
                                if (state.operation == CamOperation.engrave) {
                                  controller.generate(_settings);
                                } else if (state.operation ==
                                    CamOperation.contour) {
                                  controller.generateContour(_contourSettings);
                                } else {
                                  controller.generateRelief(_reliefSettings);
                                }
                              },
                        icon: state.isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(state.isBusy ? 'Generando…' : 'Generar'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: !state.hasResult
                            ? null
                            : () => ref
                                  .read(camControllerProvider.notifier)
                                  .sendToViewer(),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Enviar al visor'),
                      ),
                      if (state.hasImage)
                        TextButton.icon(
                          onPressed: () =>
                              ref.read(camControllerProvider.notifier).clear(),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Descartar'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
