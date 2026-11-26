import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/services/plot_generator.dart';
import 'package:image/image.dart' as img;

Uint8List _encode(img.Image image) => Uint8List.fromList(img.encodePng(image));

img.Image _canvas(int size, {int value = 255}) {
  final img.Image image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return image;
}

/// Cuadrado negro de `inner` × `inner` centrado en (left, top).
img.Image _squareAt(int size, int inner, {int left = 10, int top = 10}) {
  final img.Image image = _canvas(size);
  for (int y = top; y < top + inner; y++) {
    for (int x = left; x < left + inner; x++) {
      image.setPixelRgb(x, y, 0, 0, 0);
    }
  }
  return image;
}

PlotJob _job(img.Image image, {PlotSettings settings = const PlotSettings()}) {
  return PlotJob(bytes: _encode(image), settings: settings);
}

/// Coordenadas de todos los movimientos de dibujo (`G1 X… Y…`).
List<List<double>> _drawMoves(String gcode) {
  final RegExp pattern = RegExp(r'^G1 X(-?\d+\.\d+) Y(-?\d+\.\d+)');
  return <List<double>>[
    for (final String line in gcode.split('\n'))
      if (pattern.firstMatch(line) case final RegExpMatch match)
        <double>[double.parse(match.group(1)!), double.parse(match.group(2)!)],
  ];
}

/// Suma de los giros entre segmentos consecutivos (radianes).
double _turnSum(String gcode) {
  final List<List<double>> points = _drawMoves(gcode);
  double total = 0;
  for (int i = 2; i < points.length; i++) {
    final double a1 = math.atan2(
      points[i - 1][1] - points[i - 2][1],
      points[i - 1][0] - points[i - 2][0],
    );
    final double a2 = math.atan2(
      points[i][1] - points[i - 1][1],
      points[i][0] - points[i - 1][0],
    );
    double delta = (a2 - a1).abs();
    if (delta > math.pi) {
      delta = 2 * math.pi - delta;
    }
    total += delta;
  }
  return total;
}

void main() {
  const PlotGenerator generator = PlotGenerator();

  test('las rutas vectoriales usan el rotulador por husillo', () {
    final PlotResult result = generator.generate(
      _job(
        _squareAt(40, 20),
        settings: const PlotSettings(
          widthMm: 40,
          pixelMm: 1,
          simplifyMm: 0.3,
          penDownS: 900,
        ),
      ),
    );

    expect(result.mode, PlotMode.vector);
    expect(result.paths, 1);
    expect(result.points, inInclusiveRange(4, 6));
    expect(result.gcode, contains('M3 S900'));
    expect(result.gcode, contains('M5'));
    expect(result.gcode, contains('G21'));
    expect(result.gcode, contains('G90'));
    expect(result.gcode, contains('X10.000'));
    expect(result.gcode, contains('X30.000'));
    expect(result.gcode, contains('Y10.000'));
    expect(result.gcode, contains('Y30.000'));
    expect(result.gcode.trimRight(), endsWith('; fin del trazado'));
  });

  test('con eje Z la pluma baja y sube en Z', () {
    final PlotResult result = generator.generate(
      _job(
        _squareAt(40, 20),
        settings: const PlotSettings(
          widthMm: 40,
          pixelMm: 1,
          pen: PenControl.zAxis,
          zUpMm: 2,
          zDownMm: -0.4,
        ),
      ),
    );

    expect(result.gcode, contains('G0 Z2.000'));
    expect(result.gcode, contains('G1 Z-0.400'));
    expect(result.gcode, isNot(contains('M3 S')));
    expect(result.gcode, isNot(contains('M5')));
  });

  test('eleva la punta a la altura segura antes de cada viaje en XY', () {
    const PlotSettings settings = PlotSettings(
      widthMm: 40,
      pixelMm: 1,
      pen: PenControl.zAxis,
      zUpMm: 5,
      zDownMm: -0.3,
      drawFeedMmMin: 900,
      travelFeedMmMin: 3000,
    );
    // Dos islas separadas: obliga a viajar con la punta levantada.
    final img.Image image = _squareAt(60, 10, left: 10, top: 10);
    for (int y = 10; y < 20; y++) {
      for (int x = 40; x < 50; x++) {
        image.setPixelRgb(x, y, 0, 0, 0);
      }
    }
    final PlotResult result = generator.generate(
      _job(image, settings: settings),
    );

    final List<String> lines = <String>[
      for (final String line in result.gcode.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    int travels = 0;
    for (int i = 0; i < lines.length; i++) {
      if (!lines[i].startsWith('G0 X')) {
        continue;
      }
      travels++;
      expect(
        lines[i - 1],
        'G0 Z5.000',
        reason:
            '«${lines[i]}» debe ir precedido de la subida a la altura segura',
      );
    }
    // Un viaje por trayecto más el regreso al origen, también con la punta arriba.
    expect(travels, result.paths + 1);
    expect(travels, greaterThanOrEqualTo(2));
    // La bajada lleva avance propio: no hereda el rápido del viaje.
    expect(result.gcode, contains('G1 Z-0.300 F900.000'));
    expect(result.gcode, contains('F3000.000'));
  });

  test('ordena las rutas por proximidad al origen', () {
    // Dos cuadrados: izquierdo (10..20) y derecho (25..35).
    final img.Image image = _squareAt(60, 10, left: 10, top: 10);
    for (int y = 10; y < 20; y++) {
      for (int x = 40; x < 50; x++) {
        image.setPixelRgb(x, y, 0, 0, 0);
      }
    }

    final PlotResult result = generator.generate(
      _job(
        image,
        settings: const PlotSettings(widthMm: 60, pixelMm: 1, simplifyMm: 0.3),
      ),
    );

    expect(result.paths, 2);
    // El primer trayecto debe ser el más cercano al origen (el izquierdo).
    final String firstTravel = result.gcode
        .split('\n')
        .firstWhere((String line) => line.startsWith('G0 X'));
    expect(firstTravel, contains('X10.000'));
  });

  test('el bordado raster rellena la zona oscura con líneas', () {
    final PlotResult result = generator.generate(
      _job(
        _squareAt(40, 20),
        settings: const PlotSettings(
          widthMm: 40,
          pixelMm: 1,
          mode: PlotMode.hatch,
          hatchSpacingMm: 4,
          hatchAngleDeg: 0,
        ),
      ),
    );

    expect(result.mode, PlotMode.hatch);
    expect(result.paths, greaterThanOrEqualTo(4));
    final List<List<double>> moves = _drawMoves(result.gcode);
    expect(moves, isNotEmpty);
    // Todas las líneas caen dentro del cuadrado (10..30 en X e Y).
    for (final List<double> move in moves) {
      expect(move[0], inInclusiveRange(9.0, 31.0));
      expect(move[1], inInclusiveRange(9.0, 31.0));
    }
    // Ángulo 0: las líneas son horizontales y llegan al borde del cuadrado.
    expect(moves.any((List<double> move) => move[0] >= 29), isTrue);
  });

  test('las puntadas dividen cada línea en trazos cortos', () {
    final PlotResult continuous = generator.generate(
      _job(
        _squareAt(40, 20),
        settings: const PlotSettings(
          widthMm: 40,
          pixelMm: 1,
          mode: PlotMode.hatch,
          hatchSpacingMm: 5,
          hatchAngleDeg: 0,
        ),
      ),
    );
    final PlotResult stitched = generator.generate(
      _job(
        _squareAt(40, 20),
        settings: const PlotSettings(
          widthMm: 40,
          pixelMm: 1,
          mode: PlotMode.hatch,
          hatchSpacingMm: 5,
          hatchAngleDeg: 0,
          stitchMm: 3,
        ),
      ),
    );

    expect(stitched.paths, greaterThan(continuous.paths));
  });

  test('el ángulo cambia la dirección de las líneas', () {
    final PlotResult horizontal = generator.generate(
      _job(
        _squareAt(40, 20),
        settings: const PlotSettings(
          widthMm: 40,
          pixelMm: 1,
          mode: PlotMode.hatch,
          hatchSpacingMm: 5,
          hatchAngleDeg: 0,
        ),
      ),
    );
    final PlotResult diagonal = generator.generate(
      _job(
        _squareAt(40, 20),
        settings: const PlotSettings(
          widthMm: 40,
          pixelMm: 1,
          mode: PlotMode.hatch,
          hatchSpacingMm: 5,
          hatchAngleDeg: 45,
        ),
      ),
    );

    expect(horizontal.gcode, isNot(diagonal.gcode));
  });

  test('sin contenido o con parámetros inválidos se rechaza', () {
    expect(
      () => generator.generate(
        _job(
          _canvas(20),
          settings: const PlotSettings(widthMm: 20, pixelMm: 1),
        ),
      ),
      throwsA(
        isA<PlotException>().having(
          (PlotException e) => e.message,
          'message',
          contains('nada que dibujar'),
        ),
      ),
    );
    expect(
      () => generator.generate(
        _job(
          _squareAt(20, 10),
          settings: const PlotSettings(
            pen: PenControl.zAxis,
            zUpMm: 1,
            zDownMm: 1.5,
          ),
        ),
      ),
      throwsA(isA<PlotException>()),
    );
  });

  test('el suavizado elimina el zigzag de las diagonales', () {
    // Rombo: sus cuatro lados son diagonales de píxeles (escalera pura).
    final img.Image diamond = _canvas(60);
    for (int y = 0; y < 60; y++) {
      for (int x = 0; x < 60; x++) {
        if ((x - 30).abs() + (y - 30).abs() <= 20) {
          diamond.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }

    final PlotResult sharp = generator.generate(
      _job(
        diamond,
        settings: const PlotSettings(
          widthMm: 60,
          pixelMm: 1,
          simplifyMm: 0,
          smoothMm: 0,
        ),
      ),
    );
    final PlotResult smooth = generator.generate(
      _job(
        diamond,
        settings: const PlotSettings(
          widthMm: 60,
          pixelMm: 1,
          simplifyMm: 0,
          smoothMm: 2,
        ),
      ),
    );

    expect(smooth.paths, 1);
    // El suavizado reduce drásticamente los cambios de dirección.
    expect(_turnSum(smooth.gcode), lessThan(_turnSum(sharp.gcode) * 0.7));
  });

  test('la vista previa es un PNG del tamaño de la rejilla', () {
    final PlotResult result = generator.generate(
      _job(
        _squareAt(40, 20),
        settings: const PlotSettings(widthMm: 40, pixelMm: 1),
      ),
    );

    expect(result.previewPng.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
    final img.Image preview = img.decodeImage(result.previewPng)!;
    expect(preview.width, 40);
    expect(preview.height, 40);
  });
}
