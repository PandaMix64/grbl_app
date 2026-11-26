import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../domain/entities/gcode_program.dart';
import '../../../domain/entities/motion_segment.dart';
import '../../../domain/services/simulation_timeline.dart';
import '../program_painter.dart';
import '../preview_visibility.dart';
import '../simulation_controller.dart';
import '../simulation_painter.dart';
import '../view_projection.dart';

/// Lienzo interactivo: arrastrar desplaza, pellizcar/rueda acerca y girar rota.
///
/// La trayectoria y la estela del simulador viven en **dos capas** separadas: la
/// ruta se repinta solo al mover la vista y la estela se repinta por fotograma
/// sin recalcular la trayectoria.
class ViewerCanvas extends ConsumerStatefulWidget {
  const ViewerCanvas({
    required this.program,
    this.headPosition,
    this.executedUpToLine,
    this.workAreaMm,
    super.key,
  });

  final GcodeProgram program;
  final Vector3? headPosition;
  final int? executedUpToLine;
  final List<double>? workAreaMm;

  @override
  ConsumerState<ViewerCanvas> createState() => ViewerCanvasState();
}

/// Estado del lienzo, accesible desde la página para centrar el trazado.
class ViewerCanvasState extends ConsumerState<ViewerCanvas> {
  double _zoom = 1;
  Offset _pan = Offset.zero;
  double _yaw = -30;
  double _pitch = 25;

  double _zoomStart = 1;
  double _yawStart = -30;

  /// Proyección cacheada: puntos para la estela y lotes para la trayectoria.
  ///
  /// Se recalcula solo cuando cambia el programa, la vista o la línea ejecutada;
  /// mientras la simulación avanza, repintar cuesta O(1) (prefijo del búfer) en
  /// lugar de recorrer todos los segmentos en cada fotograma.
  Float32List? _projected;
  ProgramBatches? _batches;
  GcodeProgram? _cachedProgram;
  double _cachedScale = 0;
  double _cachedYaw = 0;
  double _cachedPitch = 0;
  double _cachedCenterX = 0;
  double _cachedCenterY = 0;
  double _cachedCenterZ = 0;
  int? _cachedExecutedLine;

  /// Devuelve la vista a encuadre inicial (zoom, paneo y giro).
  void resetView() {
    setState(() {
      _zoom = 1;
      _pan = Offset.zero;
      _yaw = -30;
      _pitch = 25;
    });
  }

  @override
  void didUpdateWidget(covariant ViewerCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Un programa nuevo debe encuadrarse solo: si no, el paneo anterior deja el
    // trazado fuera del viewport y la vista parece «atorada».
    if (!identical(oldWidget.program, widget.program)) {
      _zoom = 1;
      _pan = Offset.zero;
      _yaw = -30;
      _pitch = 25;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomStart = _zoom;
    _yawStart = _yaw;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _zoom = (_zoomStart * details.scale).clamp(0.15, 12.0);
      _pan += details.focalPointDelta;
      if (details.rotation.abs() > 0.001) {
        _yaw = _yawStart + details.rotation * 180 / math.pi;
      }
    });
  }

  void _resetView() => resetView();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GcodeProgram program = widget.program;
    final SimulationCursor? cursor = ref.watch(
      simulationControllerProvider.select(
        (SimulationUiState state) => state.cursor,
      ),
    );
    final PreviewVisibility visibility = ref.watch(previewVisibilityProvider);
    // Solo se desactiva la caché de ráster mientras hay animación en marcha.
    final bool simulating = ref.watch(
      simulationControllerProvider.select(
        (SimulationUiState state) => state.playing,
      ),
    );

    final Vector3 center = _center(program);
    final Vector3 size = _size(program);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final double fit = ViewProjection.fitScale(
          size: size,
          viewport: viewport,
          yawDegrees: _yaw,
          pitchDegrees: _pitch,
        );
        final ViewProjection projection = ViewProjection(
          center: center,
          scale: fit * _zoom,
          yawDegrees: _yaw,
          pitchDegrees: _pitch,
        );
        final int? executedLine = visibility.showExecution
            ? widget.executedUpToLine
            : null;
        _ensureProjection(program, projection, executedLine);
        final SimulationTrail? trail = visibility.showSimulation
            ? _trail(program, projection, cursor)
            : null;

        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onDoubleTap: _resetView,
          child: Transform.translate(
            offset: _pan,
            // Trayectoria y estela comparten `CustomPaint` (painter y
            // `foregroundPainter`): mismo tamaño, misma proyección y mismo
            // origen, así la simulación cae exactamente sobre el recorrido.
            child: RepaintBoundary(
              child: CustomPaint(
                key: const Key('viewer-canvas'),
                size: viewport,
                isComplex: true,
                willChange: simulating,
                painter: ProgramPainter(
                  program: program,
                  projection: projection,
                  colorScheme: theme.colorScheme,
                  batches: _batches,
                  headPosition: visibility.showExecution
                      ? widget.headPosition
                      : null,
                  executedUpToLine: executedLine,
                  workAreaMm: widget.workAreaMm,
                  gridStepMm: _gridStep(size),
                ),
                foregroundPainter: trail == null
                    ? null
                    : SimulationPainter(
                        trail: trail,
                        color: theme.colorScheme.tertiary,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Estela hasta el cabezal simulado, en coordenadas de pantalla.
  SimulationTrail? _trail(
    GcodeProgram program,
    ViewProjection projection,
    SimulationCursor? cursor,
  ) {
    final Float32List? points = _projected;
    if (points == null || program.segments.isEmpty) {
      return null;
    }
    if (cursor == null) {
      return SimulationTrail(points: points, segmentsDone: 0);
    }
    final int index = cursor.segmentIndex.clamp(0, program.segments.length - 1);
    final MotionSegment segment = program.segments[index];
    final Vector2 start = projection.project(segment.start);
    final Vector2 head = projection.project(cursor.position);
    return SimulationTrail(
      points: points,
      segmentsDone: index,
      partialStart: Offset(start.x, start.y),
      head: Offset(head.x, head.y),
    );
  }

  /// Proyecta el programa una sola vez por vista: búfer plano para la estela
  /// (`ax, ay, bx, by` por segmento) y lotes por categoría para la trayectoria.
  void _ensureProjection(
    GcodeProgram program,
    ViewProjection projection,
    int? executedLine,
  ) {
    final bool cached =
        _projected != null &&
        _batches != null &&
        identical(_cachedProgram, program) &&
        _cachedScale == projection.scale &&
        _cachedYaw == projection.yawDegrees &&
        _cachedPitch == projection.pitchDegrees &&
        _cachedCenterX == projection.center.x &&
        _cachedCenterY == projection.center.y &&
        _cachedCenterZ == projection.center.z &&
        _cachedExecutedLine == executedLine;
    if (cached) {
      return;
    }

    final List<MotionSegment> segments = program.segments;
    final Float32List points = Float32List(segments.length * 4);
    final List<double> rapid = <double>[];
    final List<double> cutting = <double>[];
    final List<double> executed = <double>[];

    for (int i = 0; i < segments.length; i++) {
      final MotionSegment segment = segments[i];
      final Vector2 a = projection.project(segment.start);
      final Vector2 b = projection.project(segment.end);
      final int offset = i * 4;
      points[offset] = a.x;
      points[offset + 1] = a.y;
      points[offset + 2] = b.x;
      points[offset + 3] = b.y;

      final bool done =
          executedLine != null && program.lineIndexes[i] <= executedLine;
      final List<double> target = done
          ? executed
          : (segment.rapid ? rapid : cutting);
      target
        ..add(a.x)
        ..add(a.y)
        ..add(b.x)
        ..add(b.y);
    }

    _projected = points;
    _batches = ProgramBatches(
      rapid: Float32List.fromList(rapid),
      cutting: Float32List.fromList(cutting),
      executed: Float32List.fromList(executed),
    );
    _cachedProgram = program;
    _cachedScale = projection.scale;
    _cachedYaw = projection.yawDegrees;
    _cachedPitch = projection.pitchDegrees;
    _cachedCenterX = projection.center.x;
    _cachedCenterY = projection.center.y;
    _cachedCenterZ = projection.center.z;
    _cachedExecutedLine = executedLine;
  }

  /// Centro del encuadre: la **unión** de la trayectoria y el volumen de trabajo.
  ///
  /// Si solo se encuadrara el programa, la cama (dibujada en coordenadas
  /// absolutas) aparecía lejos y parecía que la simulación flotaba en otro sitio.
  /// Compartiendo encuadre, programa y cama están siempre en el mismo sistema de
  /// referencia.
  Vector3 _center(GcodeProgram program) {
    final ({Vector3 min, Vector3 max}) frame = _frame(program);
    return (frame.min + frame.max) * 0.5;
  }

  Vector3 _size(GcodeProgram program) {
    final ({Vector3 min, Vector3 max}) frame = _frame(program);
    final Vector3 size = frame.max - frame.min;
    return Vector3(
      math.max(size.x, 10),
      math.max(size.y, 10),
      math.max(size.z, 5),
    );
  }

  ({Vector3 min, Vector3 max}) _frame(GcodeProgram program) {
    Vector3 min = program.min ?? Vector3.zero();
    Vector3 max = program.max ?? Vector3.zero();
    final List<double>? area = widget.workAreaMm;
    if (area != null && area.length >= 2) {
      final double volumeZ = area.length > 2 ? area[2] : 0;
      min = Vector3(math.min(min.x, 0), math.min(min.y, 0), math.min(min.z, 0));
      max = Vector3(
        math.max(max.x, area[0]),
        math.max(max.y, area[1]),
        math.max(max.z, volumeZ),
      );
    }
    return (min: min, max: max);
  }

  double _gridStep(Vector3 size) {
    final double largest = math.max(size.x, size.y);
    if (largest > 400) {
      return 50;
    }
    if (largest > 150) {
      return 20;
    }
    return 10;
  }
}
