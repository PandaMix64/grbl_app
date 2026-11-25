/// Estimación de la holgura a partir de la prueba de inversión de sentido.
///
/// Procedimiento del documento de ruta (§3.2): se ordena un avance, se marca la
/// posición, se invierte el sentido la misma distancia y se mide cuánto se
/// movió realmente. La diferencia es la holgura.
class BacklashEstimate {
  const BacklashEstimate({required this.commandedMm, required this.measuredMm});

  /// Distancia ordenada en cada sentido (normalmente 5 mm).
  final double commandedMm;

  /// Desplazamiento real medido al volver.
  final double measuredMm;

  /// Holgura estimada en mm.
  double get backlashMm => commandedMm - measuredMm;

  /// Valor formateado a 3 decimales para guardarlo en el perfil.
  String toProfileValue({int decimals = 3}) =>
      backlashMm.toStringAsFixed(decimals);

  /// Errores que invalidan la estimación.
  List<String> validate() {
    final List<String> errors = <String>[];
    if (commandedMm <= 0) {
      errors.add('La distancia ordenada debe ser mayor que cero.');
    }
    if (measuredMm < 0) {
      errors.add('La distancia medida no puede ser negativa.');
    }
    if (measuredMm > commandedMm) {
      errors.add(
        'La medida supera lo ordenado: revisa el calibre o repite la prueba '
        'con menos avance.',
      );
    } else if (commandedMm > 0 && backlashMm > commandedMm * 0.5) {
      errors.add(
        'La holgura estimada supera el 50 % del avance: probablemente la '
        'prueba no se hizo con la máquina en reposo o hay un paso perdido.',
      );
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;
}
