import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../app/providers.dart';
import '../../domain/entities/gcode_program.dart';
import '../../domain/entities/machine_profile.dart';
import '../connection/connection_controller.dart';
import 'execution_controller.dart';
import 'viewer_controller.dart';
import 'widgets/execution_bar.dart';
import 'widgets/viewer_canvas.dart';

/// Visor de proyectos: carga G-code, lo simula en 3D y sigue la telemetría.
class ViewerPage extends ConsumerWidget {
  const ViewerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GlobalKey<ViewerCanvasState> canvasKey = ref.watch(
      viewerCanvasKeyProvider,
    );
    final ViewerUiState state = ref.watch(viewerControllerProvider);
    final ConnectionUiState connection = ref.watch(
      connectionControllerProvider,
    );
    final MachineProfile? profile = ref.watch(activeProfileProvider).value;
    final ThemeData theme = Theme.of(context);
    final ViewerController controller = ref.read(
      viewerControllerProvider.notifier,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Visor',
                    style: theme.textTheme.headlineMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openFile(context, ref),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Abrir archivo'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: controller.loadExample,
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: const Text('Ejemplo'),
                ),
                if (state.hasProgram) ...<Widget>[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cerrar programa',
                    onPressed: controller.clear,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            if (state.fileName != null)
              Text(state.fileName!, style: theme.textTheme.bodySmall),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  state.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (state.hasProgram) ...<Widget>[
              const SizedBox(height: 4),
              _ProgramStats(program: state.program!),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: state.hasProgram
                  ? Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: _canvas(
                            state.program!,
                            connection,
                            profile,
                            theme.colorScheme.outlineVariant,
                            ref.watch(executionControllerProvider).executedLine,
                            canvasKey,
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          right: 10,
                          child: ExecutionBar(
                            onFitView: () =>
                                canvasKey.currentState?.resetView(),
                          ),
                        ),
                      ],
                    )
                  : _emptyState(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _canvas(
    GcodeProgram program,
    ConnectionUiState connection,
    MachineProfile? profile,
    Color borderColor,
    int? executedLine,
    GlobalKey<ViewerCanvasState> canvasKey,
  ) {
    final List<double>? workPosition = connection.workPosition;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ViewerCanvas(
          key: canvasKey,
          program: program,
          executedUpToLine: executedLine,
          headPosition: workPosition != null && workPosition.length >= 3
              ? Vector3(workPosition[0], workPosition[1], workPosition[2])
              : null,
          workAreaMm: profile == null
              ? null
              : <double>[
                  profile.travelXmm,
                  profile.travelYmm,
                  profile.travelZmm,
                ],
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.view_in_ar_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Abre un archivo .gcode/.nc o carga el ejemplo para simularlo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Arrastra para desplazar, pellizca o usa la rueda para acercar '
              'y gira con dos dedos. Doble toque para restablecer la vista.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    try {
      const XTypeGroup group = XTypeGroup(
        label: 'G-code',
        extensions: <String>['gcode', 'nc', 'tap', 'txt'],
      );
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[group],
      );
      if (file == null) {
        return;
      }
      final String text = await file.readAsString();
      ref
          .read(viewerControllerProvider.notifier)
          .loadText(text, fileName: file.name);
    } on Object catch (error) {
      ref
          .read(viewerControllerProvider.notifier)
          .reportError('No se pudo abrir el archivo: $error');
    }
  }
}

/// Clave del lienzo: permite que la página centre el trazado con un botón.
final Provider<GlobalKey<ViewerCanvasState>> viewerCanvasKeyProvider =
    Provider<GlobalKey<ViewerCanvasState>>(
      (Ref ref) => GlobalKey<ViewerCanvasState>(),
    );

class _ProgramStats extends StatelessWidget {
  const _ProgramStats({required this.program});

  final GcodeProgram program;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        _stat('${program.blockCount} segmentos', theme),
        _stat('${program.arcCount} arcos', theme),
        _stat(
          '${program.cuttingLengthMm.toStringAsFixed(0)} mm de corte',
          theme,
        ),
        _stat(
          '${program.rapidLengthMm.toStringAsFixed(0)} mm en rápido',
          theme,
        ),
        if (program.warnings.isNotEmpty)
          Chip(
            avatar: Icon(
              Icons.warning_amber_outlined,
              size: 16,
              color: theme.colorScheme.error,
            ),
            label: Text('${program.warnings.length} avisos'),
            labelStyle: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }

  Widget _stat(String text, ThemeData theme) {
    return Chip(
      label: Text(text),
      labelStyle: theme.textTheme.labelSmall,
      visualDensity: VisualDensity.compact,
    );
  }
}
