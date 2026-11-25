import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../domain/entities/gcode_program.dart';
import '../../domain/entities/motion_segment.dart';
import 'view_projection.dart';

/// Dibuja la trayectoria en tres lotes (`drawRawPoints`).
///
/// Un lote por categoría evita cambiar de `Paint` por segmento: rápido,
/// pendiente de ejecutar y ya ejecutado. Los búferes se construyen en una sola
/// pasada sobre los segmentos y se envían como `PointMode.lines`.
class ProgramPainter extends CustomPainter {
  ProgramPainter({
    required this.program,
    required this.projection,
    required this.colorScheme,
    this.headPosition,
    this.executedUpToLine,
    this.workAreaMm,
    this.gridStepMm = 0,
  });

  final GcodeProgram program;
  final ViewProjection projection;
  final ColorScheme colorScheme;

  /// Posición actual de la máquina (mm), si hay telemetría.
  final Vector3? headPosition;

  /// Última línea ejecutada; los segmentos hasta ella se pintan como ejecutados.
  final int? executedUpToLine;

  /// Volumen de trabajo del perfil (X, Y, Z) en mm.
  final List<double>? workAreaMm;

  /// Separación de la rejilla del plano; 0 la desactiva.
  final double gridStepMm;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset origin = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);

    if (gridStepMm > 0 && workAreaMm != null) {
      _drawGrid(canvas);
    }
    if (workAreaMm != null) {
      _drawVolume(canvas);
    }

    final Paint rapidPaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final Paint cuttingPaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 1.4;
    final Paint executedPaint = Paint()
      ..color = colorScheme.tertiary
      ..strokeWidth = 1.8;

    final _Batches batches = _batches();
    _drawBatch(canvas, rapidPaint, batches.rapid);
    _drawBatch(canvas, cuttingPaint, batches.cutting);
    _drawBatch(canvas, executedPaint, batches.executed);

    if (headPosition != null) {
      _drawHead(canvas, headPosition!);
    }
    canvas.restore();
  }

  _Batches _batches() {
    final List<double> rapid = <double>[];
    final List<double> cutting = <double>[];
    final List<double> executed = <double>[];
    final int? executedLine = executedUpToLine;

    for (int i = 0; i < program.segments.length; i++) {
      final MotionSegment segment = program.segments[i];
      final Vector2 a = projection.project(segment.start);
      final Vector2 b = projection.project(segment.end);
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
    return _Batches(rapid: rapid, cutting: cutting, executed: executed);
  }

  void _drawBatch(Canvas canvas, Paint paint, List<double> data) {
    if (data.isEmpty) {
      return;
    }
    canvas.drawRawPoints(PointMode.lines, Float32List.fromList(data), paint);
  }

  void _drawVolume(Canvas canvas) {
    final List<double> area = workAreaMm!;
    if (area.length < 2) {
      return;
    }
    final Paint paint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final double w = area[0];
    final double h = area[1];
    final double z = area.length > 2 ? area[2] : 0;

    for (final double height in <double>[0, z]) {
      final Path path = Path();
      final List<Vector3> corners = <Vector3>[
        Vector3(0, 0, height),
        Vector3(w, 0, height),
        Vector3(w, h, height),
        Vector3(0, h, height),
        Vector3(0, 0, height),
      ];
      for (int i = 0; i < corners.length; i++) {
        final Vector2 p = projection.project(corners[i]);
        if (i == 0) {
          path.moveTo(p.x, p.y);
        } else {
          path.lineTo(p.x, p.y);
        }
      }
      canvas.drawPath(path, paint);
    }

    for (final Vector3 corner in <Vector3>[
      Vector3(0, 0, 0),
      Vector3(w, 0, 0),
      Vector3(w, h, 0),
      Vector3(0, h, 0),
    ]) {
      final Vector2 bottom = projection.project(corner);
      final Vector2 upper = projection.project(Vector3(corner.x, corner.y, z));
      canvas.drawLine(
        Offset(bottom.x, bottom.y),
        Offset(upper.x, upper.y),
        paint,
      );
    }
  }

  void _drawGrid(Canvas canvas) {
    final List<double> area = workAreaMm!;
    final double w = area[0];
    final double h = area[1];
    final Paint paint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;
    for (double gx = 0; gx <= w; gx += gridStepMm) {
      final Vector2 a = projection.project(Vector3(gx, 0, 0));
      final Vector2 b = projection.project(Vector3(gx, h, 0));
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
    }
    for (double gy = 0; gy <= h; gy += gridStepMm) {
      final Vector2 a = projection.project(Vector3(0, gy, 0));
      final Vector2 b = projection.project(Vector3(w, gy, 0));
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
    }
  }

  void _drawHead(Canvas canvas, Vector3 position) {
    final Vector2 p = projection.project(position);
    canvas.drawCircle(Offset(p.x, p.y), 5, Paint()..color = colorScheme.error);
    canvas.drawCircle(
      Offset(p.x, p.y),
      10,
      Paint()
        ..color = colorScheme.error.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(ProgramPainter oldDelegate) {
    return !identical(oldDelegate.program, program) ||
        oldDelegate.projection.center != projection.center ||
        oldDelegate.projection.scale != projection.scale ||
        oldDelegate.projection.yawDegrees != projection.yawDegrees ||
        oldDelegate.projection.pitchDegrees != projection.pitchDegrees ||
        oldDelegate.headPosition != headPosition ||
        oldDelegate.executedUpToLine != executedUpToLine ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.workAreaMm != workAreaMm;
  }
}

/// Búferes de puntos por lote (pares inicio/fin en `PointMode.lines`).
class _Batches {
  const _Batches({
    required this.rapid,
    required this.cutting,
    required this.executed,
  });

  final List<double> rapid;
  final List<double> cutting;
  final List<double> executed;
}
