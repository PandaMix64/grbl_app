import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/machine_profile.dart';

void main() {
  MachineProfile build() => const MachineProfile(
    id: 'p1',
    name: 'Genmitsu 3018',
    tool: ToolType.laser,
    travelXmm: 300,
    travelYmm: 180,
    travelZmm: 45,
    safeZmm: 10,
    backlashXmm: 0.15,
    backlashYmm: 0.2,
  );

  group('MachineProfile', () {
    test('un perfil coherente es válido', () {
      final MachineProfile profile = build();

      expect(profile.validate(), isEmpty);
      expect(profile.isValid, isTrue);
      expect(profile.usesLaserMode, isTrue);
      expect(profile.hasBacklashCompensation, isTrue);
      expect(profile.travel, <double>[300, 180, 45]);
    });

    test('detecta dimensiones imposibles y altura segura fuera de rango', () {
      final MachineProfile broken = build().copyWith(
        travelXmm: 0,
        safeZmm: 60,
        defaultFeedMmMin: 0,
      );

      final List<String> errors = broken.validate();

      expect(errors, hasLength(3));
      expect(broken.isValid, isFalse);
    });

    test('contiene puntos solo dentro del volumen de trabajo', () {
      final MachineProfile profile = build();

      expect(profile.containsPoint(<double>[0, 0, 0]), isTrue);
      expect(profile.containsPoint(<double>[299.9, 179.9, 44.9]), isTrue);
      expect(profile.containsPoint(<double>[301, 10, 10]), isFalse);
      expect(profile.containsPoint(<double>[10, -1, 10]), isFalse);
      expect(profile.containsPoint(<double>[10, 10]), isFalse);
    });

    test('sobrevive a la serialización JSON', () {
      final MachineProfile profile = build();

      final MachineProfile restored = MachineProfile.fromJson(profile.toJson());

      expect(restored.id, profile.id);
      expect(restored.tool, ToolType.laser);
      expect(restored.travelZmm, 45);
      expect(restored.safeZmm, 10);
      expect(restored.backlashYmm, 0.2);
    });

    test('no inventa dimensiones si faltan en el JSON', () {
      expect(
        () => MachineProfile.fromJson(<String, Object?>{
          'id': 'p1',
          'name': 'Sin medidas',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
