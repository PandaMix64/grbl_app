import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Parámetros del relieve 2.5D (fresado por niveles de profundidad).
class ReliefSettings {
  const ReliefSettings({
    this.widthMm = 60,
    this.pixelMm = 1,
    this.levels = 6,
    this.maxDepthMm = 3,
    this.passDepthMm = 0.5,
    this.rpm = 8000,
    this.feedMmMin = 600,
    this.plungeMmMin = 200,
    this.safeZmm = 2,
    this.invert = false,
    this.originXmm = 0,
    this.originYmm = 0,
  });

  /// Ancho del relieve; el alto sale de la proporción de la imagen.
  final double widthMm;

  /// Resolución de la rejilla (mm por celda).
  final double pixelMm;

  /// Niveles de profundidad (2..16).
  final int levels;

  /// Profundidad de la celda más oscura (positiva; se aplica en negativo).
  final double maxDepthMm;

  /// Profundidad por pasada dentro de un nivel.
  final double passDepthMm;

  /// Velocidad del husillo (`S` de `M3`).
  final int rpm;

  final double feedMmMin;
  final double plungeMmMin;
  final double safeZmm;
  final bool invert;
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
    if (levels < 2 || levels > 16) {
      errors.add('Los niveles deben estar entre 2 y 16.');
    }
    if (maxDepthMm < 0.1 || maxDepthMm > 50) {
      errors.add('La profundidad máxima debe estar entre 0.1 y 50 mm.');
    }
    if (passDepthMm <= 0 || passDepthMm > 10) {
      errors.add('La profundidad por pasada debe estar entre 0 y 10 mm.');
    }
    if (passDepthMm > maxDepthMm) {
      errors.add('La pasada no puede ser mayor que la profundidad total.');
    }
    if (rpm < 1 || rpm > 30000) {
      errors.add('Las RPM deben estar entre 1 y 30000.');
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
    return errors;
  }
}

/// Entrada del generador de relieve.
class ReliefJob {
  const ReliefJob({required this.bytes, required this.settings});

  final Uint8List bytes;
  final ReliefSettings settings;
}

/// Resultado del relieve: G-code, estadísticas y mapa de altura.
class ReliefResult {
  const ReliefResult({
    required this.gcode,
    required this.columns,
    required this.rows,
    required this.widthMm,
    required this.heightMm,
    required this.levels,
    required this.maxDepthMm,
    required this.cutCells,
    required this.previewPng,
  });

  final String gcode;
  final int columns;
  final int rows;
  final double widthMm;
  final double heightMm;
  final int levels;
  final double maxDepthMm;

  /// Celdas que se fresan (nivel > 0).
  final int cutCells;

  /// PNG con el mapa de altura cuantizado (oscuro = más profundo).
  final Uint8List previewPng;

  int get lineCount => gcode.split('\n').length;

  double get cutRatio => columns * rows == 0 ? 0 : cutCells / (columns * rows);
}

/// Error del generador de relieve, apto para la UI.
class ReliefException implements Exception {
  const ReliefException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Genera un relieve 2.5D: cuantiza la imagen en niveles de profundidad y fresca
/// cada banda con el husillo (`M3`), bajando en pasadas.
///
/// · Nivel 0 = sin material que quitar (claro); `niveles` = lo más profundo
///   (oscuro).
/// · Para cada nivel se fresan las celdas de ese nivel o más profundas, de modo
///   que el acabado es una escalera de profundidad.
class ReliefGenerator {
  const ReliefGenerator();

  static const int maxCells = 120000;
  static const int maxMoves = 400000;

  Future<ReliefResult> generateAsync(ReliefJob job) {
    return Isolate.run(() => generate(job));
  }

  ReliefResult generate(ReliefJob job) {
    final List<String> errors = job.settings.validate();
    if (errors.isNotEmpty) {
      throw ReliefException(errors.first);
    }
    final ReliefSettings settings = job.settings;

    final img.Image? decoded = img.decodeImage(job.bytes);
    if (decoded == null) {
      throw const ReliefException(
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
      throw ReliefException(
        'La imagen generaría ${columns * rows} celdas (máximo $maxCells).',
      );
    }

    final List<List<int>> levels = _levelGrid(gray, columns, rows, settings);
    int cut = 0;
    for (final List<int> row in levels) {
      for (final int value in row) {
        if (value > 0) {
          cut++;
        }
      }
    }
    if (cut == 0) {
      throw const ReliefException(
        'No hay nada que fresar: la imagen es demasiado clara o el umbral '
        'equivale a cero. Invierte los colores o sube el contraste.',
      );
    }

    final String gcode = _emit(
      levels: levels,
      settings: settings,
      heightMm: heightMm,
    );
    if (gcode.split('\n').length > maxMoves) {
      throw ReliefException(
        'El relieve generaría demasiadas líneas (más de $maxMoves): aumenta '
        'los mm por celda, baja los niveles o sube la profundidad por pasada.',
      );
    }

    return ReliefResult(
      gcode: gcode,
      columns: columns,
      rows: rows,
      widthMm: settings.widthMm,
      heightMm: heightMm,
      levels: settings.levels,
      maxDepthMm: settings.maxDepthMm,
      cutCells: cut,
      previewPng: _previewPng(levels, settings),
    );
  }

  /// Media de luminancia por celda convertida a nivel de profundidad (0..N).
  List<List<int>> _levelGrid(
    img.Image gray,
    int columns,
    int rows,
    ReliefSettings settings,
  ) {
    final List<List<int>> grid = <List<int>>[
      for (int r = 0; r < rows; r++) List<int>.filled(columns, 0),
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
        double sum = 0;
        int count = 0;
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            sum += gray.getPixel(x, y).r.toDouble();
            count++;
          }
        }
        double luminance = count == 0 ? 1 : sum / count / 255.0;
        if (settings.invert) {
          luminance = 1 - luminance;
        }
        // Claro = 0 (sin corte); oscuro = `levels` (lo más profundo).
        final int level = ((1 - luminance).clamp(0.0, 1.0) * settings.levels)
            .ceil();
        grid[r][c] = level.clamp(0, settings.levels);
      }
    }
    return grid;
  }

  /// Emite las pasadas: por nivel, por pasada de Z y por tramo horizontal.
  String _emit({
    required List<List<int>> levels,
    required ReliefSettings settings,
    required double heightMm,
  }) {
    final int rows = levels.length;
    final int columns = rows == 0 ? 0 : levels.first.length;
    final StringBuffer out = StringBuffer()
      ..writeln(
        '; Relieve 2.5D · ${settings.levels} niveles · '
        'profundidad ${settings.maxDepthMm.toStringAsFixed(2)} mm · '
        '${columns}x$rows celdas',
      )
      ..writeln('G21')
      ..writeln('G90')
      ..writeln('G0 Z${_mm(settings.safeZmm)}')
      ..writeln('M3 S${settings.rpm}');

    for (int level = 1; level <= settings.levels; level++) {
      final double depth = settings.maxDepthMm * level / settings.levels;
      final int passes = (depth / settings.passDepthMm).ceil().clamp(1, 100);
      for (int pass = 1; pass <= passes; pass++) {
        final double z = -depth * pass / passes;
        out.writeln(
          '; nivel $level/${settings.levels} · pasada $pass/$passes '
          '(Z${_mm(z)})',
        );
        for (int r = 0; r < rows; r++) {
          final double y =
              settings.originYmm + heightMm - (r + 0.5) * settings.pixelMm;
          int c = 0;
          while (c < columns) {
            if (levels[r][c] < level) {
              c++;
              continue;
            }
            int end = c;
            while (end + 1 < columns && levels[r][end + 1] >= level) {
              end++;
            }
            final double xStart = settings.originXmm + c * settings.pixelMm;
            final double xEnd =
                settings.originXmm + (end + 1) * settings.pixelMm;
            out
              ..writeln(
                'G0 X${_mm(xStart)} Y${_mm(y)} Z${_mm(settings.safeZmm)}',
              )
              ..writeln('G1 Z${_mm(z)} F${_mm(settings.plungeMmMin)}')
              ..writeln('G1 X${_mm(xEnd)} F${_mm(settings.feedMmMin)}')
              ..writeln('G0 Z${_mm(settings.safeZmm)}');
            c = end + 1;
          }
        }
      }
    }

    out
      ..writeln('M5')
      ..writeln('G0 Z${_mm(settings.safeZmm)}')
      ..writeln('G0 X${_mm(settings.originXmm)} Y${_mm(settings.originYmm)}')
      ..writeln('; fin del relieve');
    return out.toString();
  }

  /// Mapa de altura cuantizado: oscuro = más profundo.
  Uint8List _previewPng(List<List<int>> levels, ReliefSettings settings) {
    final int rows = levels.length;
    final int columns = rows == 0 ? 0 : levels.first.length;
    final img.Image preview = img.Image(width: columns, height: rows);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        final double ratio = settings.levels == 0
            ? 0
            : levels[r][c] / settings.levels;
        final int shade = (255 * (1 - ratio)).round();
        preview.setPixelRgb(c, r, shade, shade, shade);
      }
    }
    return Uint8List.fromList(img.encodePng(preview));
  }

  static String _mm(double value) => value.toStringAsFixed(3);
}
