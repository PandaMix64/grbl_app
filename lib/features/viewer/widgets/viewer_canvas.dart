import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../domain/entities/gcode_program.dart';
import '../../../domain/entities/motion_segment.dart';
import '../../../domain/services/simulation_timeline.dart';
import '../program_painter.dart';
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

  /// Búfer proyectado de toda la trayectoria (4 flotantes por segmento) y la
  /// proyección con la que se construyó. Se reutiliza mientras no cambie ni el
  /// programa ni la vista, así que la estela del simulador se dibuja sin recorrer
  /// los segmentos en cada fotograma.
  Float32List? _projected;
  GcodeProgram? _projectedProgram;
  double _projectedScale = 0;
  double _projectedYaw = 0;
  double _projectedPitch = 0;
  double _projectedCenterX = 0;
  double _projectedCenterY = 0;
  double _projectedCenterZ = 0;

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

        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onDoubleTap: _resetView,
          child: Transform.translate(
            offset: _pan,
            child: SizedBox(
              width: viewport.width,
              height: viewport.height,
              child: Stack(
                children: <Widget>[
                  // La pintura solo depende de la proyección: al panear se mueve
                  // la capa sin repintar los lotes de segmentos.
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const Key('viewer-canvas'),
                        isComplex: true,
                        willChange: false,
                        painter: ProgramPainter(
                          program: program,
                          projection: projection,
                          colorScheme: theme.colorScheme,
                          headPosition: widget.headPosition,
                          executedUpToLine: widget.executedUpToLine,
                          workAreaMm: widget.workAreaMm,
                          gridStepMm: _gridStep(size),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const Key('viewer-simulation'),
                        willChange: true,
                        painter: SimulationPainter(
                          trail: _trail(program, projection, cursor),
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Estela hasta el cabezal simulado, en coordenadas de pantalla.
  SimulationTrail _trail(
    GcodeProgram program,
    ViewProjection projection,
    SimulationCursor? cursor,
  ) {
    final Float32List points = _projectedPoints(program, projection);
    if (cursor == null || program.segments.isEmpty) {
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

  /// Búfer plano `[ax, ay, bx, by]` por segmento; recalculado solo si cambia el
  /// programa o la vista.
  Float32List _projectedPoints(
    GcodeProgram program,
    ViewProjection projection,
  ) {
    final Float32List? cached = _projected;
    if (cached != null &&
        identical(_projectedProgram, program) &&
        _projectedScale == projection.scale &&
        _projectedYaw == projection.yawDegrees &&
        _projectedPitch == projection.pitchDegrees &&
        _projectedCenterX == projection.center.x &&
        _projectedCenterY == projection.center.y &&
        _projectedCenterZ == projection.center.z) {
      return cached;
    }
    final List<MotionSegment> segments = program.segments;
    final Float32List points = Float32List(segments.length * 4);
    for (int i = 0; i < segments.length; i++) {
      final MotionSegment segment = segments[i];
      final Vector2 a = projection.project(segment.start);
      final Vector2 b = projection.project(segment.end);
      final int offset = i * 4;
      points[offset] = a.x;
      points[offset + 1] = a.y;
      points[offset + 2] = b.x;
      points[offset + 3] = b.y;
    }
    _projected = points;
    _projectedProgram = program;
    _projectedScale = projection.scale;
    _projectedYaw = projection.yawDegrees;
    _projectedPitch = projection.pitchDegrees;
    _projectedCenterX = projection.center.x;
    _projectedCenterY = projection.center.y;
    _projectedCenterZ = projection.center.z;
    return points;
  }

  Vector3 _center(GcodeProgram program) {
    final Vector3? min = program.min;
    final Vector3? max = program.max;
    if (min == null || max == null) {
      return Vector3.zero();
    }
    return (min + max) * 0.5;
  }

  Vector3 _size(GcodeProgram program) {
    final Vector3? min = program.min;
    final Vector3? max = program.max;
    if (min == null || max == null) {
      return Vector3(100, 100, 10);
    }
    final Vector3 size = max - min;
    return Vector3(
      math.max(size.x, 10),
      math.max(size.y, 10),
      math.max(size.z, 5),
    );
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
