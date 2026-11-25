/// Ejes soportados por GRBL con sus códigos de parámetros asociados.
///
/// Evita los "números mágicos" de `$100..$132` repartidos por el código.
enum MachineAxis {
  x(0),
  y(1),
  z(2);

  const MachineAxis(this.axisIndex);

  /// Posición del eje en los vectores de posición y en el sufijo de parámetro.
  final int axisIndex;

  /// `$100`, `$101`, `$102` — pasos por milímetro.
  int get stepsPerMmCode => 100 + axisIndex;

  /// `$110`, `$111`, `$112` — velocidad máxima en mm/min.
  int get maxRateCode => 110 + axisIndex;

  /// `$120`, `$121`, `$122` — aceleración en mm/s².
  int get accelerationCode => 120 + axisIndex;

  /// `$130`, `$131`, `$132` — recorrido máximo en mm.
  int get maxTravelCode => 130 + axisIndex;

  /// Nombre en mayúsculas usado por GRBL (`X`, `Y`, `Z`).
  String get letter => name.toUpperCase();
}
