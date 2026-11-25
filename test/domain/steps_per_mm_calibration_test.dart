import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/services/steps_per_mm_calibration.dart';

void main() {
  group('StepsPerMmCalibration', () {
    test('corrige a partir del avance ordenado y la medida real', () {
      const StepsPerMmCalibration calibration = StepsPerMmCalibration(
        currentStepsPerMm: 250,
        commandedMm: 10,
        measuredMm: 9.8,
      );

      // 250 * 10 / 9.8 = 255.102...
      expect(calibration.newStepsPerMm, closeTo(255.102, 0.001));
      expect(calibration.toGrblValue(), '255.102');
      expect(calibration.correctionFactor, closeTo(1.0204, 0.0001));
      expect(calibration.relativeError, closeTo(-0.02, 0.0001));
      expect(calibration.isValid, isTrue);
    });

    test('si la máquina avanzó de más, reduce los pasos/mm', () {
      const StepsPerMmCalibration calibration = StepsPerMmCalibration(
        currentStepsPerMm: 400,
        commandedMm: 10,
        measuredMm: 10.5,
      );

      expect(calibration.newStepsPerMm, closeTo(380.952, 0.001));
      expect(calibration.relativeError, greaterThan(0));
    });

    test('rechaza valores no positivos', () {
      expect(
        const StepsPerMmCalibration(
          currentStepsPerMm: 0,
          commandedMm: 10,
          measuredMm: 10,
        ).validate(),
        hasLength(1),
      );
      expect(
        const StepsPerMmCalibration(
          currentStepsPerMm: 250,
          commandedMm: 10,
          measuredMm: 0,
        ).validate(),
        hasLength(1),
      );
    });

    test('rechaza medidas fuera del ±50 % (unidad equivocada o patinaje)', () {
      const StepsPerMmCalibration wrongUnit = StepsPerMmCalibration(
        currentStepsPerMm: 250,
        commandedMm: 10,
        measuredMm: 25.4,
      );

      expect(wrongUnit.isValid, isFalse);
      expect(wrongUnit.validate().single, contains('50 %'));
    });
  });
}
