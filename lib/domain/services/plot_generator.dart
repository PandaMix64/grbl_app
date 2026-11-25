import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:vector_math/vector_math_64.dart';

import 'contour_tracer.dart';

/// Cómo se procesa la imagen para el plóter.
enum PlotMode {
  /// Silueta vectorizada: rutas optimizadas para dibujar contornos.
  vector,

  /// Bordado raster: líneas paralelas que rellenan las zonas oscuras.
  hatch;

  String get label => switch (this) {
    PlotMode.vector => 'Rutas vectoriales',
    PlotMode.hatch => 'Bordado raster',
  };
}

/// Cómo baja y sube el rotulador.
enum PenControl {
  /// Servo o PWM por el husillo: `M3 S…` baja, `M5` sube.
  spindle,

  /// El rotulador va en Z: `G1 Z…` baja, `G0 Z…` sube.
  zAxis;

  String get label => switch (this) {
    PenControl.spindle => 'Husillo (M3/M5)',
    PenControl.zAxis => 'Eje Z',
  };
}

/// Parámetros del trazado.
class PlotSettings {
  const PlotSettings({
    this.widthMm = 120,
    this.pixelMm = 0.3,
    this.threshold = 0.5,
    this.invert = false,
    this.mode = PlotMode.vector,
    this.pen = PenControl.spindle,
    this.penDownS = 1000,
    this.zUpMm = 2,
    this.zDownMm = -0.3,
    this.drawFeedMmMin = 1500,
    this.travelFeedMmMin = 4000,
    this.simplifyMm = 0.15,
    this.smoothMm = 0.4,
    this.optimizeOrder = true,
    this.hatchSpacingMm = 1.5,
    this.hatchAngleDeg = 45,
    this.stitchMm = 0,
    this.originXmm = 0,
    this.originYmm = 0,
  });

  final double widthMm;
  final double pixelMm;
  final double threshold;
  final bool invert;
  final PlotMode mode;
  final PenControl pen;

  /// `S` de bajada del rotulador cuando [pen] es [PenControl.spindle].
  final int penDownS;

  /// Alturas de Z cuando [pen] es [PenControl.zAxis].
  final double zUpMm;
  final double zDownMm;

  final double drawFeedMmMin;
  final double travelFeedMmMin;
  final double simplifyMm;

  /// Radio de suavizado en mm (0 = sin suavizar).
  ///
  /// Convierte la escalera de píxeles de las diagonales y curvas en una polilínea
  /// continua, conservando las esquinas marcadas.
  final double smoothMm;

  final bool optimizeOrder;

  /// Separación entre líneas del bordado y su ángulo.
  final double hatchSpacingMm;
  final double hatchAngleDeg;

  /// Longitud de puntada; 0 = línea continua.
  final double stitchMm;

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
    if (penDownS < 1 || penDownS > 30000) {
      errors.add('La potencia de bajada debe estar entre 1 y 30000.');
    }
    if (zDownMm >= zUpMm) {
      errors.add('La Z de dibujo debe ser menor que la Z de viaje.');
    }
    if (drawFeedMmMin < 1 || drawFeedMmMin > 20000) {
      errors.add('El avance de dibujo debe estar entre 1 y 20000 mm/min.');
    }
    if (travelFeedMmMin < 1 || travelFeedMmMin > 30000) {
      errors.add('El avance de viaje debe estar entre 1 y 30000 mm/min.');
    }
    if (simplifyMm < 0 || simplifyMm > 5) {
      errors.add('La tolerancia de simplificación debe estar entre 0 y 5 mm.');
    }
    if (smoothMm < 0 || smoothMm > 5) {
      errors.add('El suavizado debe estar entre 0 y 5 mm.');
    }
    if (hatchSpacingMm < 0.2 || hatchSpacingMm > 20) {
      errors.add('La separación del bordado debe estar entre 0.2 y 20 mm.');
    }
    if (stitchMm < 0 || stitchMm > 50) {
      errors.add('La puntada debe estar entre 0 y 50 mm.');
    }
    return errors;
  }
}

/// Entrada del generador de trazado.
class PlotJob {
  const PlotJob({required this.bytes, required this.settings});

  final Uint8List bytes;
  final PlotSettings settings;
}

/// Resultado del trazado.
class PlotResult {
  const PlotResult({
    required this.gcode,
    required this.mode,
    required this.paths,
    required this.points,
    required this.widthMm,
    required this.heightMm,
    required this.previewPng,
  });

  final String gcode;
  final PlotMode mode;

  /// Trayectos dibujados (cada uno con un ciclo de bajar/subir).
  final int paths;
  final int points;
  final double widthMm;
  final double heightMm;

  /// PNG con lo que se va a dibujar.
  final Uint8List previewPng;

  int get lineCount => gcode.split('\n').length;
}

/// Error del generador de trazado, apto para la UI.
class PlotException implements Exception {
  const PlotException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Genera trazados para plóter/rotulador a partir de una imagen.
///
/// · **Vectorial**: silueta → contornos simplificados → orden por proximidad para
///   minimizar los viajes con el rotulador levantado.
/// · **Bordado raster**: líneas paralelas (ángulo y separación configurables) que
///   rellenan las zonas oscuras, con puntadas opcionales.
class PlotGenerator {
  const PlotGenerator();

  static const int maxCells = 400000;
  static const int maxPaths = 60000;

  static const ContourTracer _tracer = ContourTracer();

  Future<PlotResult> generateAsync(PlotJob job) {
    return Isolate.run(() => generate(job));
  }

  PlotResult generate(PlotJob job) {
    final List<String> errors = job.settings.validate();
    if (errors.isNotEmpty) {
      throw PlotException(errors.first);
    }
    final PlotSettings settings = job.settings;

    final img.Image? decoded = img.decodeImage(job.bytes);
    if (decoded == null) {
      throw const PlotException(
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
      throw PlotException(
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

    final List<List<Vector2>> pixelPaths = settings.mode == PlotMode.vector
        ? _vectorPaths(inside, settings)
        : _hatchPaths(inside, columns, rows, settings);
    if (pixelPaths.isEmpty) {
      throw const PlotException(
        'No se encontró nada que dibujar: ajusta el umbral o invierte los '
        'colores.',
      );
    }
    if (pixelPaths.length > maxPaths) {
      throw PlotException(
        'El trazado tendría ${pixelPaths.length} trayectos (máximo $maxPaths): '
        'baja la resolución o sube la tolerancia.',
      );
    }

    int points = 0;
    for (final List<Vector2> path in pixelPaths) {
      points += path.length;
    }

    final List<List<Vector2>> mmPaths = <List<Vector2>>[
      for (final List<Vector2> path in pixelPaths)
        <Vector2>[
          for (final Vector2 point in path)
            Vector2(
              settings.originXmm + point.x * settings.pixelMm,
              settings.originYmm + heightMm - point.y * settings.pixelMm,
            ),
        ],
    ];

    final String gcode = _emit(paths: mmPaths, settings: settings);

    return PlotResult(
      gcode: gcode,
      mode: settings.mode,
      paths: mmPaths.length,
      points: points,
      widthMm: settings.widthMm,
      heightMm: heightMm,
      previewPng: _previewPng(columns, rows, pixelPaths),
    );
  }

  /// Rejilla binaria: `true` donde hay tinta que dibujar.
  List<List<bool>> _samplingGrid(
    img.Image gray,
    int columns,
    int rows,
    PlotSettings settings,
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

  /// G-code del trazado con ciclos bajar/dibujar/subir.
  String _emit({
    required List<List<Vector2>> paths,
    required PlotSettings settings,
  }) {
    final StringBuffer out = StringBuffer()
      ..writeln(
        '; Trazado ${settings.mode.label} · ${_penLabel(settings)} · '
        '${paths.length} trayectos',
      )
      ..writeln('G21')
      ..writeln('G90');
    _penUp(out, settings);

    for (final List<Vector2> path in paths) {
      if (path.length < 2) {
        continue;
      }
      out.writeln(
        'G0 X${_mm(path.first.x)} Y${_mm(path.first.y)} '
        'F${_mm(settings.travelFeedMmMin)}',
      );
      _penDown(out, settings);
      for (int i = 1; i < path.length; i++) {
        out.writeln(
          'G1 X${_mm(path[i].x)} Y${_mm(path[i].y)} '
          'F${_mm(settings.drawFeedMmMin)}',
        );
      }
      _penUp(out, settings);
    }

    out
      ..writeln('M5')
      ..writeln('G0 X${_mm(settings.originXmm)} Y${_mm(settings.originYmm)}')
      ..writeln('; fin del trazado');
    return out.toString();
  }

  static String _penLabel(PlotSettings settings) => switch (settings.pen) {
    PenControl.spindle => 'pluma M3 S${settings.penDownS}',
    PenControl.zAxis =>
      'pluma Z${_mm(settings.zDownMm)}/${_mm(settings.zUpMm)}',
  };

  void _penDown(StringBuffer out, PlotSettings settings) {
    if (settings.pen == PenControl.spindle) {
      out.writeln('M3 S${settings.penDownS}');
    } else {
      out.writeln('G1 Z${_mm(settings.zDownMm)}');
    }
  }

  void _penUp(StringBuffer out, PlotSettings settings) {
    if (settings.pen == PenControl.spindle) {
      out.writeln('M5');
    } else {
      out.writeln('G0 Z${_mm(settings.zUpMm)}');
    }
  }

  /// Vista previa del dibujo sobre fondo claro.
  Uint8List _previewPng(int columns, int rows, List<List<Vector2>> paths) {
    final img.Image preview = img.Image(width: columns, height: rows);
    img.fill(preview, color: img.ColorRgb8(250, 248, 242));
    final img.Color ink = img.ColorRgb8(24, 24, 24);
    int clampX(double value) => value.round().clamp(0, columns - 1);
    int clampY(double value) => value.round().clamp(0, rows - 1);
    for (final List<Vector2> path in paths) {
      if (path.length < 2) {
        continue;
      }
      for (int i = 0; i < path.length - 1; i++) {
        img.drawLine(
          preview,
          x1: clampX(path[i].x),
          y1: clampY(path[i].y),
          x2: clampX(path[i + 1].x),
          y2: clampY(path[i + 1].y),
          color: ink,
        );
      }
    }
    return Uint8List.fromList(img.encodePng(preview));
  }

  static String _mm(double value) => value.toStringAsFixed(3);

  /// Contornos simplificados y, si se pide, ordenados por proximidad.
  List<List<Vector2>> _vectorPaths(
    List<List<bool>> inside,
    PlotSettings settings,
  ) {
    final double epsilonPx = settings.simplifyMm / settings.pixelMm;
    final int window = (settings.smoothMm / settings.pixelMm).round().clamp(
      0,
      10,
    );
    final List<List<Vector2>> loops = <List<Vector2>>[];
    for (final List<Vector2> loop in _tracer.trace(inside)) {
      List<Vector2> reduced = _tracer.simplify(loop, epsilonPx);
      if (window > 0 && reduced.length >= 5) {
        // Suaviza la escalera de píxeles y vuelve a simplificar: menos vértices
        // por curva, sin los dientes de sierra de las diagonales.
        reduced = _tracer.simplify(_smooth(reduced, window), epsilonPx * 0.5);
      }
      if (reduced.length >= 3) {
        // Cerrado: se repite el primer punto al final.
        loops.add(<Vector2>[...reduced, reduced.first]);
      }
    }
    if (!settings.optimizeOrder || loops.length < 2) {
      return loops;
    }
    return _orderByProximity(loops);
  }

  /// Suaviza el trayecto promediando vecinos y conservando las esquinas.
  ///
  /// Un vértice se considera esquina si se separa del punto medio de sus vecinos
  /// más de `1,5 × ventana` píxeles: los escalones de una diagonal son pequeños y
  /// se suavizan; la punta de un corazón se conserva.
  List<Vector2> _smooth(List<Vector2> loop, int window) {
    final int count = loop.length;
    if (window < 1 || count < 5) {
      return loop;
    }
    final double cornerPx = window * 1.5;
    final double divisor = (2 * window + 1).toDouble();
    final List<Vector2> out = <Vector2>[];
    for (int i = 0; i < count; i++) {
      final Vector2 current = loop[i];
      final Vector2 before = loop[(i - window + count) % count];
      final Vector2 after = loop[(i + window) % count];
      final Vector2 chord = (before + after) * 0.5;
      if ((current - chord).length > cornerPx) {
        out.add(current);
        continue;
      }
      Vector2 sum = Vector2.zero();
      for (int offset = -window; offset <= window; offset++) {
        sum += loop[(i + offset + count) % count];
      }
      out.add(sum / divisor);
    }
    return out;
  }

  List<List<Vector2>> _orderByProximity(List<List<Vector2>> loops) {
    final List<List<Vector2>> remaining = List<List<Vector2>>.of(loops);
    final List<List<Vector2>> ordered = <List<Vector2>>[];
    Vector2 cursor = Vector2.zero();
    while (remaining.isNotEmpty) {
      int best = 0;
      bool reverse = false;
      double bestDistance = double.infinity;
      for (int i = 0; i < remaining.length; i++) {
        final double startDistance = (remaining[i].first - cursor).length;
        if (startDistance < bestDistance) {
          bestDistance = startDistance;
          best = i;
          reverse = false;
        }
        final double endDistance = (remaining[i].last - cursor).length;
        if (endDistance < bestDistance) {
          bestDistance = endDistance;
          best = i;
          reverse = true;
        }
      }
      final List<Vector2> path = remaining.removeAt(best);
      ordered.add(reverse ? path.reversed.toList() : path);
      cursor = ordered.last.last;
    }
    return ordered;
  }

  /// Líneas paralelas que rellenan las zonas oscuras (bordado raster).
  List<List<Vector2>> _hatchPaths(
    List<List<bool>> inside,
    int columns,
    int rows,
    PlotSettings settings,
  ) {
    final double spacingPx = (settings.hatchSpacingMm / settings.pixelMm).clamp(
      1.0,
      10000.0,
    );
    final double theta = -settings.hatchAngleDeg * math.pi / 180;
    final Vector2 direction = Vector2(math.cos(theta), math.sin(theta));
    final Vector2 normal = Vector2(-direction.y, direction.x);
    final Vector2 center = Vector2(columns / 2, rows / 2);
    final double reach = math.sqrt(columns * columns + rows * rows) / 2;
    final int lines = (reach * 2 / spacingPx).ceil() + 1;

    bool filledAt(Vector2 point) {
      final int x = point.x.round();
      final int y = point.y.round();
      if (x < 0 || y < 0 || x >= columns || y >= rows) {
        return false;
      }
      return inside[y][x];
    }

    final List<List<Vector2>> paths = <List<Vector2>>[];
    for (int line = 0; line < lines; line++) {
      final Vector2 base = center + normal * ((line - lines / 2) * spacingPx);
      final List<List<double>> runs = <List<double>>[];
      double? runStart;
      double t = -reach;
      while (t <= reach) {
        final bool inRun = filledAt(base + direction * t);
        if (inRun && runStart == null) {
          runStart = t;
        } else if (!inRun && runStart != null) {
          runs.add(<double>[runStart, t]);
          runStart = null;
        }
        t += 0.5;
      }
      if (runStart != null) {
        runs.add(<double>[runStart, reach]);
      }
      // Zigzag: las líneas impares se recorren al revés.
      final bool reverse = line.isOdd;
      final List<List<double>> ordered = reverse
          ? runs.reversed.toList()
          : runs;
      for (final List<double> run in ordered) {
        final Vector2 a = base + direction * run[0];
        final Vector2 b = base + direction * run[1];
        final Vector2 start = reverse ? b : a;
        final Vector2 end = reverse ? a : b;
        final double lengthPx = (end - start).length;
        if (lengthPx < 1e-6) {
          continue;
        }
        if (settings.stitchMm <= 0) {
          paths.add(<Vector2>[start, end]);
          continue;
        }
        final double stitchPx = settings.stitchMm / settings.pixelMm;
        final double stepPx = stitchPx * 1.35;
        double travelled = 0;
        while (travelled < lengthPx) {
          final double from = travelled;
          final double to = math.min(travelled + stitchPx, lengthPx);
          paths.add(<Vector2>[
            start + (end - start) * (from / lengthPx),
            start + (end - start) * (to / lengthPx),
          ]);
          travelled += stepPx;
        }
      }
    }
    return paths;
  }
}
