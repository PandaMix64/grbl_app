import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/gcode_program.dart';
import 'package:grbl_app/domain/entities/motion_segment.dart';
import 'package:grbl_app/domain/services/simulation_timeline.dart';
import 'package:grbl_app/features/viewer/view_projection.dart';
import 'package:grbl_app/features/viewer/preview_visibility.dart';
import 'package:grbl_app/features/viewer/program_painter.dart';
import 'package:grbl_app/features/viewer/simulation_controller.dart';
import 'package:grbl_app/features/viewer/simulation_painter.dart';
import 'package:grbl_app/features/viewer/viewer_controller.dart';
import 'package:grbl_app/features/viewer/widgets/viewer_canvas.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math_64.dart';

const String _square =
    'G21\nG90\nG1 X0 Y0 F600\nG1 X80 Y0\nG1 X80 Y60\nG1 X0 Y60\nG1 X0 Y0';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pumpCanvas(
    WidgetTester tester, {
    String source = _square,
    List<double>? workAreaMm,
  }) async {
    container.read(viewerControllerProvider.notifier).loadText(source);
    final GcodeProgram program = container
        .read(viewerControllerProvider)
        .program!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 300,
                child: ViewerCanvas(program: program, workAreaMm: workAreaMm),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  CustomPaint canvasPaint(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(const Key('viewer-canvas')));

  ProgramPainter programPainter(WidgetTester tester) =>
      canvasPaint(tester).painter! as ProgramPainter;

  testWidgets('la estela comparte lienzo y proyección con la trayectoria', (
    WidgetTester tester,
  ) async {
    await pumpCanvas(tester);
    container.read(simulationControllerProvider.notifier).seekFraction(0.6);
    await tester.pump();

    final CustomPaint paint = canvasPaint(tester);
    final ProgramPainter program = programPainter(tester);
    final SimulationPainter simulation =
        paint.foregroundPainter! as SimulationPainter;

    // Una sola capa de dibujo: no hay `CustomPaint` aparte para la simulación,
    // así que no puede desfasarse de la trayectoria.
    expect(find.byKey(const Key('viewer-simulation')), findsNothing);

    // El cabezal simulado cae exactamente donde la proyección del programa sitúa
    // al cursor: la simulación va sobre el recorrido, mismo origen.
    final SimulationCursor cursor = container
        .read(simulationControllerProvider)
        .cursor!;
    final Vector2 expected = program.projection.project(cursor.position);
    expect(simulation.trail.head, isNotNull);
    expect(
      (simulation.trail.head! - Offset(expected.x, expected.y)).distance,
      lessThan(0.01),
    );
    expect(simulation.trail.segmentsDone, cursor.segmentIndex);
  });

  testWidgets('los conmutadores apagan cada previsualización', (
    WidgetTester tester,
  ) async {
    await pumpCanvas(tester);
    expect(container.read(previewVisibilityProvider).showSimulation, isTrue);
    expect(canvasPaint(tester).foregroundPainter, isNotNull);

    container.read(previewVisibilityProvider.notifier).toggleSimulation();
    await tester.pump();
    expect(container.read(previewVisibilityProvider).showSimulation, isFalse);
    expect(canvasPaint(tester).foregroundPainter, isNull);

    container.read(previewVisibilityProvider.notifier).toggleExecution();
    await tester.pump();
    final ProgramPainter program = programPainter(tester);
    expect(container.read(previewVisibilityProvider).showExecution, isFalse);
    expect(program.headPosition, isNull);
    expect(program.executedUpToLine, isNull);
  });

  testWidgets('la trayectoria no se reproyecta en cada fotograma', (
    WidgetTester tester,
  ) async {
    await pumpCanvas(tester);
    final ProgramBatches? first = programPainter(tester).batches;
    expect(first, isNotNull);

    // Avanzar la simulación fuerza un fotograma completo del lienzo.
    container.read(simulationControllerProvider.notifier).seekFraction(0.4);
    await tester.pump();
    final ProgramBatches? second = programPainter(tester).batches;

    // Repintar con lotes cacheados es O(1): no se recorren los segmentos.
    expect(identical(first, second), isTrue);
    expect(identical(first!.cutting, second!.cutting), isTrue);
  });

  testWidgets('el encuadre incluye la cama y el recorrido', (
    WidgetTester tester,
  ) async {
    // Programa pequeño cerca del origen con una cama mucho mayor: sin encuadre
    // compartido, la cama quedaba fuera de la vista.
    await pumpCanvas(
      tester,
      source: 'G21\nG90\nG1 X0 Y0 F600\nG1 X60 Y0\nG1 X60 Y40',
      workAreaMm: <double>[400, 300, 40],
    );

    final ProgramPainter painter = programPainter(tester);
    final ViewProjection projection = painter.projection;
    const double halfWidth = 400 / 2;
    const double halfHeight = 300 / 2;

    // Las cuatro esquinas de la cama, abajo y arriba, dentro del lienzo.
    for (final double x in <double>[0, 400]) {
      for (final double y in <double>[0, 300]) {
        for (final double z in <double>[0, 40]) {
          final Vector2 p = projection.project(Vector3(x, y, z));
          expect(p.x.abs(), lessThan(halfWidth), reason: 'cama ($x,$y,$z)');
          expect(p.y.abs(), lessThan(halfHeight), reason: 'cama ($x,$y,$z)');
        }
      }
    }
    // Y el programa, en el mismo sistema de referencia.
    for (final MotionSegment segment in painter.program.segments) {
      for (final Vector3 point in <Vector3>[segment.start, segment.end]) {
        final Vector2 p = projection.project(point);
        expect(p.x.abs(), lessThan(halfWidth));
        expect(p.y.abs(), lessThan(halfHeight));
      }
    }
  });
}
