import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/axis.dart';
import 'package:grbl_app/domain/entities/grbl_settings.dart';

void main() {
  const String samplePayload = r'''$0=10
$1=25
$10=1
$20=1
$21=0
$22=1
$30=1000.000
$32=1
$100=250.000
$101=250.000
$102=400.000
$110=500.000
$111=500.000
$112=200.000
$120=10.000
$121=10.000
$122=10.000
$130=200.000
$131=200.000
$132=80.000
ok''';

  group('GrblSettings', () {
    test('parsea la respuesta de la EEPROM ignorando ok y ruido', () {
      final GrblSettings settings = GrblSettings.parse(samplePayload);

      expect(settings.codes.length, 20);
      expect(settings.integer(0), 10);
      expect(settings.number(32), 1);
      expect(settings.rawValue(100), '250.000');
    });

    test('expone los parámetros por eje con el código correcto', () {
      final GrblSettings settings = GrblSettings.parse(samplePayload);

      expect(settings.stepsPerMm(MachineAxis.x), 250);
      expect(settings.stepsPerMm(MachineAxis.z), 400);
      expect(MachineAxis.y.stepsPerMmCode, 101);
      expect(MachineAxis.z.maxTravelCode, 132);
      expect(settings.maxTravel(MachineAxis.z), 80);
      expect(settings.acceleration(MachineAxis.y), 10);
    });

    test('detecta modo láser, soft limits y homing', () {
      final GrblSettings settings = GrblSettings.parse(samplePayload);

      expect(settings.isLaserMode, isTrue);
      expect(settings.softLimitsEnabled, isTrue);
      expect(settings.hardLimitsEnabled, isFalse);
      expect(settings.homingEnabled, isTrue);
    });

    test('formatea enteros y decimales según el código', () {
      final GrblSettings settings = GrblSettings.parse(samplePayload)
          .withValue(100, 80)
          .withValue(20, 0);

      expect(settings.rawValue(100), '80.000');
      expect(settings.rawValue(20), '0');
    });

    test(
      'diff solo devuelve los parámetros que cambian (desgaste de EEPROM)',
      () {
        final GrblSettings current = GrblSettings.parse(samplePayload);
        final GrblSettings target = current
            .withValue(100, 80)
            .withValue(101, 80);

        final Map<int, String> changes = current.diff(target);

        expect(changes.keys, <int>[100, 101]);
        expect(changes[100], '80.000');
      },
    );

    test('toCommands genera bloques de parámetro listos para enviar', () {
      final GrblSettings settings = GrblSettings.empty().withValue(100, 80);

      expect(settings.toCommands(), <String>[r'$100=80.000']);
    });

    test('un conjunto vacío no inventa parámetros', () {
      final GrblSettings settings = GrblSettings.empty();

      expect(settings.codes, isEmpty);
      expect(settings.number(100), isNull);
      expect(settings.isLaserMode, isFalse);
      expect(settings.toCommands(), isEmpty);
    });
  });
}
