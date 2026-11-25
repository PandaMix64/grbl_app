import 'package:vector_math/vector_math_64.dart';

/// Traza los contornos de una rejilla binaria y los simplifica.
///
/// Se comparte entre el CAM de contornos y el trazado con plóter: ambos parten
/// de una silueta y necesitan polígonos mecanizables.
class ContourTracer {
  const ContourTracer();

  /// Bordes de la rejilla enlazados en bucles cerrados (con las islas internas).
  ///
  /// Se recorren las aristas de cada píxel interior que da al exterior y se
  /// encadenan por sus vértices: el resultado es una escalera por píxel que luego
  /// se simplifica.
  List<List<Vector2>> trace(List<List<bool>> inside) {
    final int rows = inside.length;
    final int cols = inside.isEmpty ? 0 : inside.first.length;
    final int stride = cols + 2;
    int key(int x, int y) => y * stride + x;

    final Map<int, List<int>> outgoing = <int, List<int>>{};
    void add(int x1, int y1, int x2, int y2) {
      outgoing.putIfAbsent(key(x1, y1), () => <int>[]).add(key(x2, y2));
    }

    bool filled(int x, int y) =>
        x >= 0 && y >= 0 && x < cols && y < rows && inside[y][x];

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (!inside[y][x]) {
          continue;
        }
        if (!filled(x, y - 1)) {
          add(x, y, x + 1, y);
        }
        if (!filled(x + 1, y)) {
          add(x + 1, y, x + 1, y + 1);
        }
        if (!filled(x, y + 1)) {
          add(x + 1, y + 1, x, y + 1);
        }
        if (!filled(x - 1, y)) {
          add(x, y + 1, x, y);
        }
      }
    }

    final List<List<Vector2>> loops = <List<Vector2>>[];
    for (final int start in outgoing.keys.toList()) {
      final List<int>? startEdges = outgoing[start];
      while (startEdges != null && startEdges.isNotEmpty) {
        final List<Vector2> loop = <Vector2>[];
        int current = start;
        int guard = 0;
        while (guard++ < 4000000) {
          final List<int>? nexts = outgoing[current];
          if (nexts == null || nexts.isEmpty) {
            break;
          }
          final int next = nexts.removeAt(0);
          loop.add(
            Vector2(
              (current % stride).toDouble(),
              (current ~/ stride).toDouble(),
            ),
          );
          if (next == start) {
            break;
          }
          current = next;
        }
        if (loop.length >= 4) {
          loops.add(loop);
        }
      }
    }
    return loops;
  }

  /// Quita vértices colineales y aplica Douglas–Peucker sobre el bucle cerrado.
  List<Vector2> simplify(List<Vector2> loop, double epsilonPx) {
    final List<Vector2> collinear = <Vector2>[];
    for (int i = 0; i < loop.length; i++) {
      final Vector2 previous = loop[(i - 1 + loop.length) % loop.length];
      final Vector2 current = loop[i];
      final Vector2 next = loop[(i + 1) % loop.length];
      final double cross =
          (current.x - previous.x) * (next.y - current.y) -
          (current.y - previous.y) * (next.x - current.x);
      if (cross.abs() > 1e-9) {
        collinear.add(current);
      }
    }
    if (collinear.length < 4 || epsilonPx <= 0) {
      return collinear;
    }
    final List<Vector2> open = <Vector2>[...collinear, collinear.first];
    final List<Vector2> reduced = _rdp(open, epsilonPx);
    if (reduced.length < 4) {
      return collinear;
    }
    return reduced.sublist(0, reduced.length - 1);
  }

  /// Douglas–Peucker iterativo (evita recursión profunda en contornos largos).
  List<Vector2> _rdp(List<Vector2> points, double epsilon) {
    final int count = points.length;
    if (count < 3) {
      return points;
    }
    final List<bool> keep = List<bool>.filled(count, false);
    keep[0] = true;
    keep[count - 1] = true;
    final List<List<int>> stack = <List<int>>[
      <int>[0, count - 1],
    ];
    while (stack.isNotEmpty) {
      final List<int> range = stack.removeLast();
      final int first = range[0];
      final int last = range[1];
      if (last - first < 2) {
        continue;
      }
      double maxDistance = 0;
      int index = -1;
      for (int i = first + 1; i < last; i++) {
        final double distance = distanceToSegment(
          points[i],
          points[first],
          points[last],
        );
        if (distance > maxDistance) {
          maxDistance = distance;
          index = i;
        }
      }
      if (index != -1 && maxDistance > epsilon) {
        keep[index] = true;
        stack
          ..add(<int>[first, index])
          ..add(<int>[index, last]);
      }
    }
    return <Vector2>[
      for (int i = 0; i < count; i++)
        if (keep[i]) points[i],
    ];
  }

  static double distanceToSegment(Vector2 point, Vector2 a, Vector2 b) {
    final double dx = b.x - a.x;
    final double dy = b.y - a.y;
    final double lengthSquared = dx * dx + dy * dy;
    if (lengthSquared <= 1e-12) {
      return (point - a).length;
    }
    double t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    final Vector2 projection = Vector2(a.x + t * dx, a.y + t * dy);
    return (point - projection).length;
  }
}
