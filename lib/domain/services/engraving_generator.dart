import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Conversión de la imagen a potencia del láser.
enum EngravingMode {
  /// Enciende al máximo por debajo del umbral (silueta nítida).
  threshold,

  /// Tramado Floyd–Steinberg a 1 bit (medios tonos con láser).
  dither,

  /// Potencia proporcional a la oscuridad (grabado en escala de grises).
  grayscale;

  String get label => switch (this) {
    EngravingMode.threshold => 'Umbral',
    EngravingMode.dither => 'Tramado',
    EngravingMode.grayscale => 'Escala de grises',
  };
}

/// Parámetros del grabado.
class EngravingSettings {
  const EngravingSettings({
    this.widthMm = 80,
    this.pixelMm = 0.5,
    this.mode = EngravingMode.threshold,
    this.threshold = 0.5,
    this.maxPower = 1000,
    this.feedMmMin = 1200,
    this.invert = false,
    this.originXmm = 0,
    this.originYmm = 0,
  });

  /// Ancho del grabado; el alto sale de la proporción de la imagen.
  final double widthMm;

  /// Tamaño de celda (resolución del grabado) en mm.
  final double pixelMm;

  final EngravingMode mode;

  /// Umbral 0..1 (solo [EngravingMode.threshold]).
  final double threshold;

  /// Potencia máxima (`S`), típicamente el `$30` del perfil.
  final int maxPower;

  final double feedMmMin;

  /// Invierte claro/oscuro.
  final bool invert;

  final double originXmm;
  final double originYmm;

  EngravingSettings copyWith({
    double? widthMm,
    double? pixelMm,
    EngravingMode? mode,
    double? threshold,
    int? maxPower,
    double? feedMmMin,
    bool? invert,
    double? originXmm,
    double? originYmm,
  }) {
    return EngravingSettings(
      widthMm: widthMm ?? this.widthMm,
      pixelMm: pixelMm ?? this.pixelMm,
      mode: mode ?? this.mode,
      threshold: threshold ?? this.threshold,
      maxPower: maxPower ?? this.maxPower,
      feedMmMin: feedMmMin ?? this.feedMmMin,
      invert: invert ?? this.invert,
      originXmm: originXmm ?? this.originXmm,
      originYmm: originYmm ?? this.originYmm,
    );
  }

  /// Errores de validación aptos para mostrar en la UI.
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
    if (maxPower < 1 || maxPower > 30000) {
      errors.add('La potencia máxima debe estar entre 1 y 30000.');
    }
    if (feedMmMin < 1 || feedMmMin > 20000) {
      errors.add('El avance debe estar entre 1 y 20000 mm/min.');
    }
    return errors;
  }
}

/// Entrada del generador (aislada para poder cruzar a un isolate).
class EngravingJob {
  const EngravingJob({required this.bytes, required this.settings});

  final Uint8List bytes;
  final EngravingSettings settings;
}

/// Resultado del grabado: G-code listo para el visor, estadísticas y vista
/// previa del material tal y como quedará.
class EngravingResult {
  const EngravingResult({
    required this.gcode,
    required this.columns,
    required this.rows,
    required this.widthMm,
    required this.heightMm,
    required this.litCells,
    required this.mode,
    required this.maxPower,
    required this.previewPng,
  });

  final String gcode;
  final int columns;
  final int rows;
  final double widthMm;
  final double heightMm;

  /// Celdas que se graban (potencia > 0).
  final int litCells;
  final EngravingMode mode;
  final int maxPower;

  /// PNG de una celda por píxel: negro donde el láser quema al máximo y blanco
  /// donde no actúa. Es el resultado real, no la foto original.
  final Uint8List previewPng;

  int get lineCount => gcode.split('\n').length;

  double get litRatio => columns * rows == 0 ? 0 : litCells / (columns * rows);
}

/// Error de generación con mensaje apto para la UI.
class EngravingException implements Exception {
  const EngravingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Genera G-code de grabado láser desde una imagen.
///
/// · `M4` (láser dinámico) con potencia por celda y `S0` en los rápidos.
/// · El alto se deduce de la proporción de la imagen.
/// · Origen en la esquina inferior izquierda; la fila 0 de la imagen es el borde
///   superior, como en cualquier editor gráfico.
class EngravingGenerator {
  const EngravingGenerator();

  /// Límite de celdas para no generar millones de líneas.
  static const int maxCells = 250000;

  /// Ejecuta la conversión en un isolate para no congelar la UI.
  Future<EngravingResult> generateAsync(EngravingJob job) {
    return Isolate.run(() => generate(job));
  }

  EngravingResult generate(EngravingJob job) {
    final List<String> errors = job.settings.validate();
    if (errors.isNotEmpty) {
      throw EngravingException(errors.first);
    }

    final img.Image? decoded = img.decodeImage(job.bytes);
    if (decoded == null) {
      throw const EngravingException(
        'No se pudo decodificar la imagen (usa PNG, JPG o BMP).',
      );
    }
    final img.Image gray = img.grayscale(decoded);

    final EngravingSettings settings = job.settings;
    final int columns = (settings.widthMm / settings.pixelMm).round().clamp(
      1,
      20000,
    );
    final double heightMm = settings.widthMm * gray.height / gray.width;
    final int rows = (heightMm / settings.pixelMm).round().clamp(1, 20000);
    if (columns * rows > maxCells) {
      throw EngravingException(
        'La imagen generaría ${columns * rows} celdas (máximo $maxCells): '
        'aumenta los mm por celda o reduce el ancho.',
      );
    }

    final List<List<double>> luminance = _sampleLuminance(gray, columns, rows);
    final List<List<int>> power = _powerGrid(luminance, settings);

    int lit = 0;
    for (final List<int> row in power) {
      for (final int value in row) {
        if (value > 0) {
          lit++;
        }
      }
    }

    final String gcode = _emit(
      power: power,
      settings: settings,
      widthMm: settings.widthMm,
      heightMm: heightMm,
    );

    return EngravingResult(
      gcode: gcode,
      columns: columns,
      rows: rows,
      widthMm: settings.widthMm,
      heightMm: heightMm,
      litCells: lit,
      mode: settings.mode,
      maxPower: settings.maxPower,
      previewPng: _previewPng(power, settings.maxPower),
    );
  }

  /// Imagen del resultado: una celda = un píxel, con el material «quemado» en
  /// negro y el resto en blanco.
  Uint8List _previewPng(List<List<int>> power, int maxPower) {
    final int rows = power.length;
    final int columns = rows == 0 ? 0 : power.first.length;
    final img.Image preview = img.Image(width: columns, height: rows);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        final double ratio = maxPower <= 0
            ? 0
            : (power[r][c] / maxPower).clamp(0.0, 1.0);
        final int shade = (255 * (1 - ratio)).round();
        preview.setPixelRgb(c, r, shade, shade, shade);
      }
    }
    return Uint8List.fromList(img.encodePng(preview));
  }

  /// Media de luminancia (0 = negro, 1 = blanco) de cada celda.
  List<List<double>> _sampleLuminance(img.Image gray, int columns, int rows) {
    final List<List<double>> grid = <List<double>>[
      for (int r = 0; r < rows; r++) List<double>.filled(columns, 1.0),
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
        grid[r][c] = count == 0 ? 1.0 : sum / count / 255.0;
      }
    }
    return grid;
  }

  /// Convierte la luminancia en potencia (`0..maxPower`).
  List<List<int>> _powerGrid(
    List<List<double>> luminance,
    EngravingSettings settings,
  ) {
    final List<List<double>> values = <List<double>>[
      for (final List<double> row in luminance)
        <double>[
          for (final double value in row) settings.invert ? 1.0 - value : value,
        ],
    ];
    final int maxPower = settings.maxPower;

    switch (settings.mode) {
      case EngravingMode.grayscale:
        return <List<int>>[
          for (final List<double> row in values)
            <int>[
              for (final double value in row)
                ((1.0 - value).clamp(0.0, 1.0) * maxPower).round(),
            ],
        ];
      case EngravingMode.threshold:
        return <List<int>>[
          for (final List<double> row in values)
            <int>[
              for (final double value in row)
                value <= settings.threshold ? maxPower : 0,
            ],
        ];
      case EngravingMode.dither:
        final List<List<double>> work = <List<double>>[
          for (final List<double> row in values) List<double>.of(row),
        ];
        final List<List<int>> result = <List<int>>[
          for (int r = 0; r < work.length; r++)
            List<int>.filled(work[r].length, 0),
        ];
        for (int r = 0; r < work.length; r++) {
          for (int c = 0; c < work[r].length; c++) {
            final double old = work[r][c];
            final bool on = old <= 0.5;
            result[r][c] = on ? maxPower : 0;
            final double error = old - (on ? 0.0 : 1.0);
            _spread(work, r, c + 1, error * 7 / 16);
            _spread(work, r + 1, c - 1, error * 3 / 16);
            _spread(work, r + 1, c, error * 5 / 16);
            _spread(work, r + 1, c + 1, error * 1 / 16);
          }
        }
        return result;
    }
  }

  static void _spread(
    List<List<double>> grid,
    int row,
    int column,
    double error,
  ) {
    if (row < 0 || row >= grid.length) {
      return;
    }
    final List<double> target = grid[row];
    if (column < 0 || column >= target.length) {
      return;
    }
    target[column] = (target[column] + error).clamp(0.0, 1.0);
  }

  /// Emite el G-code agrupando celdas contiguas con la misma potencia.
  String _emit({
    required List<List<int>> power,
    required EngravingSettings settings,
    required double widthMm,
    required double heightMm,
  }) {
    final int rows = power.length;
    final int columns = rows == 0 ? 0 : power.first.length;
    final StringBuffer out = StringBuffer()
      ..writeln(
        '; Grabado ${settings.mode.label} · ${columns}x$rows · '
        '${widthMm.toStringAsFixed(1)}x${heightMm.toStringAsFixed(1)} mm',
      )
      ..writeln('G21')
      ..writeln('G90')
      ..writeln('M5')
      ..writeln('M4')
      ..writeln('F${settings.feedMmMin.toStringAsFixed(0)}');

    int currentPower = 0;
    for (int r = 0; r < rows; r++) {
      // Fila 0 de la imagen = borde superior del grabado.
      final double y =
          settings.originYmm + heightMm - (r + 0.5) * settings.pixelMm;
      out.writeln('G0 X${_mm(settings.originXmm)} Y${_mm(y)} S0');
      currentPower = 0;

      int c = 0;
      while (c < columns) {
        final int value = power[r][c];
        int end = c;
        while (end + 1 < columns && power[r][end + 1] == value) {
          end++;
        }
        final double xEnd = settings.originXmm + ((end + 1) * settings.pixelMm);
        final String powerWord = value == currentPower ? '' : ' S$value';
        out.writeln('G1 X${_mm(xEnd)} Y${_mm(y)}$powerWord');
        currentPower = value;
        c = end + 1;
      }
    }

    out
      ..writeln('M5')
      ..writeln('G0 X${_mm(settings.originXmm)} Y${_mm(settings.originYmm)}')
      ..writeln('; fin del grabado');
    return out.toString();
  }

  static String _mm(double value) => value.toStringAsFixed(3);
}
