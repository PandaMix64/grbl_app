import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:usb_serial/usb_serial.dart';

import '../../core/grbl/grbl_constants.dart';
import '../../domain/repositories/serial_port_repository.dart';
import 'serial_line_buffer.dart';

/// Implementación de [SerialPortRepository] sobre el host USB de Android.
///
/// Los GRBL se conectan por un chip USB-serie (CDC-ACM del Uno/Mega, CH340 en
/// las placas clonadas, CP210x, FTDI o PL2303). Android **no** expone esos chips
/// como `/dev/ttyUSB0`: el dispositivo aparece en `/dev/bus/usb/...` y hay que
/// pedir permiso al `UsbManager` y hablar por *bulk transfers*. Eso es lo que
/// resuelve `usb_serial`, que trae los drivers de `usb-serial-for-android`
/// empaquetados y lanza el diálogo de permiso al crear el puerto.
///
/// A diferencia de `LibSerialPortRepository` (FFI), este camino usa un
/// `MethodChannel`, así que **debe** ejecutarse en el isolate principal: por eso
/// en Android el worker serial se construye con `GrblWorkerClient.inProcess`.
///
/// Configuración fija 8-N-1 sin control de flujo, igual que GRBL exige
/// (`115200 baudios, 8-N-1`), y terminadores `\r` en las líneas.
class AndroidUsbSerialRepository implements SerialPortRepository {
  static const String permissionDeniedMessage =
      'Android no concedió el permiso de acceso al dispositivo USB. Acepta el '
      'diálogo «Permitir acceso a…» que aparece al conectar la máquina.';

  final StreamController<String> _lines = StreamController<String>.broadcast();
  final SerialLineBuffer _incoming = SerialLineBuffer();

  UsbPort? _port;
  StreamSubscription<Uint8List>? _inputSubscription;

  /// Cola de escrituras: `writeLine` es síncrono para el servicio, pero el
  /// `MethodChannel` es asíncrono. Encadenarlas conserva el orden de los bytes.
  Future<void> _writeChain = Future<void>.value();

  /// Evita reentrar en `close()` (y silenciar el aviso de desconexión).
  bool _closing = false;

  @override
  bool get isOpen => _port != null;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<List<SerialPortInfo>> listPorts() async {
    final List<UsbDevice> devices = await UsbSerial.listDevices();
    return <SerialPortInfo>[
      for (final UsbDevice device in devices)
        SerialPortInfo(
          // `deviceName` se mantiene mientras el aparato siga enchufado y se
          // usa como clave para volver a localizarlo al abrir (el `deviceId`
          // cambia al reconectar).
          name: device.deviceName,
          description: _describe(device),
        ),
    ];
  }

  @override
  Future<void> open({
    required String portName,
    int baudRate = kDefaultBaudRate,
  }) async {
    if (_port != null) {
      throw const SerialPortException('Ya hay un puerto abierto.');
    }

    final UsbDevice? device = await _findDevice(portName);
    if (device == null) {
      throw SerialPortException(
        'El dispositivo USB $portName ya no está conectado. Actualiza la lista '
        'de puertos.',
      );
    }

    // `create()` pide permiso al `UsbManager` si aún no lo tiene (diálogo del
    // sistema) y abre el `UsbDeviceConnection`. Si se deniega, el plugin
    // devuelve `PlatformException` o `null` según el punto de fallo.
    UsbPort? port;
    try {
      port = await device.create();
    } on PlatformException catch (error) {
      throw SerialPortException(_createErrorMessage(error), cause: error);
    }
    if (port == null) {
      throw const SerialPortException(permissionDeniedMessage);
    }

    final bool opened = await port.open();
    if (!opened) {
      await _safeClose(port);
      throw SerialPortException(
        'No se pudo abrir el puerto USB $portName. ¿Está en uso por otra '
        'aplicación?',
      );
    }

    _port = port;
    // La suscripción va **antes** de tocar DTR: el reset del Arduino imprime el
    // banner de GRBL y el stream es broadcast (los eventos sin oyente se
    // pierden).
    _inputSubscription = port.inputStream?.listen(
      _onData,
      onError: (Object error) => _emitError(
        SerialPortException('Error de lectura USB.', cause: error),
      ),
      onDone: _onUnexpectedClose,
    );

    try {
      await port.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      await port.setFlowControl(UsbPort.FLOW_CONTROL_OFF);
      // DTR/RTS altos: es lo que reinicia el Arduino y deja la línea en reposo.
      await port.setDTR(true);
      await port.setRTS(true);
    } on Object catch (error) {
      // Sin la configuración 8-N-1 el enlace no sirve: se libera el puerto en
      // vez de dejarlo abierto y a medias.
      await close();
      throw SerialPortException(
        'No se pudo configurar el puerto USB $portName.',
        cause: error,
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    final UsbPort? port = _port;
    final StreamSubscription<Uint8List>? subscription = _inputSubscription;
    _port = null;
    _inputSubscription = null;
    try {
      await subscription?.cancel();
      // Cerrar en medio de una escritura deja el `bulkTransfer` con el
      // descriptor liberado: se espera a que la cola termine.
      await _writeChain;
      if (port != null) {
        await port.close();
      }
    } on Object catch (error) {
      _emitError(SerialPortException('Al cerrar el puerto USB.', cause: error));
    } finally {
      _incoming.clear();
      _closing = false;
    }
  }

  @override
  void writeLine(String line) => _enqueueWrite(utf8.encode('$line\r'));

  @override
  void writeRealtime(int byte) => _enqueueWrite(<int>[byte]);

  @override
  void writeBytes(Uint8List bytes) => _enqueueWrite(bytes);

  /// Libera el controlador de líneas; llamar al cerrar el servicio.
  Future<void> dispose() async {
    await close();
    if (!_lines.isClosed) {
      await _lines.close();
    }
  }

  Future<UsbDevice?> _findDevice(String portName) async {
    final List<UsbDevice> devices = await UsbSerial.listDevices();
    for (final UsbDevice device in devices) {
      if (device.deviceName == portName) {
        return device;
      }
    }
    return null;
  }

  /// Descripción legible: producto, fabricante y `VID:PID` cuando existan.
  String _describe(UsbDevice device) {
    final List<String> parts = <String>[];
    final String? product = device.productName?.trim();
    final String? manufacturer = device.manufacturerName?.trim();
    if (product != null && product.isNotEmpty) {
      parts.add(product);
    }
    if (manufacturer != null && manufacturer.isNotEmpty) {
      parts.add(manufacturer);
    }
    final int? vid = device.vid;
    final int? pid = device.pid;
    if (vid != null && pid != null) {
      parts.add('${_hex(vid)}:${_hex(pid)}');
    }
    return parts.isEmpty ? 'Dispositivo USB' : parts.join(' · ');
  }

  static String _hex(int value) =>
      '0x${value.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  /// Traduce los errores del plugin a algo accionable para el operario.
  static String _createErrorMessage(PlatformException error) {
    final String detail = '${error.message ?? ''} ${error.code}'.toLowerCase();
    if (detail.contains('permission')) {
      return permissionDeniedMessage;
    }
    if (detail.contains('no such device')) {
      return 'El dispositivo USB se desconectó antes de abrirlo. Actualiza la '
          'lista de puertos.';
    }
    if (detail.contains('not an serial') || detail.contains('not a serial')) {
      return 'El dispositivo USB no parece un adaptador serie: comprueba que '
          'sea la placa GRBL y no otro periférico.';
    }
    return 'No se pudo abrir el puerto USB: ${error.message ?? error.code}';
  }

  /// Encola una escritura sin bloquear al llamador.
  void _enqueueWrite(List<int> data) {
    final UsbPort? port = _port;
    if (port == null) {
      if (_closing) {
        // Una respuesta tardía puede intentar escribir mientras se cierra el
        // puerto: se descarta en silencio, igual que en el transporte FFI.
        return;
      }
      throw const SerialPortException('No hay puerto abierto.');
    }
    final Uint8List bytes = data is Uint8List ? data : Uint8List.fromList(data);
    _writeChain = _writeChain.then((_) async {
      // El puerto pudo cerrarse mientras esta escritura esperaba su turno.
      if (_port != port) {
        return;
      }
      try {
        await port.write(bytes);
      } on Object catch (error) {
        _emitError(SerialPortException('Escritura USB fallida.', cause: error));
      }
    });
  }

  Future<void> _safeClose(UsbPort port) async {
    try {
      await port.close();
    } on Object {
      // El puerto pudo no haber llegado a abrirse.
    }
  }

  /// El plugin cierra el stream de entrada cuando el dispositivo se desenchufa.
  void _onUnexpectedClose() {
    if (_closing) {
      return;
    }
    _port = null;
    _inputSubscription = null;
    _emitError(
      const SerialPortException(
        'El dispositivo USB se desconectó. Vuelve a conectarlo y reconecta '
        'para recuperar el control de la máquina.',
      ),
    );
  }

  void _onData(Uint8List chunk) {
    if (_lines.isClosed) {
      return;
    }
    // GRBL es ASCII: `allowMalformed` evita tumbar el stream con ruido de línea.
    for (final String line in _incoming.add(
      utf8.decode(chunk, allowMalformed: true),
    )) {
      _lines.add(line);
    }
  }

  void _emitError(Object error) {
    if (!_lines.isClosed) {
      _lines.addError(error);
    }
  }
}
