import '../entities/axis.dart';
import '../entities/grbl_settings.dart';
import '../entities/machine_profile.dart';
import '../entities/parser_state.dart';

/// Gravedad de una discrepancia entre el perfil local y la EEPROM de GRBL.
enum ConsistencySeverity {
  /// Impide ejecutar: el trabajo saldría mal o la máquina se protegería sola.
  blocking,

  /// Riesgo o pérdida de precisión; el usuario debe decidir.
  warning,

  /// Informativo.
  info,
}

/// Discrepancia detectada al comparar el perfil con el controlador.
class ConsistencyIssue {
  const ConsistencyIssue({
    required this.code,
    required this.severity,
    required this.message,
  });

  final String code;
  final ConsistencySeverity severity;
  final String message;

  bool get blocks => severity == ConsistencySeverity.blocking;

  @override
  String toString() => '[${severity.name}] $code — $message';
}

/// Compara el perfil local con lo que el controlador dice tener configurado.
///
/// El perfil guarda lo que la app **cree** de la máquina (volumen, herramienta,
/// altura segura); la EEPROM guarda lo que la máquina **hace**. Si divergen, el
/// resultado es una pieza perdida o un choque contra los finales de carrera.
class ProfileConsistency {
  const ProfileConsistency._();

  static List<ConsistencyIssue> check({
    required MachineProfile profile,
    required GrblSettings settings,
    ParserState? parserState,
  }) {
    final List<ConsistencyIssue> issues = <ConsistencyIssue>[];

    for (final MachineAxis axis in MachineAxis.values) {
      final double? steps = settings.stepsPerMm(axis);
      if (steps == null || steps <= 0) {
        issues.add(
          ConsistencyIssue(
            code: 'STEPS_${axis.letter}',
            severity: ConsistencySeverity.blocking,
            message:
                'El eje ${axis.letter} no tiene pasos/mm válidos '
                r'($100-$102): sin eso no hay movimiento preciso.',
          ),
        );
      }
      final double? rate = settings.maxRate(axis);
      if (rate == null || rate <= 0) {
        issues.add(
          ConsistencyIssue(
            code: 'RATE_${axis.letter}',
            severity: ConsistencySeverity.blocking,
            message:
                'El eje ${axis.letter} no tiene velocidad máxima válida '
                r'($110-$112).',
          ),
        );
      }
    }

    if (profile.usesLaserMode && !settings.isLaserMode) {
      issues.add(
        const ConsistencyIssue(
          code: 'LASER_MODE_OFF',
          severity: ConsistencySeverity.blocking,
          message:
              r'El perfil usa láser pero $32=0: GRBL se detendría en cada '
              'cambio de S y el haz no modularía con la velocidad.',
        ),
      );
    }
    if (!profile.usesLaserMode && settings.isLaserMode) {
      issues.add(
        ConsistencyIssue(
          code: 'LASER_MODE_ON',
          severity: ConsistencySeverity.warning,
          message:
              r'GRBL está en modo láser ($32=1) con una herramienta de tipo '
              '${profile.tool.name}.',
        ),
      );
    }

    for (final MachineAxis axis in MachineAxis.values) {
      final double expected = profile.travel[axis.axisIndex];
      final double? configured = settings.maxTravel(axis);
      if (configured == null || configured <= 0) {
        issues.add(
          ConsistencyIssue(
            code: 'TRAVEL_${axis.letter}_UNSET',
            severity: ConsistencySeverity.warning,
            message:
                'El recorrido máximo del eje ${axis.letter} no está '
                r'configurado ($130-$132): los soft limits no protegerán ese '
                'eje.',
          ),
        );
        continue;
      }
      if (configured < expected - 1) {
        issues.add(
          ConsistencyIssue(
            code: 'TRAVEL_${axis.letter}',
            severity: ConsistencySeverity.blocking,
            message:
                'El recorrido configurado del eje ${axis.letter} '
                '(${configured.toStringAsFixed(1)} mm) es menor que el del '
                'perfil (${expected.toStringAsFixed(1)} mm): los soft limits '
                'rechazarían parte del trabajo.',
          ),
        );
      } else if ((configured - expected).abs() > 1) {
        issues.add(
          ConsistencyIssue(
            code: 'TRAVEL_${axis.letter}_DIFF',
            severity: ConsistencySeverity.warning,
            message:
                'El recorrido del eje ${axis.letter} difiere del perfil: '
                '${configured.toStringAsFixed(1)} mm frente a '
                '${expected.toStringAsFixed(1)} mm.',
          ),
        );
      }
    }

    if (!settings.homingEnabled) {
      issues.add(
        const ConsistencyIssue(
          code: 'NO_HOMING',
          severity: ConsistencySeverity.info,
          message:
              r'Homing deshabilitado ($22=0): tras un reset habrá que '
              'redefinir el origen a mano antes de reanudar.',
        ),
      );
    }
    if (!settings.softLimitsEnabled) {
      issues.add(
        const ConsistencyIssue(
          code: 'NO_SOFT_LIMITS',
          severity: ConsistencySeverity.warning,
          message:
              r'Soft limits deshabilitados ($20=0): nada impide que un G-code '
              'saque la máquina de su volumen de trabajo.',
        ),
      );
    }
    if (parserState != null && parserState.isInches) {
      issues.add(
        const ConsistencyIssue(
          code: 'UNITS_INCHES',
          severity: ConsistencySeverity.warning,
          message:
              'El parser está en pulgadas (G20) y el perfil se define en '
              'milímetros.',
        ),
      );
    }

    return issues;
  }

  /// `true` si alguna discrepancia impide ejecutar.
  static bool hasBlocking(Iterable<ConsistencyIssue> issues) =>
      issues.any((ConsistencyIssue issue) => issue.blocks);
}
