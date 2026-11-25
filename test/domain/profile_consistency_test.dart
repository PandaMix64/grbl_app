import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/grbl_settings.dart';
import 'package:grbl_app/domain/entities/machine_profile.dart';
import 'package:grbl_app/domain/entities/parser_state.dart';
import 'package:grbl_app/domain/services/profile_consistency.dart';

void main() {
  const MachineProfile profile = MachineProfile(
    id: 'p1',
    name: '3018 láser',
    tool: ToolType.laser,
    travelXmm: 300,
    travelYmm: 180,
    travelZmm: 45,
  );

  GrblSettings settings({
    int laser = 1,
    int softLimits = 1,
    int homing = 1,
    double travelX = 300,
  }) {
    final GrblSettings base = GrblSettings.parse(
      <String>[
        r'$20=1',
        r'$21=0',
        r'$22=1',
        r'$32=1',
        r'$100=250.000',
        r'$101=250.000',
        r'$102=400.000',
        r'$110=500.000',
        r'$111=500.000',
        r'$112=200.000',
        r'$130=300.000',
        r'$131=180.000',
        r'$132=45.000',
      ].join('\n'),
    );
    return base
        .withValue(32, laser)
        .withValue(20, softLimits)
        .withValue(22, homing)
        .withValue(130, travelX);
  }

  group('ProfileConsistency', () {
    test('un perfil coherente no produce bloqueos', () {
      final List<ConsistencyIssue> issues = ProfileConsistency.check(
        profile: profile,
        settings: settings(),
      );

      expect(ProfileConsistency.hasBlocking(issues), isFalse);
    });

    test('bloquea si el perfil es láser y el modo láser está apagado', () {
      final List<ConsistencyIssue> issues = ProfileConsistency.check(
        profile: profile,
        settings: settings(laser: 0),
      );

      expect(ProfileConsistency.hasBlocking(issues), isTrue);
      expect(
        issues.map((ConsistencyIssue issue) => issue.code),
        contains('LASER_MODE_OFF'),
      );
    });

    test('bloquea si el recorrido configurado es menor que el del perfil', () {
      final List<ConsistencyIssue> issues = ProfileConsistency.check(
        profile: profile,
        settings: settings(travelX: 200),
      );

      final ConsistencyIssue issue = issues.firstWhere(
        (ConsistencyIssue issue) => issue.code == 'TRAVEL_X',
      );
      expect(issue.blocks, isTrue);
      expect(issue.message, contains('200.0'));
      expect(issue.message, contains('300.0'));
    });

    test('avisa si los soft limits están apagados', () {
      final List<ConsistencyIssue> issues = ProfileConsistency.check(
        profile: profile,
        settings: settings(softLimits: 0),
      );

      expect(
        issues.map((ConsistencyIssue issue) => issue.code),
        contains('NO_SOFT_LIMITS'),
      );
      expect(ProfileConsistency.hasBlocking(issues), isFalse);
    });

    test('avisa si el parser está en pulgadas', () {
      final ParserState inches = ParserState.parse(
        r'[GC:G0 G54 G17 G20 G90 G94 M5 M9 T0 F0 S0]',
      );

      final List<ConsistencyIssue> issues = ProfileConsistency.check(
        profile: profile,
        settings: settings(),
        parserState: inches,
      );

      expect(
        issues.map((ConsistencyIssue issue) => issue.code),
        contains('UNITS_INCHES'),
      );
    });

    test('bloquea si faltan pasos/mm, velocidades o modo láser', () {
      final List<ConsistencyIssue> issues = ProfileConsistency.check(
        profile: profile,
        settings: GrblSettings.empty(),
      );

      final Iterable<String> blockingCodes = issues
          .where((ConsistencyIssue issue) => issue.blocks)
          .map((ConsistencyIssue issue) => issue.code);

      expect(ProfileConsistency.hasBlocking(issues), isTrue);
      // 3 ejes x (pasos/mm + velocidad) + modo láser sin configurar.
      expect(blockingCodes, hasLength(7));
      expect(blockingCodes, contains('STEPS_X'));
      expect(blockingCodes, contains('RATE_Z'));
      expect(blockingCodes, contains('LASER_MODE_OFF'));
    });

    test('avisa de modo láser activo con herramienta de fresado', () {
      const MachineProfile mill = MachineProfile(
        id: 'p2',
        name: 'Fresadora',
        tool: ToolType.mill,
        travelXmm: 300,
        travelYmm: 180,
        travelZmm: 45,
      );

      final List<ConsistencyIssue> issues = ProfileConsistency.check(
        profile: mill,
        settings: settings(),
      );

      expect(
        issues.map((ConsistencyIssue issue) => issue.code),
        contains('LASER_MODE_ON'),
      );
      expect(ProfileConsistency.hasBlocking(issues), isFalse);
    });
  });
}
