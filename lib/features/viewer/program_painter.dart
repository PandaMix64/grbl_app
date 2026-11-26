import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../domain/entities/gcode_program.dart';
import '../../domain/entities/motion_segment.dart';
import 'view_projection.dart';

/// Trayectoria ya proyectada y repartida en lotes de dibujo.
///
/// Se construye una vez por programa/vista (y por línea ejecutada) para que
/// repintar sea solo enviar tres búferes: sin recorrer segmentos ni asignar
/// listas en cada fotograma.
class ProgramBatches {
  const ProgramBatches({
    required this.rapid,
    required this.cutting,
    required this.executed,
  });

  /// Pares de puntos (inicio, fin) en pantalla por cada rápido `G0`.
  final Float32List rapid;

  /// Pares de puntos de mecanizado (`G1` y arcos) pendientes de ejecutar.
  final Float32List cutting;

  /// Pares de puntos ya ejecutados por la máquina.
  final Float32List executed;

  bool get isEmpty => rapid.isEmpty && cutting.isEmpty && executed.isEmpty;
}

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
    this.batches,
    this.headPosition,
    this.executedUpToLine,
    this.workAreaMm,
    this.gridStepMm = 0,
  });

  final GcodeProgram program;
  final ViewProjection projection;
  final ColorScheme colorScheme;

  /// Lotes precalculados (los aporta el lienzo desde su caché).
  ///
  /// Si llegan `null` se calculan al pintar: cómodo para pruebas y para usos
  /// sueltos, pero el visor siempre los pasa cacheados.
  final ProgramBatches? batches;

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

    final ProgramBatches resolved =
        batches ??
        buildBatches(
          program: program,
          projection: projection,
          executedUpToLine: executedUpToLine,
        );
    _drawBatch(canvas, rapidPaint, resolved.rapid);
    _drawBatch(canvas, cuttingPaint, resolved.cutting);
    _drawBatch(canvas, executedPaint, resolved.executed);

    if (headPosition != null) {
      _drawHead(canvas, headPosition!);
    }
    canvas.restore();
  }

  /// Proyecta el programa en tres lotes (rápido, pendiente y ejecutado).
  ///
  /// Es O(n) sobre los segmentos: el lienzo lo cachea y solo lo repite cuando
  /// cambia el programa, la vista o la línea ejecutada.
  static ProgramBatches buildBatches({
    required GcodeProgram program,
    required ViewProjection projection,
    int? executedUpToLine,
  }) {
    final List<double> rapid = <double>[];
    final List<double> cutting = <double>[];
    final List<double> executed = <double>[];

    for (int i = 0; i < program.segments.length; i++) {
      final MotionSegment segment = program.segments[i];
      final Vector2 a = projection.project(segment.start);
      final Vector2 b = projection.project(segment.end);
      final bool done =
          executedUpToLine != null &&
          program.lineIndexes[i] <= executedUpToLine;
      final List<double> target = done
          ? executed
          : (segment.rapid ? rapid : cutting);
      target
        ..add(a.x)
        ..add(a.y)
        ..add(b.x)
        ..add(b.y);
    }
    return ProgramBatches(
      rapid: Float32List.fromList(rapid),
      cutting: Float32List.fromList(cutting),
      executed: Float32List.fromList(executed),
    );
  }

  void _drawBatch(Canvas canvas, Paint paint, Float32List data) {
    if (data.isEmpty) {
      return;
    }
    canvas.drawRawPoints(PointMode.lines, data, paint);
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
        !identical(oldDelegate.batches, batches) ||
        oldDelegate.projection.center != projection.center ||
        oldDelegate.projection.scale != projection.scale ||
        oldDelegate.projection.yawDegrees != projection.yawDegrees ||
        oldDelegate.projection.pitchDegrees != projection.pitchDegrees ||
        oldDelegate.headPosition != headPosition ||
        oldDelegate.executedUpToLine != executedUpToLine ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.workAreaMm != workAreaMm ||
        oldDelegate.gridStepMm != gridStepMm;
  }
}
