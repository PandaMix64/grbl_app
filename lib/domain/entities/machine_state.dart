/// Estados de máquina que reporta GRBL v1.1 en el campo de estado de `<...>`.
enum MachineState {
  idle,
  run,
  jog,
  hold,
  door,
  check,
  home,
  sleep,
  alarm,
  unknown;

  /// Interpreta el primer campo de un status report (`<Idle|...>`).
  ///
  /// El nombre puede venir con subestado (`Hold:0`, `Door:1`), por lo que solo
  /// se compara la parte anterior a los dos puntos.
  static MachineState parse(String raw) {
    final String name = raw.split(':').first.trim().toLowerCase();
    return switch (name) {
      'idle' => MachineState.idle,
      'run' => MachineState.run,
      'jog' => MachineState.jog,
      'hold' => MachineState.hold,
      'door' => MachineState.door,
      'check' => MachineState.check,
      'home' => MachineState.home,
      'sleep' => MachineState.sleep,
      'alarm' => MachineState.alarm,
      _ => MachineState.unknown,
    };
  }

  /// Indica si la máquina está ejecutando movimiento.
  bool get isMoving => this == MachineState.run || this == MachineState.jog;

  /// Indica si la máquina puede aceptar un jog (`$J=`).
  ///
  /// GRBL solo acepta jogs en `Idle` o `Jog`.
  bool get allowsJog => this == MachineState.idle || this == MachineState.jog;

  /// Indica si el estado requiere `$X` antes de cualquier movimiento.
  bool get isBlocked => this == MachineState.alarm || this == MachineState.door;

  /// Etiqueta legible para la barra de estado de la UI.
  String get label => switch (this) {
    MachineState.idle => 'Idle',
    MachineState.run => 'Run',
    MachineState.jog => 'Jog',
    MachineState.hold => 'Hold',
    MachineState.door => 'Door',
    MachineState.check => 'Check',
    MachineState.home => 'Home',
    MachineState.sleep => 'Sleep',
    MachineState.alarm => 'Alarm',
    MachineState.unknown => 'Desconocido',
  };
}
