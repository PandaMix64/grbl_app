import 'dart:typed_data';

/// Puerto serial disponible en el sistema.
class SerialPortInfo {
  const SerialPortInfo({required this.name, this.description});

  /// Identificador que espera el sistema operativo (`COM3`, `/dev/ttyUSB0`).
  final String name;

  /// Descripción legible del dispositivo, si el sistema la proporciona.
  final String? description;

  @override
  String toString() => description == null ? name : '$name ($description)';
}

/// Error de apertura, escritura o lectura del puerto serial.
class SerialPortException implements Exception {
  const SerialPortException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'SerialPortException: $message${cause == null ? '' : ' — $cause'}';
}

/// Contrato de acceso al puerto serial.
///
/// Existe para que toda la lógica de GRBL dependa de esta interfaz y no de
/// `flutter_libserialport`. Así el servicio serial es testeable con un puerto
/// falso y se puede cambiar de librería (o sumar USB-OTG en Android) sin tocar
/// el dominio.
///
/// Implementación concreta pendiente: `LibSerialPortRepository` (FFI) más el
/// isolate worker que la posee. Ningún widget debe usar esta interfaz
/// directamente: solo `GrblSerialService` y el `SafetyController`.
abstract interface class SerialPortRepository {
  /// Puertos disponibles en el sistema.
  Future<List<SerialPortInfo>> listPorts();

  /// Abre el puerto indicado.
  Future<void> open({required String portName, int baudRate = 115200});

  /// Cierra el puerto si está abierto. Idempotente.
  Future<void> close();

  bool get isOpen;

  /// Escribe una línea terminada en `\r` (GRBL no acepta `\r\n` como bloque).
  void writeLine(String line);

  /// Escribe un byte de comando en tiempo real (`?`, `!`, `~`, `0x18`, ...).
  void writeRealtime(int byte);

  /// Escribe bytes crudos (usado para el banner inicial o pruebas).
  void writeBytes(Uint8List bytes);

  /// Líneas recibidas del controlador, sin el terminador.
  Stream<String> get lines;
}
