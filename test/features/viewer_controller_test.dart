import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/features/viewer/viewer_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  ViewerController controller() =>
      container.read(viewerControllerProvider.notifier);
  ViewerUiState state() => container.read(viewerControllerProvider);

  test('carga un programa válido y guarda el nombre del archivo', () {
    controller().loadText(
      'G21\nG90\nG1 X10 Y0 F500\nG1 X10 Y10',
      fileName: 'pieza.gcode',
    );

    expect(state().hasProgram, isTrue);
    expect(state().fileName, 'pieza.gcode');
    expect(state().program!.blockCount, 2);
    expect(state().error, isNull);
  });

  test('rechaza un programa sin movimientos', () {
    controller().loadText('G21\nG90\nM4 S500');

    expect(state().hasProgram, isFalse);
    expect(state().error, contains('no contiene movimientos'));
  });

  test('el ejemplo incluye arcos y se carga completo', () {
    controller().loadExample();

    expect(state().hasProgram, isTrue);
    expect(state().program!.arcCount, 5);
    expect(state().program!.warnings, isEmpty);
    expect(state().fileName, 'ejemplo.gcode');
  });

  test('cerrar descarta el programa y el nombre', () {
    controller().loadExample();

    controller().clear();

    expect(state().program, isNull);
    expect(state().fileName, isNull);
    expect(state().hasProgram, isFalse);
  });

  test('reportError deja el mensaje visible', () {
    controller().reportError('No se pudo abrir');

    expect(state().error, 'No se pudo abrir');
    expect(state().isLoading, isFalse);
  });
}
