import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/services/engraving_generator.dart';
import 'cam_controller.dart';

/// Vista previa del grabado: una celda por píxel, tal y como quedará el material.
class _EngravingPreview extends StatelessWidget {
  const _EngravingPreview({required this.result});

  final EngravingResult result;

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
              // Fondo claro: el grabado se ve como sobre la pieza.
              color: const Color(0xFFF5F2EA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Image.memory(
              result.previewPng,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              gaplessPlayback: true,
              semanticLabel: 'Vista previa del grabado',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Vista previa del resultado: 1 celda = 1 píxel · '
            '${result.columns} × ${result.rows}',
            style: theme.textTheme.labelSmall,
          ),
        ),
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

  EngravingMode _mode = EngravingMode.threshold;
  double _threshold = 0.5;
  bool _invert = false;

  @override
  void dispose() {
    _width.dispose();
    _pixel.dispose();
    _power.dispose();
    _feed.dispose();
    super.dispose();
  }

  static double _parse(TextEditingController controller, double fallback) {
    final double? value = double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    );
    return value == null || value <= 0 ? fallback : value;
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
                    'CAM · Grabado láser',
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
              'La imagen se convierte en potencia del láser (M4). El alto se '
              'calcula por proporción y el resultado se revisa en el visor '
              'antes de ejecutar.',
              style: theme.textTheme.bodySmall,
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
            if (profile != null && !profile.usesLaserMode)
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
                          Text('Invertir', style: theme.textTheme.labelMedium),
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
            const SizedBox(height: 16),
            _Panel(
              icon: Icons.play_circle_outline,
              title: 'Resultado',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (state.result == null)
                    Text(
                      'Elige una imagen, ajusta los parámetros y pulsa '
                      '«Generar». La previsualización es obligatoria: el '
                      'trabajo se revisa en el visor antes de ejecutar.',
                      style: theme.textTheme.bodySmall,
                    )
                  else ...<Widget>[
                    _EngravingPreview(result: state.result!),
                    const SizedBox(height: 12),
                    Text(
                      'Tamaño: '
                      '${state.result!.widthMm.toStringAsFixed(1)} × '
                      '${state.result!.heightMm.toStringAsFixed(1)} mm · '
                      '${state.result!.columns}×${state.result!.rows} celdas',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.result!.lineCount} líneas · '
                      '${(state.result!.litRatio * 100).toStringAsFixed(0)} % '
                      'grabado · ${state.result!.mode.label} · S máx. '
                      '${state.result!.maxPower}',
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
                                  .read(camControllerProvider.notifier)
                                  .generate(_settings),
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
                        onPressed: state.result == null
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
