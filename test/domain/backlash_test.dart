import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/services/backlash_compensator.dart';
import 'package:grbl_app/domain/services/backlash_estimate.dart';

void main() {
  group('BacklashCompensator', () {
    const BacklashCompensator compensator = BacklashCompensator(
      backlashXmm: 0.3,
      backlashYmm: 0.2,
    );

    test('inyecta un movimiento real al invertir el sentido en X', () {
      final BacklashCompensationResult result = compensator.process(<String>[
        'G21',
        'G90',
        'G1 X10.000 Y0.000 F500.000',
        'G1 X0.000 Y0.000 F500.000',
      ]);

      expect(result.compensationsX, 1);
      expect(result.compensationsY, 0);
      expect(result.gcode, contains('G1 X9.700 F500.000'));
      final int index = result.gcode.indexOf('G1 X9.700 F500.000');
      expect(result.gcode[index + 1], 'G1 X0.000 Y0.000 F500.000');
      expect(result.total, 1);
    });

    test('compensa X e Y en un cuadrado', () {
      final BacklashCompensationResult result = compensator.process(<String>[
        'G21',
        'G90',
        'G1 X10.000 Y0.000 F500.000',
        'G1 X10.000 Y10.000 F500.000',
        'G1 X0.000 Y10.000 F500.000',
        'G1 X0.000 Y0.000 F500.000',
      ]);

      expect(result.compensationsX, 1);
      expect(result.compensationsY, 1);
      expect(result.gcode, contains('G1 X9.700 F500.000'));
      expect(result.gcode, contains('G1 Y9.800 F500.000'));
      expect(result.toString(), contains('2 compensaciones'));
    });

    test('no toca nada si el programa no invierte el sentido', () {
      final List<String> program = <String>[
        'G21',
        'G90',
        'G1 X0.000 Y0.000 F500.000',
        'G1 X5.000 Y0.000 F500.000',
        'G1 X10.000 Y0.000 F500.000',
      ];

      final BacklashCompensationResult result = compensator.process(program);

      expect(result.total, 0);
      expect(result.gcode, program);
    });

    test('con holgura cero el programa sale idéntico', () {
      const BacklashCompensator none = BacklashCompensator(
        backlashXmm: 0,
        backlashYmm: 0,
      );

      final BacklashCompensationResult result = none.process(<String>[
        'G1 X10 F500',
        'G1 X0 F500',
      ]);

      expect(result.total, 0);
      expect(result.gcode, <String>['G1 X10 F500', 'G1 X0 F500']);
    });

    test('nunca compensa Z aunque invierta el sentido', () {
      final BacklashCompensationResult result = compensator.process(<String>[
        'G1 Z-1.000 F200',
        'G1 Z-3.000 F200',
        'G1 Z-1.000 F200',
        'G1 Z-5.000 F200',
      ]);

      expect(result.total, 0);
    });

    test('usa el avance de la línea y, si falta, el de reserva', () {
      final BacklashCompensationResult result = compensator.process(<String>[
        'G1 X10.000 F400.000',
        'G1 X0.000',
      ]);

      // La segunda línea no trae F: se reutiliza el último programado.
      expect(result.gcode, contains('G1 X9.700 F400.000'));
    });

    test('usa el avance de reserva si el programa aún no fijó F', () {
      const BacklashCompensator custom = BacklashCompensator(
        backlashXmm: 0.5,
        backlashYmm: 0,
        fallbackFeedMmMin: 250,
      );

      final BacklashCompensationResult result = custom.process(<String>[
        'G1 X10.000',
        'G1 X0.000',
      ]);

      expect(result.gcode, contains('G1 X9.500 F250.000'));
    });

    test('respeta comentarios, líneas vacías y comandos modales', () {
      final List<String> program = <String>[
        '; cabecera',
        '',
        'G21',
        'G90',
        'M4 S500',
        'G1 X10.000 F500.000',
        'G1 X0.000 F500.000',
      ];

      final BacklashCompensationResult result = compensator.process(program);

      expect(result.gcode.take(5), program.take(5));
      expect(result.compensationsX, 1);
    });

    test('la primera aparición de un eje no compensa', () {
      // No se sabe en qué estado quedó la holgura antes del programa.
      final BacklashCompensationResult result = compensator.process(<String>[
        'G1 X-10.000 F500.000',
      ]);

      expect(result.total, 0);
    });
  });

  group('BacklashEstimate', () {
    test('calcula la holgura a partir de la ida y la vuelta', () {
      const BacklashEstimate estimate = BacklashEstimate(
        commandedMm: 5,
        measuredMm: 4.8,
      );

      expect(estimate.backlashMm, closeTo(0.2, 1e-9));
      expect(estimate.toProfileValue(), '0.200');
      expect(estimate.isValid, isTrue);
    });

    test('rechaza una medición mayor que lo ordenado', () {
      const BacklashEstimate estimate = BacklashEstimate(
        commandedMm: 5,
        measuredMm: 5.4,
      );

      expect(estimate.isValid, isFalse);
      expect(estimate.validate().single, contains('supera lo ordenado'));
    });

    test('rechaza holguras desproporcionadas', () {
      const BacklashEstimate estimate = BacklashEstimate(
        commandedMm: 5,
        measuredMm: 2,
      );

      expect(estimate.isValid, isFalse);
      expect(estimate.validate().single, contains('50 %'));
    });

    test('rechaza distancias no positivas', () {
      expect(
        const BacklashEstimate(commandedMm: 0, measuredMm: 0).validate(),
        isNotEmpty,
      );
      expect(
        const BacklashEstimate(commandedMm: 5, measuredMm: -1).validate(),
        isNotEmpty,
      );
    });
  });
}
