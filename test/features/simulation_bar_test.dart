import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/features/viewer/simulation_controller.dart';
import 'package:grbl_app/features/viewer/viewer_controller.dart';
import 'package:grbl_app/features/viewer/widgets/simulation_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_serial_port.dart';

void main() {
  late FakeSerialPort port;
  late GrblWorkerClient client;
  late AppDatabase database;
  late ProviderContainer container;

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

  SimulationUiState state() => container.read(simulationControllerProvider);

  Future<void> pumpBar(WidgetTester tester) async {
    container
        .read(viewerControllerProvider.notifier)
        .loadText(
          'G21\nG90\nG1 X10 Y0 F600\nG1 X10 Y10 F600\n',
          fileName: 'sim.gcode',
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SimulationBar(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('reproduce, pausa y avanza bloque a bloque', (
    WidgetTester tester,
  ) async {
    await pumpBar(tester);

    expect(find.byTooltip('Reproducir simulación'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(state().playing, isFalse);

    await tester.tap(find.byTooltip('Reproducir simulación'));
    await tester.pump();
    expect(state().playing, isTrue);

    // El ticker arranca en el fotograma siguiente: 300 ms reales son 300 ms de
    // programa (velocidad 1×).
    await tester.pump(const Duration(milliseconds: 300));
    expect(state().seconds, greaterThan(0.2));
    expect(state().seconds, lessThan(0.5));

    await tester.tap(find.byTooltip('Pausar simulación'));
    await tester.pump();
    expect(state().playing, isFalse);
    final double paused = state().seconds;

    await tester.pump(const Duration(milliseconds: 400));
    expect(state().seconds, paused);

    await tester.tap(find.byTooltip('Bloque siguiente'));
    await tester.pump();
    expect(state().seconds, closeTo(1, 1e-9));
    expect(state().cursor!.segmentIndex, 1);

    await tester.tap(find.byTooltip('Bloque anterior'));
    await tester.pump();
    expect(state().seconds, closeTo(0, 1e-9));
  });

  testWidgets('la velocidad elegida multiplica el reloj', (
    WidgetTester tester,
  ) async {
    await pumpBar(tester);

    await tester.tap(find.byTooltip('Velocidad de simulación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4×').last);
    await tester.pumpAndSettle();
    expect(state().speed, 4);

    await tester.tap(find.byTooltip('Reproducir simulación'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 200 ms reales a 4× ≈ 800 ms de programa (el primer tick solo arranca el
    // cronómetro).
    expect(state().seconds, greaterThan(0.7));
    expect(state().seconds, lessThan(1.9));
  });

  testWidgets('cabe en una pantalla de móvil sin desbordar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpBar(tester);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Reproducir simulación'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
