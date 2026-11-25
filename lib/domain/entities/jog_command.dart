import 'axis.dart';

/// Modo de coordenadas del jog.
enum JogMode {
  /// `G91`: desplazamiento relativo en el marco de trabajo (uso normal).
  relative,

  /// `G90` + `G53`: destino absoluto en coordenadas de máquina.
  absoluteMachine,
}

/// Comando de jogging de GRBL v1.1 (`$J=`).
///
/// Reglas del firmware (`doc/markdown/jogging.md`):
/// * los tres primeros caracteres deben ser `$J=`,
/// * `F` es **obligatorio en cada comando** y no es modal,
/// * solo se acepta en estado `Idle` o `Jog`,
/// * `G20/G21`, `G90/G91` y `G53` son opcionales y afectan solo a ese comando,
/// * no altera el estado modal del parser.
class JogCommand {
  JogCommand({
    required Map<MachineAxis, double> values,
    required this.feedMmMin,
    this.mode = JogMode.relative,
  }) : values = Map<MachineAxis, double>.unmodifiable(values);

  /// Incrementos (o destinos, en [JogMode.absoluteMachine]) por eje.
  final Map<MachineAxis, double> values;

  /// Avance en mm/min. Obligatorio y no modal.
  final double feedMmMin;

  final JogMode mode;

  bool get isValid => validate().isEmpty;

  /// Errores de validación; vacío si el comando es ejecutable.
  List<String> validate() {
    final List<String> errors = <String>[];
    if (values.isEmpty || values.values.every((double value) => value == 0)) {
      errors.add('El jog necesita al menos un eje con desplazamiento.');
    }
    if (feedMmMin <= 0) {
      errors.add('El jog necesita un avance mayor que cero (F).');
    }
    return errors;
  }

  /// Línea `$J=...` lista para enviar.
  ///
  /// Lanza [ArgumentError] si el comando no es válido: es preferible fallar en
  /// Dart que enviar a GRBL un jog que devolvería `error:`.
  String build() {
    final List<String> errors = validate();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.join(' '));
    }

    final List<String> words = <String>[];
    switch (mode) {
      case JogMode.relative:
        words.add('G91');
      case JogMode.absoluteMachine:
        words
          ..add('G90')
          ..add('G53');
    }
    for (final MachineAxis axis in MachineAxis.values) {
      final double? value = values[axis];
      if (value != null && value != 0) {
        words.add('${axis.letter}${value.toStringAsFixed(3)}');
      }
    }
    words.add('F${feedMmMin.toStringAsFixed(3)}');
    return '${r'$J='}${words.join(' ')}';
  }

  @override
  String toString() => isValid ? build() : 'JogCommand(inválido)';
}
