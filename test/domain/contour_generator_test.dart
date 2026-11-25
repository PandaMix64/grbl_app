import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/services/contour_generator.dart';
import 'package:image/image.dart' as img;

Uint8List _encode(img.Image image) => Uint8List.fromList(img.encodePng(image));

img.Image _canvas(int size, {int value = 255}) {
  final img.Image image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return image;
}

/// Cuadrado negro centrado de `inner` × `inner` píxeles.
img.Image _square(int size, int inner) {
  final img.Image image = _canvas(size);
  final int from = (size - inner) ~/ 2;
  for (int y = from; y < from + inner; y++) {
    for (int x = from; x < from + inner; x++) {
      image.setPixelRgb(x, y, 0, 0, 0);
    }
  }
  return image;
}

/// Anillo: cuadrado negro con un hueco blanco dentro.
img.Image _ring(int size, int outer, int hole) {
  final img.Image image = _square(size, outer);
  final int from = (size - hole) ~/ 2;
  for (int y = from; y < from + hole; y++) {
    for (int x = from; x < from + hole; x++) {
      image.setPixelRgb(x, y, 255, 255, 255);
    }
  }
  return image;
}

ContourJob _job(
  img.Image image, {
  ContourSettings settings = const ContourSettings(),
}) {
  return ContourJob(bytes: _encode(image), settings: settings);
}

void main() {
  const ContourGenerator generator = ContourGenerator();

  test('vectoriza un cuadrado con láser y cuatro esquinas', () {
    final ContourResult result = generator.generate(
      _job(
        _square(40, 20),
        settings: const ContourSettings(
          widthMm: 40,
          pixelMm: 1,
          power: 1000,
          feedMmMin: 500,
        ),
      ),
    );

    expect(result.loops, 1);
    expect(result.points, inInclusiveRange(4, 6));
    expect(result.passes, 1);
    expect(result.tool, ContourTool.laser);
    expect(result.gcode, contains('G21'));
    expect(result.gcode, contains('G90'));
    expect(result.gcode, contains('M4'));
    expect(result.gcode, contains('G1 S1000'));
    expect(result.gcode, contains('G1 S0'));
    expect(result.gcode, contains('M5'));
    // Cuadrado de (10,10) a (30,30) en mm, con Y invertida respecto a la imagen.
    expect(result.gcode, contains('X10.000'));
    expect(result.gcode, contains('X30.000'));
    expect(result.gcode, contains('Y10.000'));
    expect(result.gcode, contains('Y30.000'));
  });

  test('detecta el hueco interior como segunda vuelta', () {
    final ContourResult result = generator.generate(
      _job(
        _ring(40, 30, 10),
        settings: const ContourSettings(widthMm: 40, pixelMm: 1),
      ),
    );

    expect(result.loops, 2);
  });

  test('el husillo añade pasadas en Z hasta la profundidad final', () {
    final ContourResult result = generator.generate(
      _job(
        _square(40, 20),
        settings: const ContourSettings(
          widthMm: 40,
          pixelMm: 1,
          tool: ContourTool.spindle,
          power: 8000,
          safeZmm: 2,
          cutZmm: -1,
          passDepthMm: 0.5,
        ),
      ),
    );

    expect(result.passes, 2);
    expect(result.gcode, contains('M3 S8000'));
    expect(result.gcode, contains('G0 Z2.000'));
    expect(result.gcode, contains('G1 Z-0.500'));
    expect(result.gcode, contains('G1 Z-1.000'));
  });

  test('las pestañas levantan la Z sobre el nivel de corte', () {
    final ContourResult result = generator.generate(
      _job(
        _square(60, 40),
        settings: const ContourSettings(
          widthMm: 60,
          pixelMm: 1,
          tool: ContourTool.spindle,
          safeZmm: 2,
          cutZmm: -1,
          passDepthMm: 1,
          tabs: 2,
          tabWidthMm: 4,
          tabHeightMm: 0.8,
        ),
      ),
    );

    expect(result.tabs, 2);
    // Nivel -1 + 0.8 en el centro de cada pestaña.
    expect(result.gcode, contains('G1 Z-0.200'));
  });

  test('en láser las pestañas apagan el haz', () {
    final ContourResult result = generator.generate(
      _job(
        _square(60, 40),
        settings: const ContourSettings(
          widthMm: 60,
          pixelMm: 1,
          tabs: 3,
          tabWidthMm: 4,
        ),
      ),
    );

    final int offs = 'G1 S0'.allMatches(result.gcode).length;
    // Al menos tres apagados por pestañas, más el final de la vuelta.
    expect(offs, greaterThanOrEqualTo(3));
  });

  test('invertir selecciona el fondo como silueta', () {
    final ContourResult normal = generator.generate(
      _job(
        _square(40, 20),
        settings: const ContourSettings(widthMm: 40, pixelMm: 1),
      ),
    );
    final ContourResult inverted = generator.generate(
      _job(
        _square(40, 20),
        settings: const ContourSettings(widthMm: 40, pixelMm: 1, invert: true),
      ),
    );

    expect(normal.gcode, isNot(inverted.gcode));
    expect(inverted.loops, greaterThanOrEqualTo(1));
  });

  test('la vista previa vectorial es un PNG', () {
    final ContourResult result = generator.generate(
      _job(
        _square(40, 20),
        settings: const ContourSettings(widthMm: 40, pixelMm: 1),
      ),
    );

    expect(result.previewPng.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
    final img.Image preview = img.decodeImage(result.previewPng)!;
    expect(preview.width, 40);
    expect(preview.height, 40);
  });

  test('sin silueta o con parámetros inválidos se rechaza', () {
    expect(
      () => generator.generate(
        _job(
          _canvas(20),
          settings: const ContourSettings(widthMm: 20, pixelMm: 1),
        ),
      ),
      throwsA(
        isA<ContourException>().having(
          (ContourException e) => e.message,
          'message',
          contains('silueta'),
        ),
      ),
    );
    expect(
      () => generator.generate(
        _job(_square(20, 10), settings: const ContourSettings(cutZmm: 1)),
      ),
      throwsA(isA<ContourException>()),
    );
    expect(
      () => generator.generate(
        _job(_square(20, 10), settings: const ContourSettings(tabs: 40)),
      ),
      throwsA(isA<ContourException>()),
    );
  });
}
