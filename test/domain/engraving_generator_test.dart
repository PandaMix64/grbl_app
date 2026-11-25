import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/services/engraving_generator.dart';
import 'package:image/image.dart' as img;

Uint8List _encode(img.Image image) => Uint8List.fromList(img.encodePng(image));

img.Image _halfBlack(int width, int height) {
  final img.Image image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int value = x < width ~/ 2 ? 0 : 255;
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return image;
}

img.Image _solid(int value, {int width = 20, int height = 20}) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return image;
}

EngravingJob _job(
  img.Image image, {
  EngravingSettings settings = const EngravingSettings(),
}) {
  return EngravingJob(bytes: _encode(image), settings: settings);
}

void main() {
  const EngravingGenerator generator = EngravingGenerator();

  test('genera cabecera de láser y respeta la rejilla', () {
    final EngravingResult result = generator.generate(
      _job(
        _halfBlack(40, 20),
        settings: const EngravingSettings(
          widthMm: 40,
          pixelMm: 1,
          maxPower: 800,
          feedMmMin: 900,
        ),
      ),
    );

    expect(result.columns, 40);
    expect(result.rows, 20);
    expect(result.widthMm, 40);
    expect(result.heightMm, 20);
    // Mitad izquierda negra: 20 columnas × 20 filas.
    expect(result.litCells, 400);
    expect(result.gcode, contains('G21'));
    expect(result.gcode, contains('G90'));
    expect(result.gcode, contains('M4'));
    expect(result.gcode, contains('F900'));
    expect(result.gcode, contains('S800'));
    expect(result.gcode.trimRight(), endsWith('; fin del grabado'));
  });

  test('la fila superior de la imagen queda en el Y máximo', () {
    final EngravingResult result = generator.generate(
      _job(
        _solid(0, width: 10, height: 10),
        settings: const EngravingSettings(widthMm: 10, pixelMm: 1),
      ),
    );

    final List<String> moves = result.gcode
        .split('\n')
        .where((String line) => line.startsWith('G0 X') && line.endsWith(' S0'))
        .toList();
    // Primera pasada en Y=9.5 (borde superior) y última en Y=0.5.
    expect(moves.first, contains('Y9.500'));
    expect(moves.last, contains('Y0.500'));
  });

  test('la escala de grises proporcional la potencia', () {
    final EngravingResult result = generator.generate(
      _job(
        _solid(128, width: 10, height: 10),
        settings: const EngravingSettings(
          widthMm: 10,
          pixelMm: 1,
          mode: EngravingMode.grayscale,
          maxPower: 800,
        ),
      ),
    );

    // El gris medio debe quedar cerca de la mitad de la potencia (la conversión
    // a escala de grises puede redondear ±1 nivel).
    expect(result.gcode, contains(RegExp(r' S(39\d|40\d|41\d)\n')));
    expect(result.litCells, 100);
  });

  test('el tramado es determinista y enciende cerca de la mitad', () {
    final EngravingJob job = _job(
      _solid(128),
      settings: const EngravingSettings(
        widthMm: 20,
        pixelMm: 1,
        mode: EngravingMode.dither,
      ),
    );

    final EngravingResult first = generator.generate(job);
    final EngravingResult second = generator.generate(job);

    expect(first.gcode, second.gcode);
    expect(first.litRatio, closeTo(0.5, 0.15));
  });

  test('invertir cambia las celdas grabadas', () {
    final EngravingResult normal = generator.generate(
      _job(
        _halfBlack(20, 20),
        settings: const EngravingSettings(widthMm: 20, pixelMm: 1),
      ),
    );
    final EngravingResult inverted = generator.generate(
      _job(
        _halfBlack(20, 20),
        settings: const EngravingSettings(
          widthMm: 20,
          pixelMm: 1,
          invert: true,
        ),
      ),
    );

    expect(normal.litCells, 200);
    expect(inverted.litCells, 200);
    expect(normal.gcode, isNot(inverted.gcode));
  });

  test('la vista previa muestra las celdas que se queman', () {
    final EngravingResult result = generator.generate(
      _job(
        _halfBlack(20, 20),
        settings: const EngravingSettings(widthMm: 20, pixelMm: 1),
      ),
    );

    expect(result.previewPng, isNotEmpty);
    // Firma PNG.
    expect(result.previewPng.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);

    final img.Image preview = img.decodeImage(result.previewPng)!;
    expect(preview.width, 20);
    expect(preview.height, 20);
    // Mitad izquierda quemada (negro), derecha intacta (blanco).
    expect(preview.getPixel(0, 0).r.toInt(), 0);
    expect(preview.getPixel(19, 19).r.toInt(), 255);
  });

  test('rechaza una rejilla desmesurada', () {
    expect(
      () => generator.generate(
        _job(
          _solid(0, width: 100, height: 100),
          settings: const EngravingSettings(widthMm: 500, pixelMm: 0.05),
        ),
      ),
      throwsA(
        isA<EngravingException>().having(
          (EngravingException e) => e.message,
          'message',
          contains('celdas'),
        ),
      ),
    );
  });

  test('rechaza parámetros inválidos y bytes ilegibles', () {
    expect(
      () => generator.generate(
        _job(_solid(0), settings: const EngravingSettings(pixelMm: 0)),
      ),
      throwsA(isA<EngravingException>()),
    );
    expect(
      () => generator.generate(
        EngravingJob(
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          settings: const EngravingSettings(),
        ),
      ),
      throwsA(
        isA<EngravingException>().having(
          (EngravingException e) => e.message,
          'message',
          contains('decodificar'),
        ),
      ),
    );
  });
}
