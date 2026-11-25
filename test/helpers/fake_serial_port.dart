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
  final List<void Function()> _heldAcks = <void Function()>[];

  /// Estado que reporta el emulador.
  String state = 'Idle';

  /// Consigna de husillo/láser (`S`) reportada.
  double spindle = 0;

  /// Avance reportado.
  double feed = 800;

  /// Respuesta de `$I`. Vacía para simular un firmware sin build info.
  List<String> buildInfoLines = <String>[
    '[VER:1.1h.20190825:]',
    '[OPT:V,15,128]',
  ];

  /// Respuesta de `$$`.
  List<String> settingsLines = <String>[
    r'$0=10',
    r'$1=25',
    r'$10=1',
    r'$20=1',
    r'$21=0',
    r'$22=1',
    r'$30=1000.000',
    r'$32=1',
    r'$100=250.000',
    r'$101=250.000',
    r'$102=400.000',
    r'$110=500.000',
    r'$111=500.000',
    r'$112=200.000',
    r'$120=10.000',
    r'$121=10.000',
    r'$122=10.000',
    r'$130=300.000',
    r'$131=180.000',
    r'$132=45.000',
  ];

  /// Respuesta de `$G`.
  String parserStateLine = r'[GC:G0 G54 G17 G21 G90 G94 M5 M9 T0 F0 S0]';

  /// Respuesta de `$#`.
  List<String> offsetLines = <String>[
    '[G54:0.000,0.000,0.000]',
    '[G55:0.000,0.000,0.000]',
    '[G56:0.000,0.000,0.000]',
    '[G57:0.000,0.000,0.000]',
    '[G58:0.000,0.000,0.000]',
    '[G59:0.000,0.000,0.000]',
    '[G28:0.000,0.000,0.000]',
    '[G30:0.000,0.000,0.000]',
    '[G92:0.000,0.000,0.000]',
    '[TLO:0.000]',
    '[PRB:0.000,0.000,0.000:0]',
  ];

  /// Si es `true`, cada línea recibe su `ok` (como GRBL en `Idle`).
  set autoAck(bool value) => _autoAck = value;

  /// Retardo artificial de cada `ok`, para simular el ritmo real del puerto.
  Duration ackDelay = Duration.zero;

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
    _applySettingWrite(line);
    final int bytes = line.length + 1;
    _unackedBytes += bytes;
    if (_unackedBytes > peakUnackedBytes) {
      peakUnackedBytes = _unackedBytes;
    }
    if (_unackedBytes > bufferSize) {
      overflowDetected = true;
    }
    for (final String response in _responsesFor(line)) {
      emitLine(response);
    }
    if (_autoAck) {
      void acknowledge() {
        _unackedBytes -= bytes;
        if (_unackedBytes < 0) {
          _unackedBytes = 0;
        }
        emitLine('ok');
      }

      final bool isSystemCommand = line.trimLeft().startsWith(r'$');
      if (state == 'Hold' && !isSystemCommand) {
        // En Hold GRBL deja de vaciar el planificador: los `ok` del programa
        // llegan al enviar cycle start.
        _heldAcks.add(acknowledge);
      } else if (ackDelay == Duration.zero) {
        scheduleMicrotask(acknowledge);
      } else {
        Timer(ackDelay, acknowledge);
      }
    }
  }

  /// Simula la escritura de un parámetro `$x=valor` actualizando la EEPROM
  /// emulada, de modo que una relectura posterior refleje el cambio.
  void _applySettingWrite(String line) {
    final RegExp pattern = RegExp(r'^\$(\d+)=(.+)$');
    final RegExpMatch? match = pattern.firstMatch(line);
    if (match == null) {
      return;
    }
    final String code = match.group(1)!;
    final String value = match.group(2)!.trim();
    final String prefix = '\$$code=';
    settingsLines = <String>[
      for (final String setting in settingsLines)
        if (setting.startsWith(prefix)) '$prefix$value' else setting,
    ];
  }

  /// Respuestas emuladas de los comandos de sistema de GRBL.
  List<String> _responsesFor(String line) {
    switch (line) {
      case r'$I':
        return buildInfoLines;
      case r'$$':
        return settingsLines;
      case r'$G':
        return <String>[parserStateLine];
      case r'$#':
        return offsetLines;
      case r'$X':
        state = 'Idle';
        return const <String>[];
      case r'$H':
        state = 'Idle';
        return const <String>[];
      default:
        return const <String>[];
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
        emitLine(statusLine());
      case 0x7E: // '~'
        state = 'Run';
        emitLine(statusLine());
        final List<void Function()> held = List<void Function()>.of(_heldAcks);
        _heldAcks.clear();
        for (final void Function() acknowledge in held) {
          acknowledge();
        }
      case 0x18: // soft reset
        state = 'Alarm';
        _unackedBytes = 0;
        _heldAcks.clear();
        scheduleMicrotask(() => emitLine(r"Grbl 1.1h ['$' for help]"));
      case 0x85: // jog cancel
        if (state == 'Jog') {
          state = 'Idle';
        }
      case 0x9E: // spindle stop toggle (solo en Hold)
        if (state == 'Hold') {
          spindle = spindle > 0 ? 0 : 500;
          emitLine(statusLine());
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
