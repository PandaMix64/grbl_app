import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/domain/entities/machine_profile.dart';
import 'package:grbl_app/domain/services/contour_generator.dart';
import 'package:grbl_app/domain/services/engraving_generator.dart';
import 'package:grbl_app/features/cam/cam_controller.dart';
import 'package:grbl_app/features/viewer/viewer_controller.dart';
import 'package:image/image.dart' as img;

import '../helpers/fake_serial_port.dart';

Uint8List _blackImage({int width = 10, int height = 10}) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(0, 0, 0));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  late FakeSerialPort port;
  late GrblWorkerClient client;
  late AppDatabase database;
  late ProviderContainer container;

  const MachineProfile laserProfile = MachineProfile(
    id: 'laser',
    name: 'Láser 3018',
    tool: ToolType.laser,
    travelXmm: 300,
    travelYmm: 180,
    travelZmm: 45,
    maxSpindleRpm: 1000,
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

  CamController controller() => container.read(camControllerProvider.notifier);
  CamUiState state() => container.read(camControllerProvider);

  Future<void> useProfile(MachineProfile profile) async {
    await database.upsertProfile(profile);
    container.read(activeProfileIdProvider.notifier).select(profile.id);
    await container.read(activeProfileProvider.future);
  }

  test('genera G-code con perfil láser y lo envía al visor', () async {
    await useProfile(laserProfile);
    controller().loadImage(_blackImage(), 'logo.png');

    await controller().generate(
      const EngravingSettings(
        widthMm: 10,
        pixelMm: 1,
        mode: EngravingMode.grayscale,
      ),
    );

    expect(state().error, isNull);
    expect(state().engraveResult, isNotNull);
    expect(state().engraveResult!.litCells, 100);
    expect(state().message, contains('G-code generado'));

    controller().sendToViewer();

    final ViewerUiState viewer = container.read(viewerControllerProvider);
    expect(viewer.fileName, 'logo_grabado.gcode');
    expect(viewer.source, contains('M4'));
    expect(viewer.hasProgram, isTrue);
    expect(state().message, contains('Visor'));
  });

  test('exige un perfil y que sea láser', () async {
    controller().loadImage(_blackImage(), 'logo.png');

    await controller().generate(const EngravingSettings());
    expect(state().error, contains('perfil'));

    await useProfile(
      laserProfile.copyWith(tool: ToolType.mill, name: 'Fresadora'),
    );
    await controller().generate(const EngravingSettings());
    expect(state().error, contains('láser'));
  });

  test('rechaza grabados que exceden el recorrido del perfil', () async {
    await useProfile(laserProfile);
    controller().loadImage(_blackImage(), 'logo.png');

    await controller().generate(
      const EngravingSettings(widthMm: 400, pixelMm: 1),
    );

    expect(state().engraveResult, isNull);
    expect(state().error, contains('excede'));
  });

  test('sin imagen avisa en lugar de generar', () async {
    await useProfile(laserProfile);

    await controller().generate(const EngravingSettings());

    expect(state().error, contains('imagen'));
  });

  test('genera un contorno y lo envía al visor', () async {
    await useProfile(laserProfile);
    controller().loadImage(_blackImage(), 'logo.png');
    controller().setOperation(CamOperation.contour);

    await controller().generateContour(
      const ContourSettings(widthMm: 10, pixelMm: 1, power: 800),
    );

    expect(state().error, isNull, reason: state().error);
    expect(state().contourResult, isNotNull);
    expect(state().contourResult!.loops, greaterThanOrEqualTo(1));
    expect(state().message, contains('Contorno generado'));
    expect(state().previewPng, isNotNull);

    controller().sendToViewer();

    final ViewerUiState viewer = container.read(viewerControllerProvider);
    expect(viewer.fileName, 'logo_contorno.gcode');
    expect(viewer.source, contains('G90'));
    expect(viewer.hasProgram, isTrue);
  });

  test('el contorno con láser exige perfil láser', () async {
    await useProfile(
      laserProfile.copyWith(tool: ToolType.mill, name: 'Fresadora'),
    );
    controller().loadImage(_blackImage(), 'logo.png');
    controller().setOperation(CamOperation.contour);

    await controller().generateContour(const ContourSettings());

    expect(state().contourResult, isNull);
    expect(state().error, contains('láser'));
  });

  test('cambiar de operación descarta el resultado anterior', () async {
    await useProfile(laserProfile);
    controller().loadImage(_blackImage(), 'logo.png');
    await controller().generate(
      const EngravingSettings(widthMm: 10, pixelMm: 1),
    );
    expect(state().engraveResult, isNotNull);

    controller().setOperation(CamOperation.contour);

    expect(state().engraveResult, isNull);
    expect(state().contourResult, isNull);
    expect(state().hasResult, isFalse);
  });
}
