import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:vector_math/vector_math_64.dart';

/// Herramienta que ejecuta el contorno.
enum ContourTool {
  laser,
  spindle;

  bool get isLaser => this == ContourTool.laser;

  String get label => switch (this) {
    ContourTool.laser => 'Láser (M4)',
    ContourTool.spindle => 'Husillo (M3)',
  };
}

/// Parámetros del corte/contorno.
class ContourSettings {
  const ContourSettings({
    this.widthMm = 80,
    this.pixelMm = 0.5,
    this.threshold = 0.5,
    this.invert = false,
    this.tool = ContourTool.laser,
    this.power = 1000,
    this.feedMmMin = 600,
    this.plungeMmMin = 200,
    this.safeZmm = 2,
    this.cutZmm = -1,
    this.passDepthMm = 0.5,
    this.simplifyMm = 0.2,
    this.tabs = 0,
    this.tabWidthMm = 3,
    this.tabHeightMm = 0.8,
    this.originXmm = 0,
    this.originYmm = 0,
  });

  final double widthMm;

  /// Resolución de muestreo de la silueta.
  final double pixelMm;
  final double threshold;
  final bool invert;
  final ContourTool tool;

  /// Potencia (`S`) para láser o RPM para husillo.
  final int power;
  final double feedMmMin;
  final double plungeMmMin;
  final double safeZmm;

  /// Profundidad final (negativa).
  final double cutZmm;

  /// Profundidad por pasada (positiva).
  final double passDepthMm;

  /// Tolerancia de simplificación de los polígonos.
  final double simplifyMm;

  /// Pestañas por contorno (0 = sin pestañas).
  final int tabs;
  final double tabWidthMm;

  /// Altura de la pestaña sobre el fondo del corte.
  final double tabHeightMm;

  final double originXmm;
  final double originYmm;

  List<String> validate() {
    final List<String> errors = <String>[];
    if (widthMm < 5 || widthMm > 2000) {
      errors.add('El ancho debe estar entre 5 y 2000 mm.');
    }
    if (pixelMm < 0.05 || pixelMm > 5) {
      errors.add('La resolución debe estar entre 0.05 y 5 mm por celda.');
    }
    if (threshold < 0 || threshold > 1) {
      errors.add('El umbral debe estar entre 0 y 1.');
    }
    if (power < 1 || power > 30000) {
      errors.add('La potencia/RPM debe estar entre 1 y 30000.');
    }
    if (feedMmMin < 1 || feedMmMin > 20000) {
      errors.add('El avance debe estar entre 1 y 20000 mm/min.');
    }
    if (plungeMmMin < 1 || plungeMmMin > 10000) {
      errors.add('La entrada en Z debe estar entre 1 y 10000 mm/min.');
    }
    if (safeZmm < 0 || safeZmm > 100) {
      errors.add('La altura segura debe estar entre 0 y 100 mm.');
    }
    if (cutZmm >= 0) {
      errors.add('La profundidad de corte debe ser negativa.');
    }
    if (passDepthMm <= 0 || passDepthMm > 20) {
      errors.add('La profundidad por pasada debe estar entre 0 y 20 mm.');
    }
    if (!tool.isLaser && passDepthMm < cutZmm.abs() / 200) {
      errors.add('Demasiadas pasadas: reduce la profundidad o auméntala.');
    }
    if (simplifyMm < 0 || simplifyMm > 5) {
      errors.add('La tolerancia de simplificación debe estar entre 0 y 5 mm.');
    }
    if (tabs < 0 || tabs > 20) {
      errors.add('Las pestañas deben ser entre 0 y 20 por contorno.');
    }
    if (tabWidthMm < 0.5 || tabWidthMm > 20) {
      errors.add('El ancho de pestaña debe estar entre 0.5 y 20 mm.');
    }
    if (tabHeightMm < 0 || tabHeightMm > 10) {
      errors.add('La altura de pestaña debe estar entre 0 y 10 mm.');
    }
    return errors;
  }
}

/// Entrada del generador de contornos.
class ContourJob {
  const ContourJob({required this.bytes, required this.settings});

  final Uint8List bytes;
  final ContourSettings settings;
}

/// Resultado del contorno: G-code, estadísticas y vista previa vectorial.
class ContourResult {
  const ContourResult({
    required this.gcode,
    required this.loops,
    required this.points,
    required this.passes,
    required this.widthMm,
    required this.heightMm,
    required this.tool,
    required this.tabs,
    required this.previewPng,
  });

  final String gcode;
  final int loops;
  final int points;
  final int passes;
  final double widthMm;
  final double heightMm;
  final ContourTool tool;
  final int tabs;

  /// PNG con los contornos simplificados que se van a cortar.
  final Uint8List previewPng;

  int get lineCount => gcode.split('\n').length;
}

/// Error del generador de contornos, apto para la UI.
class ContourException implements Exception {
  const ContourException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Vectoriza la silueta de una imagen y genera el G-code del contorno.
///
/// · Umbral (o su inverso) → rejilla binaria → bucles de frontera por píxel.
/// · Simplificación Douglas–Peucker con tolerancia en mm.
/// · Láser: `M4` y `S` conmutado (pestañas = `S0`). Husillo: `M3 S…` y pasadas
///   en Z hasta `cutZ`, con las pestañas levantando la Z.
class ContourGenerator {
  const ContourGenerator();

  static const int maxCells = 250000;
  static const int maxPoints = 40000;

  Future<ContourResult> generateAsync(ContourJob job) {
    return Isolate.run(() => generate(job));
  }

  ContourResult generate(ContourJob job) {
    final List<String> errors = job.settings.validate();
    if (errors.isNotEmpty) {
      throw ContourException(errors.first);
    }
    final ContourSettings settings = job.settings;

    final img.Image? decoded = img.decodeImage(job.bytes);
    if (decoded == null) {
      throw const ContourException(
        'No se pudo decodificar la imagen (usa PNG, JPG o BMP).',
      );
    }
    final img.Image gray = img.grayscale(decoded);

    final int columns = (settings.widthMm / settings.pixelMm).round().clamp(
      1,
      20000,
    );
    final double heightMm = settings.widthMm * gray.height / gray.width;
    final int rows = (heightMm / settings.pixelMm).round().clamp(1, 20000);
    if (columns * rows > maxCells) {
      throw ContourException(
        'La imagen generaría ${columns * rows} celdas (máximo $maxCells): '
        'aumenta los mm por celda o reduce el ancho.',
      );
    }

    final List<List<bool>> inside = _samplingGrid(
      gray,
      columns,
      rows,
      settings,
    );
    final List<List<Vector2>> pixelLoops = _traceLoops(inside);
    if (pixelLoops.isEmpty) {
      throw const ContourException(
        'No se encontró ninguna silueta: ajusta el umbral o invierte los '
        'colores.',
      );
    }

    final double epsilonPx = settings.simplifyMm / settings.pixelMm;
    final List<List<Vector2>> simplified = <List<Vector2>>[];
    for (final List<Vector2> loop in pixelLoops) {
      final List<Vector2> reduced = _simplifyLoop(loop, epsilonPx);
      if (reduced.length >= 3) {
        simplified.add(reduced);
      }
    }
    if (simplified.isEmpty) {
      throw const ContourException(
        'Los contornos quedaron demasiado pequeños: baja la tolerancia de '
        'simplificación.',
      );
    }

    int points = 0;
    for (final List<Vector2> loop in simplified) {
      points += loop.length;
    }
    if (points > maxPoints) {
      throw ContourException(
        'El contorno tiene $points puntos (máximo $maxPoints): reduce la '
        'resolución o sube la tolerancia de simplificación.',
      );
    }

    final List<List<Vector2>> mmLoops = <List<Vector2>>[
      for (final List<Vector2> loop in simplified)
        <Vector2>[
          for (final Vector2 point in loop)
            Vector2(
              settings.originXmm + point.x * settings.pixelMm,
              settings.originYmm + heightMm - point.y * settings.pixelMm,
            ),
        ],
    ];

    final String gcode = _emit(
      loops: mmLoops,
      settings: settings,
      loopCount: mmLoops.length,
    );

    return ContourResult(
      gcode: gcode,
      loops: mmLoops.length,
      points: points,
      passes: _levels(settings).length,
      widthMm: settings.widthMm,
      heightMm: heightMm,
      tool: settings.tool,
      tabs: settings.tabs,
      previewPng: _previewPng(columns, rows, simplified),
    );
  }

  /// Rejilla binaria: `true` donde hay material que recortar.
  List<List<bool>> _samplingGrid(
    img.Image gray,
    int columns,
    int rows,
    ContourSettings settings,
  ) {
    final List<List<bool>> grid = <List<bool>>[
      for (int r = 0; r < rows; r++) List<bool>.filled(columns, false),
    ];
    for (int r = 0; r < rows; r++) {
      final int y0 = (r * gray.height / rows).floor();
      final int y1 = (((r + 1) * gray.height) / rows).ceil().clamp(
        y0 + 1,
        gray.height,
      );
      for (int c = 0; c < columns; c++) {
        final int x0 = (c * gray.width / columns).floor();
        final int x1 = (((c + 1) * gray.width) / columns).ceil().clamp(
          x0 + 1,
          gray.width,
        );
        int sum = 0;
        int count = 0;
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            sum += gray.getPixel(x, y).r.toInt();
            count++;
          }
        }
        final double luminance = count == 0 ? 255 : sum / count / 255.0;
        final bool dark = luminance <= settings.threshold;
        grid[r][c] = settings.invert ? !dark : dark;
      }
    }
    return grid;
  }

  /// Bordes de la rejilla enlazados en bucles cerrados (con las islas internas).
  ///
  /// Se recorren las aristas de cada píxel interior que da al exterior y se
  /// encadenan por sus vértices: el resultado es una escalera por píxel que luego
  /// se simplifica.
  List<List<Vector2>> _traceLoops(List<List<bool>> inside) {
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
  List<Vector2> _simplifyLoop(List<Vector2> loop, double epsilonPx) {
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
        final double distance = _distanceToSegment(
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

  static double _distanceToSegment(Vector2 point, Vector2 a, Vector2 b) {
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

  /// Profundidades de pasada (el láser no usa Z).
  List<double> _levels(ContourSettings settings) {
    if (settings.tool.isLaser) {
      return const <double>[0];
    }
    final List<double> levels = <double>[];
    double z = -settings.passDepthMm;
    while (z > settings.cutZmm + 1e-9 && levels.length < 200) {
      levels.add(z);
      z -= settings.passDepthMm;
    }
    levels.add(settings.cutZmm);
    return levels;
  }

  String _emit({
    required List<List<Vector2>> loops,
    required ContourSettings settings,
    required int loopCount,
  }) {
    final List<double> levels = _levels(settings);
    final StringBuffer out = StringBuffer()
      ..writeln(
        '; Contorno ${settings.tool.label} · $loopCount vueltas · '
        '${levels.length} pasadas · ${settings.tabs} pestañas',
      )
      ..writeln('G21')
      ..writeln('G90');
    if (settings.tool.isLaser) {
      out.writeln('M4');
    } else {
      out
        ..writeln('G0 Z${_mm(settings.safeZmm)}')
        ..writeln('M3 S${settings.power}');
    }

    for (final List<Vector2> loop in loops) {
      for (final double level in levels) {
        _emitLoop(out, loop, settings, level);
        if (!settings.tool.isLaser) {
          out.writeln('G0 Z${_mm(settings.safeZmm)}');
        }
      }
    }

    out.writeln('M5');
    if (!settings.tool.isLaser) {
      out.writeln('G0 Z${_mm(settings.safeZmm)}');
    }
    out
      ..writeln('G0 X${_mm(settings.originXmm)} Y${_mm(settings.originYmm)}')
      ..writeln('; fin del contorno');
    return out.toString();
  }

  /// Recorre una vuelta, partiendo los tramos en los bordes de las pestañas.
  void _emitLoop(
    StringBuffer out,
    List<Vector2> loop,
    ContourSettings settings,
    double level,
  ) {
    final double perimeter = _perimeter(loop);
    final List<double> centers = <double>[
      if (settings.tabs > 0)
        for (int i = 0; i < settings.tabs; i++)
          perimeter * (i + 0.5) / settings.tabs,
    ];
    final double halfTab = settings.tabWidthMm / 2;
    bool inTabAt(double distance) =>
        centers.any((double c) => (distance - c).abs() <= halfTab);

    final Vector2 start = loop.first;
    out.writeln(
      'G0 X${_mm(start.x)} Y${_mm(start.y)}${settings.tool.isLaser ? ' S0' : ''}',
    );
    if (settings.tool.isLaser) {
      out.writeln('G1 S${settings.power} F${_mm(settings.feedMmMin)}');
    } else {
      out
        ..writeln('G1 Z${_mm(level)} F${_mm(settings.plungeMmMin)}')
        ..writeln('G1 F${_mm(settings.feedMmMin)}');
    }

    bool tabState = false;
    double travelled = 0;
    for (int i = 0; i < loop.length; i++) {
      final Vector2 from = loop[i];
      final Vector2 to = loop[(i + 1) % loop.length];
      final double length = (to - from).length;
      if (length <= 1e-9) {
        continue;
      }
      final List<double> cuts = <double>[0];
      for (final double center in centers) {
        for (final double edge in <double>[
          center - halfTab,
          center + halfTab,
        ]) {
          final double local = edge - travelled;
          if (local > 1e-6 && local < length - 1e-6) {
            cuts.add(local);
          }
        }
      }
      cuts
        ..add(length)
        ..sort();
      for (int c = 0; c < cuts.length - 1; c++) {
        final double t = cuts[c + 1] / length;
        final double mid = travelled + (cuts[c] + cuts[c + 1]) / 2;
        final bool inTab = inTabAt(mid);
        if (inTab != tabState) {
          tabState = inTab;
          if (settings.tool.isLaser) {
            out.writeln('G1 S${inTab ? 0 : settings.power}');
          } else {
            out.writeln(
              'G1 Z${_mm(inTab ? level + settings.tabHeightMm : level)}',
            );
          }
        }
        final Vector2 target = Vector2(
          from.x + (to.x - from.x) * t,
          from.y + (to.y - from.y) * t,
        );
        out.writeln('G1 X${_mm(target.x)} Y${_mm(target.y)}');
      }
      travelled += length;
    }
    if (settings.tool.isLaser) {
      out.writeln('G1 S0');
    }
  }

  static double _perimeter(List<Vector2> loop) {
    double total = 0;
    for (int i = 0; i < loop.length; i++) {
      total += (loop[(i + 1) % loop.length] - loop[i]).length;
    }
    return total;
  }

  /// Vista previa vectorial: los contornos simplificados sobre fondo claro.
  Uint8List _previewPng(int columns, int rows, List<List<Vector2>> pixelLoops) {
    final img.Image preview = img.Image(width: columns, height: rows);
    img.fill(preview, color: img.ColorRgb8(250, 248, 242));
    final img.Color ink = img.ColorRgb8(24, 24, 24);
    for (final List<Vector2> loop in pixelLoops) {
      for (int i = 0; i < loop.length; i++) {
        final Vector2 a = loop[i];
        final Vector2 b = loop[(i + 1) % loop.length];
        img.drawLine(
          preview,
          x1: a.x.round(),
          y1: a.y.round(),
          x2: b.x.round(),
          y2: b.y.round(),
          color: ink,
        );
      }
    }
    return Uint8List.fromList(img.encodePng(preview));
  }

  static String _mm(double value) => value.toStringAsFixed(3);
}
