import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/features/viewer/simulation_controller.dart';
import 'package:grbl_app/features/viewer/viewer_controller.dart';

const String _program =
    'G21\nG90\nG1 X10 Y0 F600\nG1 X10 Y10 F600\nG1 X0 Y10 F600';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  SimulationController controller() =>
      container.read(simulationControllerProvider.notifier);
  SimulationUiState state() => container.read(simulationControllerProvider);

  void load(String text) =>
      container.read(viewerControllerProvider.notifier).loadText(text);

  test('sin programa no hay nada que reproducir', () {
    expect(state().isReady, isFalse);
    expect(state().totalSeconds, 0);
    expect(state().cursor, isNull);
    controller().play();
    expect(state().playing, isFalse);
  });

  test('al cargar un programa calcula la duración y sitúa el cabezal', () {
    load(_program);

    expect(state().isReady, isTrue);
    // Tres tramos de 10 mm a 600 mm/min = 1 s cada uno.
    expect(state().totalSeconds, closeTo(3, 1e-9));
    expect(state().seconds, 0);
    expect(state().cursor!.segmentIndex, 0);
    expect(state().progress, 0);
    expect(state().line, 3);
  });

  test('reproduce con el reloj y se detiene al final', () {
    load(_program);
    controller().play();
    expect(state().playing, isTrue);

    controller().advance(0.5);
    expect(state().seconds, closeTo(0.5, 1e-9));
    expect(state().cursor!.segmentIndex, 0);
    expect(state().progress, closeTo(0.5 / 3, 1e-9));

    controller().advance(10);
    expect(state().playing, isFalse);
    expect(state().atEnd, isTrue);
    expect(state().seconds, closeTo(3, 1e-9));
    expect(state().cursor!.segmentIndex, 2);

    // Volver a reproducir desde el final empieza otra vez.
    controller().play();
    expect(state().seconds, 0);
    expect(state().playing, isTrue);
  });

  test('la velocidad multiplica el avance del reloj', () {
    load(_program);
    controller().setSpeed(2);
    controller().play();
    controller().advance(0.25);

    expect(state().speed, 2);
    expect(state().seconds, closeTo(0.5, 1e-9));
  });

  test('avanza y retrocede bloque a bloque', () {
    load(_program);

    controller().stepForward();
    expect(state().seconds, closeTo(1, 1e-9));
    expect(state().cursor!.segmentIndex, 1);
    expect(state().playing, isFalse);

    controller().stepForward();
    expect(state().seconds, closeTo(2, 1e-9));

    controller().stepBack();
    expect(state().seconds, closeTo(1, 1e-9));
    controller().stepBack();
    expect(state().seconds, closeTo(0, 1e-9));
    expect(state().cursor!.segmentIndex, 0);
  });

  test('retroceder a mitad de bloque vuelve a su inicio', () {
    load(_program);
    controller().seekTo(0.4);

    controller().stepBack();
    expect(state().seconds, 0);
  });

  test('la línea de tiempo salta a cualquier punto', () {
    load(_program);

    controller().seekFraction(0.5);
    expect(state().seconds, closeTo(1.5, 1e-9));
    expect(state().cursor!.segmentIndex, 1);

    controller().seekFraction(2);
    expect(state().seconds, closeTo(3, 1e-9));
    expect(state().atEnd, isTrue);
  });

  test('un programa nuevo reinicia la posición y conserva la velocidad', () {
    load(_program);
    controller().setSpeed(4);
    controller().play();
    controller().advance(1);
    expect(state().seconds, greaterThan(0));

    load('G21\nG90\nG1 X5 F300');

    expect(state().seconds, 0);
    expect(state().playing, isFalse);
    expect(state().cursor!.segmentIndex, 0);
    expect(state().totalSeconds, closeTo(1, 1e-9));
    expect(state().speed, 4);
  });
}
