import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:libserialport/libserialport.dart';

import '../../core/grbl/grbl_constants.dart';
import '../../domain/repositories/serial_port_repository.dart';

/// Implementación real de [SerialPortRepository] sobre `libserialport` (FFI).
///
/// Es FFI puro, no `MethodChannel`: por eso puede vivir dentro del isolate
/// worker (un `MethodChannel` no funciona en un isolate de fondo).
/// `flutter_libserialport` se encarga de empaquetar la biblioteca nativa en
/// Windows, Linux, macOS y Android.
///
/// Configuración fija 8-N-1 sin control de flujo, que es lo que exige GRBL
/// (`115200 baudios, 8-N-1`), y terminadores `\r` en las líneas.
class LibSerialPortRepository implements SerialPortRepository {
  final StreamController<String> _lines = StreamController<String>.broadcast();
  final StringBuffer _incoming = StringBuffer();

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readerSubscription;

  @override
  bool get isOpen => _port?.isOpen ?? false;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<List<SerialPortInfo>> listPorts() async {
    final List<SerialPortInfo> ports = <SerialPortInfo>[];
    for (final String name in SerialPort.availablePorts) {
      String? description;
      final SerialPort probe = SerialPort(name);
      try {
        description = probe.description;
      } finally {
        probe.dispose();
      }
      ports.add(SerialPortInfo(name: name, description: description));
    }
    return ports;
  }

  @override
  Future<void> open({
    required String portName,
    int baudRate = kDefaultBaudRate,
  }) async {
    if (_port != null) {
      throw const SerialPortException('Ya hay un puerto abierto.');
    }

    final SerialPort port = SerialPort(portName);
    if (!port.openReadWrite()) {
      final SerialPortError? error = SerialPort.lastError;
      port.dispose();
      throw SerialPortException(
        'No se pudo abrir el puerto $portName. ¿Está en uso por otra '
        'aplicación o desconectado?',
        cause: error,
      );
    }

    final SerialPortConfig config = SerialPortConfig()
      ..baudRate = baudRate
      ..bits = 8
      ..parity = SerialPortParity.none
      ..stopBits = 1
      ..setFlowControl(SerialPortFlowControl.none);
    try {
      port.config = config;
    } finally {
      config.dispose();
    }

    _port = port;
    final SerialPortReader reader = SerialPortReader(port);
    _reader = reader;
    _readerSubscription = reader.stream.listen(
      _onData,
      onError: (Object error) {
        if (!_lines.isClosed) {
          _lines.addError(
            SerialPortException('Error de lectura serial.', cause: error),
          );
        }
      },
    );
  }

  @override
  Future<void> close() async {
    await _readerSubscription?.cancel();
    _readerSubscription = null;
    _reader?.close();
    _reader = null;

    final SerialPort? port = _port;
    _port = null;
    if (port != null) {
      try {
        if (port.isOpen) {
          port.close();
        }
      } finally {
        port.dispose();
      }
    }
    _incoming.clear();
  }

  @override
  void writeLine(String line) => _write(utf8.encode('$line\r'));

  @override
  void writeRealtime(int byte) => _write(<int>[byte]);

  @override
  void writeBytes(Uint8List bytes) => _write(bytes);

  /// Libera el controlador de líneas; llamar al cerrar el servicio.
  Future<void> dispose() async {
    await close();
    if (!_lines.isClosed) {
      await _lines.close();
    }
  }

  void _write(List<int> data) {
    final SerialPort? port = _port;
    if (port == null) {
      throw const SerialPortException('No hay puerto abierto.');
    }
    final Uint8List bytes = Uint8List.fromList(data);
    final int written = port.write(bytes, timeout: 1000);
    if (written != bytes.length) {
      throw SerialPortException(
        'Escritura incompleta: $written de ${bytes.length} bytes.',
      );
    }
  }

  /// Reensambla las líneas: GRBL responde con `\r\n` y los datos pueden llegar
  /// partidos en varios eventos del lector.
  void _onData(Uint8List chunk) {
    if (_lines.isClosed) {
      return;
    }
    _incoming.write(utf8.decode(chunk, allowMalformed: true));
    String text = _incoming.toString();
    int newline = text.indexOf('\n');
    while (newline >= 0) {
      String line = text.substring(0, newline);
      text = text.substring(newline + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      if (line.isNotEmpty) {
        _lines.add(line);
      }
      newline = text.indexOf('\n');
    }
    _incoming
      ..clear()
      ..write(text);
  }
}
