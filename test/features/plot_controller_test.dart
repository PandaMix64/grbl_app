import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/domain/entities/machine_profile.dart';
import 'package:grbl_app/domain/services/plot_generator.dart';
import 'package:grbl_app/features/plot/plot_controller.dart';
import 'package:grbl_app/features/viewer/viewer_controller.dart';
import 'package:image/image.dart' as img;

import '../helpers/fake_serial_port.dart';

Uint8List _squareImage({int size = 20, int inner = 10}) {
  final img.Image image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  final int from = (size - inner) ~/ 2;
  for (int y = from; y < from + inner; y++) {
    for (int x = from; x < from + inner; x++) {
      image.setPixelRgb(x, y, 0, 0, 0);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  late FakeSerialPort port;
  late GrblWorkerClient client;
  late AppDatabase database;
  late ProviderContainer container;

  const MachineProfile plotter = MachineProfile(
    id: 'plotter',
    name: 'Plóter A3',
    tool: ToolType.plotter,
    travelXmm: 400,
    travelYmm: 300,
    travelZmm: 40,
    defaultFeedMmMin: 1200,
  );

  setUp(() {
    port = FakeSerialPort();
    client = GrblWorkerClient.inProcess(port: port);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        grblWorkerProvider.overrideWith((Ref ref) => client),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await client.dispose();
    await database.close();
  });

  PlotController controller() =>
      container.read(plotControllerProvider.notifier);
  PlotUiState state() => container.read(plotControllerProvider);

  Future<void> useProfile(MachineProfile profile) async {
    await database.upsertProfile(profile);
    container.read(activeProfileIdProvider.notifier).select(profile.id);
    await container.read(activeProfileProvider.future);
  }

  test('traza rutas vectoriales y las envía al visor', () async {
    await useProfile(plotter);
    controller().loadImage(_squareImage(), 'dibujo.png');

    await controller().generate(
      const PlotSettings(widthMm: 20, pixelMm: 1, simplifyMm: 0.3),
    );

    expect(state().error, isNull, reason: state().error);
    expect(state().result, isNotNull);
    expect(state().result!.mode, PlotMode.vector);
    expect(state().message, contains('Trazado generado'));

    controller().sendToViewer();
    expect(
      container.read(viewerControllerProvider).fileName,
      'dibujo_trazado.gcode',
    );
  });

  test('genera bordado raster', () async {
    await useProfile(plotter);
    controller().loadImage(_squareImage(), 'dibujo.png');

    await controller().generate(
      const PlotSettings(
        widthMm: 20,
        pixelMm: 1,
        mode: PlotMode.hatch,
        hatchSpacingMm: 4,
      ),
    );

    expect(state().result!.mode, PlotMode.hatch);
    expect(state().result!.paths, greaterThanOrEqualTo(3));
  });

  test('rechaza dibujos que exceden el recorrido y exige perfil', () async {
    controller().loadImage(_squareImage(), 'dibujo.png');
    await controller().generate(const PlotSettings(widthMm: 20, pixelMm: 1));
    expect(state().error, contains('perfil'));

    await useProfile(plotter);
    await controller().generate(const PlotSettings(widthMm: 500, pixelMm: 1));
    expect(state().result, isNull);
    expect(state().error, contains('excede'));
  });

  test('sin imagen avisa en lugar de generar', () async {
    await useProfile(plotter);

    await controller().generate(const PlotSettings());

    expect(state().error, contains('imagen'));
  });
}
