import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/data/serial/serial_line_buffer.dart';

void main() {
  test('reensambla líneas partidas y quita el terminador \\r', () {
    final SerialLineBuffer buffer = SerialLineBuffer();
    const String help = " [\$' for help]";

    expect(buffer.add('ok\r'), isEmpty);
    expect(buffer.add('\nGrbl 1.1h'), <String>['ok']);
    expect(buffer.add('$help\r\n\r\n'), <String>['Grbl 1.1h$help']);
    expect(buffer.add('ok\r\n'), <String>['ok']);
  });

  test('entrega varias líneas de un solo fragmento', () {
    final SerialLineBuffer buffer = SerialLineBuffer();

    expect(buffer.add('<Idle|MPos:0.000,0.000,0.000>\r\nok\r\n'), <String>[
      '<Idle|MPos:0.000,0.000,0.000>',
      'ok',
    ]);
    expect(buffer.add('error:2\r\n'), <String>['error:2']);
  });

  test('clear descarta el fragmento incompleto', () {
    final SerialLineBuffer buffer = SerialLineBuffer();

    expect(buffer.add('Grbl 1.1h'), isEmpty);
    buffer.clear();
    expect(buffer.add('\r\n'), isEmpty);
    expect(buffer.add('ok\r\n'), <String>['ok']);
  });
}
