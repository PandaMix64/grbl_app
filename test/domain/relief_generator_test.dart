import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/services/relief_generator.dart';
import 'package:image/image.dart' as img;

Uint8List _encode(img.Image image) => Uint8List.fromList(img.encodePng(image));

img.Image _solid(int value, {int width = 20, int height = 10}) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return image;
}

ReliefJob _job(
  img.Image image, {
  ReliefSettings settings = const ReliefSettings(),
}) {
  return ReliefJob(bytes: _encode(image), settings: settings);
}

void main() {
  const ReliefGenerator generator = ReliefGenerator();

  test('un gris claro se fresa solo en el primer nivel', () {
    final ReliefResult result = generator.generate(
      _job(
        _solid(230),
        settings: const ReliefSettings(
          widthMm: 20,
          pixelMm: 1,
          levels: 4,
          maxDepthMm: 4,
          passDepthMm: 4,
          rpm: 8000,
        ),
      ),
    );

    expect(result.gcode, contains('G1 Z-1.000'));
    expect(result.gcode, isNot(contains('G1 Z-2.000')));
    expect(result.gcode, contains('G21'));
    expect(result.gcode, contains('G90'));
    expect(result.gcode, contains('M3 S8000'));
    expect(result.gcode, contains('M5'));
    expect(result.gcode, contains('G0 Z2.000'));
  });

  test('el negro llega a la profundidad máxima', () {
    final ReliefResult result = generator.generate(
      _job(
        _solid(0),
        settings: const ReliefSettings(
          widthMm: 20,
          pixelMm: 1,
          levels: 4,
          maxDepthMm: 4,
          passDepthMm: 4,
        ),
      ),
    );

    expect(result.gcode, contains('G1 Z-4.000'));
    expect(result.cutCells, 200);
    expect(result.cutRatio, 1);
  });

  test('reparte la profundidad en varias pasadas', () {
    final ReliefResult result = generator.generate(
      _job(
        _solid(0),
        settings: const ReliefSettings(
          widthMm: 20,
          pixelMm: 1,
          levels: 2,
          maxDepthMm: 2,
          passDepthMm: 0.5,
        ),
      ),
    );

    // Nivel 2 (fondo): 2 mm en pasadas de 0.5 → incluye -1.5.
    expect(result.gcode, contains('G1 Z-1.500'));
    expect(result.gcode, contains('G1 Z-2.000'));
  });

  test('invertir convierte el blanco en profundidad máxima', () {
    final ReliefResult result = generator.generate(
      _job(
        _solid(255),
        settings: const ReliefSettings(
          widthMm: 20,
          pixelMm: 1,
          levels: 4,
          maxDepthMm: 4,
          passDepthMm: 4,
          invert: true,
        ),
      ),
    );

    expect(result.gcode, contains('G1 Z-4.000'));
  });

  test('una imagen clara sin invertir se rechaza', () {
    expect(
      () => generator.generate(
        _job(
          _solid(255),
          settings: const ReliefSettings(widthMm: 20, pixelMm: 1),
        ),
      ),
      throwsA(
        isA<ReliefException>().having(
          (ReliefException e) => e.message,
          'message',
          contains('nada que fresar'),
        ),
      ),
    );
  });

  test('la vista previa cuantiza la altura', () {
    final ReliefResult result = generator.generate(
      _job(
        _solid(0, width: 20, height: 10),
        settings: const ReliefSettings(widthMm: 20, pixelMm: 1, levels: 4),
      ),
    );

    expect(result.previewPng.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
    final img.Image preview = img.decodeImage(result.previewPng)!;
    expect(preview.width, 20);
    expect(preview.height, 10);
    // Negro = lo más profundo.
    expect(preview.getPixel(0, 0).r.toInt(), 0);
  });

  test('valida niveles y pasadas', () {
    expect(
      () => generator.generate(
        _job(_solid(0), settings: const ReliefSettings(levels: 20)),
      ),
      throwsA(isA<ReliefException>()),
    );
    expect(
      () => generator.generate(
        _job(
          _solid(0),
          settings: const ReliefSettings(maxDepthMm: 1, passDepthMm: 2),
        ),
      ),
      throwsA(isA<ReliefException>()),
    );
  });
}
