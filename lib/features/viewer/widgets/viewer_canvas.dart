import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../domain/entities/gcode_program.dart';
import '../program_painter.dart';
import '../view_projection.dart';

/// Lienzo interactivo: arrastrar desplaza, pellizcar/rueda acerca y girar rota.
class ViewerCanvas extends StatefulWidget {
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
  State<ViewerCanvas> createState() => ViewerCanvasState();
}

/// Estado del lienzo, accesible desde la página para centrar el trazado.
class ViewerCanvasState extends State<ViewerCanvas> {
  double _zoom = 1;
  Offset _pan = Offset.zero;
  double _yaw = -30;
  double _pitch = 25;

  double _zoomStart = 1;
  double _yawStart = -30;

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
            // La pintura solo depende de la proyección: al panear se mueve la
            // capa sin repintar los lotes de segmentos.
            child: RepaintBoundary(
              child: CustomPaint(
                key: const Key('viewer-canvas'),
                size: viewport,
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
        );
      },
    );
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
