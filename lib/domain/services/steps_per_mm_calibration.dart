/// Recalibración de pasos/mm a partir de una medida real.
///
/// Procedimiento (documento de ruta, §3.2): se ordena un avance teórico
/// conocido, se mide el desplazamiento real y se corrige el parámetro:
///
/// `nuevo = actual × (avance_teórico / medida_real)`
class StepsPerMmCalibration {
  const StepsPerMmCalibration({
    required this.currentStepsPerMm,
    required this.commandedMm,
    required this.measuredMm,
  });

  /// Valor actual del parámetro (`$100`/`$101`/`$102`).
  final double currentStepsPerMm;

  /// Distancia teórica ordenada (normalmente 10 mm).
  final double commandedMm;

  /// Distancia real medida con calibre o regla.
  final double measuredMm;

  /// Nuevo valor de pasos/mm.
  double get newStepsPerMm => currentStepsPerMm * commandedMm / measuredMm;

  /// Factor de corrección aplicado (`commanded / measured`).
  double get correctionFactor => commandedMm / measuredMm;

  /// Error relativo con signo: positivo si se avanzó de más.
  double get relativeError => measuredMm / commandedMm - 1;

  /// Valor formateado a 3 decimales, listo para `$x=valor`.
  String toGrblValue({int decimals = 3}) =>
      newStepsPerMm.toStringAsFixed(decimals);

  /// Errores que impiden calcular una corrección fiable.
  List<String> validate() {
    final List<String> errors = <String>[];
    if (currentStepsPerMm <= 0) {
      errors.add('Los pasos/mm actuales deben ser mayores que cero.');
    }
    if (commandedMm <= 0) {
      errors.add('La distancia ordenada debe ser mayor que cero.');
    }
    if (measuredMm <= 0) {
      errors.add('La distancia medida debe ser mayor que cero.');
    }
    if (commandedMm > 0 &&
        measuredMm > 0 &&
        (measuredMm < commandedMm * 0.5 || measuredMm > commandedMm * 1.5)) {
      errors.add(
        'La medida real difiere más de un 50 % de la ordenada: revisa la '
        'unidad (mm/pulgadas), los pasos/mm o que la máquina no patinara.',
      );
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;
}
