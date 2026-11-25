import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/axis.dart';
import 'package:grbl_app/domain/entities/jog_command.dart';

void main() {
  group('JogCommand', () {
    test('construye un jog relativo con F obligatorio', () {
      final JogCommand command = JogCommand(
        values: <MachineAxis, double>{MachineAxis.x: 1, MachineAxis.y: -0.5},
        feedMmMin: 500,
      );

      expect(command.build(), r'$J=G91 X1.000 Y-0.500 F500.000');
    });

    test('omite los ejes sin desplazamiento y respeta el orden X,Y,Z', () {
      final JogCommand command = JogCommand(
        values: <MachineAxis, double>{
          MachineAxis.z: 2,
          MachineAxis.x: 0,
          MachineAxis.y: -3,
        },
        feedMmMin: 300,
      );

      expect(command.build(), r'$J=G91 Y-3.000 Z2.000 F300.000');
    });

    test('el modo absoluto de máquina usa G90 G53', () {
      final JogCommand command = JogCommand(
        values: <MachineAxis, double>{MachineAxis.y: 5},
        feedMmMin: 300,
        mode: JogMode.absoluteMachine,
      );

      expect(command.build(), r'$J=G90 G53 Y5.000 F300.000');
    });

    test('el modo relativo nunca incluye G53', () {
      final JogCommand command = JogCommand(
        values: <MachineAxis, double>{MachineAxis.x: 5},
        feedMmMin: 300,
      );

      expect(command.build(), isNot(contains('G53')));
      expect(command.build(), contains('G91'));
    });

    test('valida ejes y avance antes de construir', () {
      final JogCommand empty = JogCommand(
        values: const <MachineAxis, double>{},
        feedMmMin: 0,
      );

      expect(empty.validate(), hasLength(2));
      expect(empty.isValid, isFalse);
      expect(() => empty.build(), throwsArgumentError);
    });

    test('un eje con 0 no cuenta como desplazamiento', () {
      final JogCommand zero = JogCommand(
        values: <MachineAxis, double>{MachineAxis.x: 0},
        feedMmMin: 500,
      );

      expect(zero.isValid, isFalse);
      expect(() => zero.build(), throwsArgumentError);
    });

    test('los valores son inmutables', () {
      final JogCommand command = JogCommand(
        values: <MachineAxis, double>{MachineAxis.x: 1},
        feedMmMin: 500,
      );

      expect(() => command.values[MachineAxis.x] = 99, throwsUnsupportedError);
    });
  });
}
