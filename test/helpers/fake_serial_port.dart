import 'dart:async';
import 'dart:typed_data';

import 'package:grbl_app/domain/repositories/serial_port_repository.dart';

/// Puerto serial falso con un GRBL v1.1 mínimo emulado.
///
/// Permite probar el streaming, la telemetría y las secuencias de seguridad sin
/// hardware. Además **detecta desbordes**: acumula los bytes enviados y no
/// confirmados, y marca [overflowDetected] si superan el búfer real (128 B).
class FakeSerialPort implements SerialPortRepository {
  FakeSerialPort({this.bufferSize = 128});

  final int bufferSize;

  final StreamController<String> _lines = StreamController<String>.broadcast();
  final List<String> writtenLines = <String>[];
  final List<int> realtimeBytes = <int>[];

  bool _open = false;
  bool _autoAck = true;
  int _unackedBytes = 0;

  /// Estado que reporta el emulador.
  String state = 'Idle';

  /// Consigna de husillo/láser (`S`) reportada.
  double spindle = 0;

  /// Avance reportado.
  double feed = 800;

  /// Si es `true`, cada línea recibe su `ok` (como GRBL en `Idle`).
  set autoAck(bool value) => _autoAck = value;

  /// `true` si alguna vez se superó el búfer de recepción.
  bool overflowDetected = false;

  /// Máximo de bytes no confirmados observado.
  int peakUnackedBytes = 0;

  @override
  bool get isOpen => _open;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<List<SerialPortInfo>> listPorts() async => const <SerialPortInfo>[
    SerialPortInfo(name: 'FAKE0', description: 'loopback de pruebas'),
  ];

  @override
  Future<void> open({required String portName, int baudRate = 115200}) async {
    _open = true;
    emitLine(r"Grbl 1.1h ['$' for help]");
  }

  @override
  Future<void> close() async {
    _open = false;
  }

  @override
  void writeLine(String line) {
    writtenLines.add(line);
    final int bytes = line.length + 1;
    _unackedBytes += bytes;
    if (_unackedBytes > peakUnackedBytes) {
      peakUnackedBytes = _unackedBytes;
    }
    if (_unackedBytes > bufferSize) {
      overflowDetected = true;
    }
    if (_autoAck) {
      scheduleMicrotask(() {
        _unackedBytes -= bytes;
        if (_unackedBytes < 0) {
          _unackedBytes = 0;
        }
        emitLine('ok');
      });
    }
  }

  @override
  void writeRealtime(int byte) {
    realtimeBytes.add(byte);
    switch (byte) {
      case 0x3F: // '?'
        emitLine(statusLine());
      case 0x21: // '!'
        if (state == 'Run' || state == 'Jog') {
          state = 'Hold';
        }
      case 0x7E: // '~'
        state = 'Run';
      case 0x18: // soft reset
        state = 'Alarm';
        _unackedBytes = 0;
        scheduleMicrotask(() => emitLine(r"Grbl 1.1h ['$' for help]"));
      case 0x85: // jog cancel
        if (state == 'Jog') {
          state = 'Idle';
        }
      case 0x9E: // spindle stop toggle (solo en Hold)
        if (state == 'Hold') {
          spindle = spindle > 0 ? 0 : 500;
        }
      case 0x84: // safety door
        state = 'Door';
    }
  }

  @override
  void writeBytes(Uint8List bytes) {
    for (final int byte in bytes) {
      writeRealtime(byte);
    }
  }

  /// Línea de status report coherente con el estado emulado.
  String statusLine() {
    return '<$state|MPos:10.000,20.000,5.000|'
        'FS:${feed.round()},${spindle.round()}|WCO:0.000,0.000,0.000>';
  }

  /// Inyecta una línea arbitraria (respuestas, alarmas, `[MSG:]`...).
  void emitLine(String line) {
    if (!_lines.isClosed) {
      _lines.add(line);
    }
  }

  /// Simula una respuesta `error:` a la última línea enviada.
  void emitError(String error) => emitLine(error);
}
