import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/gcode_program.dart';
import 'package:grbl_app/domain/services/simulation_timeline.dart';
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

  Future<void> pumpCanvas(WidgetTester tester) async {
    container.read(viewerControllerProvider.notifier).loadText(_square);
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
                child: ViewerCanvas(program: program),
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

  testWidgets('la estela comparte lienzo y proyección con la trayectoria', (
    WidgetTester tester,
  ) async {
    await pumpCanvas(tester);
    container.read(simulationControllerProvider.notifier).seekFraction(0.6);
    await tester.pump();

    final CustomPaint paint = canvasPaint(tester);
    final ProgramPainter program = paint.painter! as ProgramPainter;
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
    final ProgramPainter program =
        canvasPaint(tester).painter! as ProgramPainter;
    expect(container.read(previewVisibilityProvider).showExecution, isFalse);
    expect(program.headPosition, isNull);
    expect(program.executedUpToLine, isNull);
  });
}
