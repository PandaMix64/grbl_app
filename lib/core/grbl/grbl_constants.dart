/// Constantes de protocolo de GRBL v1.1h.
///
/// Los comandos en tiempo real son **bytes únicos** que se inyectan en el flujo
/// y se ejecutan de inmediato: los consume la ISR del ATmega antes de entrar al
/// búfer de recepción, por lo que no deben contarse en el presupuesto de 128 B
/// (ver `docs/revision_tecnica_ruta_de_accion.md`, P1-4).
library;

/// Bytes de comandos en tiempo real (sin terminador de línea).
abstract final class GrblRealtime {
  /// `?` — solicita un status report.
  static const int statusReport = 0x3F;

  /// `~` — cycle start: reanuda la ejecución tras un feed hold.
  static const int cycleStart = 0x7E;

  /// `!` — feed hold: desacelera hasta detener el movimiento.
  ///
  /// **No apaga el husillo ni el láser.** Para una pausa segura usar
  /// `GrblSafety.pause` de `docs/seguridad_operativa.md`.
  static const int feedHold = 0x21;

  /// `0x18` — soft reset (Ctrl-X). Pierde la posición de máquina.
  static const int softReset = 0x18;

  /// `0x84` — safety door.
  static const int safetyDoor = 0x84;

  /// `0x85` — jog cancel. Solo tiene efecto en estado `Jog`.
  static const int jogCancel = 0x85;

  /// `0x9E` — toggle spindle stop. Solo tiene efecto en estado `Hold`.
  static const int spindleStopToggle = 0x9E;

  /// `0x90` — restaura el feed override al 100 %.
  static const int feedOverrideReset = 0x90;

  /// `0x95` — restaura el rapid override al 100 %.
  static const int rapidOverrideReset = 0x95;

  /// `0x99` — restaura el spindle override al 100 %.
  static const int spindleOverrideReset = 0x99;

  /// `0xA0` — alterna el refrigerante de inundación.
  static const int floodCoolantToggle = 0xA0;
}

/// GRBL espera `CR` como terminador de línea, no `CRLF`.
const String kGrblLineEnding = '\r';

/// Tamaño por defecto del búfer de recepción serial (`RX_BUFFER_SIZE`).
///
/// Es un valor de **compilación**: en ATmega328P vale 128, pero otros forks
/// (ARM, ESP32) usan 256 o más. Debe confirmarse al conectar.
const int kDefaultRxBufferSize = 128;

/// Reserva de seguridad: nunca se llena el búfer hasta el último byte.
///
/// Un byte de margen evita que una escritura concurrente (por ejemplo un
/// comando en tiempo real con su propio byte en el cable) deje el búfer al
/// límite mientras GRBL aún no ha consumido la línea.
const int kRxBufferReserve = 1;

/// Velocidad por defecto de GRBL (`BAUD_RATE 115200` en `config.h`).
///
/// Es un valor de compilación: existen máquinas a 9600, 57600 y 250000, por lo
/// que la UI debe permitir cambiarla.
const int kDefaultBaudRate = 115200;
