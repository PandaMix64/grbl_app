import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:material_ui/material_ui.dart';

/// Estela del simulador ya proyectada a pantalla.
///
/// [points] es un búfer plano con cuatro flotantes por segmento (`ax, ay, bx,
/// by`), de modo que la estela de un instante cualquiera es un **prefijo** del
/// búfer y se puede dibujar con una vista sin copiar ni recorrer la trayectoria:
/// repintar cada fotograma cuesta O(1).
class SimulationTrail {
  const SimulationTrail({
    required this.points,
    required this.segmentsDone,
    this.partialStart,
    this.head,
  });

  final Float32List points;

  /// Segmentos ya reproducidos por completo (índice del bloque actual).
  final int segmentsDone;

  /// Inicio del bloque en curso, para trazar el tramo parcial.
  final Offset? partialStart;

  /// Cabezal simulado en pantalla.
  final Offset? head;
}

/// Dibuja la estela reproducida y el cabezal simulado sobre la trayectoria.
///
/// Vive en su propia capa (`CustomPaint` + `RepaintBoundary`): la ruta completa
/// se pinta aparte y no se recalcula mientras el simulador avanza.
class SimulationPainter extends CustomPainter {
  SimulationPainter({required this.trail, required this.color});

  final SimulationTrail trail;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset? head = trail.head;
    if (head == null) {
      return;
    }
    final Paint stroke = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.6;

    final int available = trail.points.length ~/ 4;
    final int done = trail.segmentsDone.clamp(0, available);
    if (done > 0) {
      canvas.drawRawPoints(
        PointMode.lines,
        Float32List.view(trail.points.buffer, 0, done * 4),
        stroke,
      );
    }
    final Offset? start = trail.partialStart;
    if (start != null && (start - head).distance > 0.4) {
      canvas.drawLine(start, head, stroke);
    }

    canvas.drawCircle(head, 5, Paint()..color = color);
    canvas.drawCircle(
      head,
      10,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(SimulationPainter oldDelegate) {
    return !identical(oldDelegate.trail.points, trail.points) ||
        oldDelegate.trail.segmentsDone != trail.segmentsDone ||
        oldDelegate.trail.partialStart != trail.partialStart ||
        oldDelegate.trail.head != trail.head ||
        oldDelegate.color != color;
  }
}
