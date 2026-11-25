import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/data/serial/grbl_serial_service.dart';
import 'package:grbl_app/domain/entities/axis.dart';
import 'package:grbl_app/domain/entities/jog_command.dart';
import 'package:grbl_app/domain/entities/machine_state.dart';

import '../helpers/fake_serial_port.dart';

Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) {
      fail('Timeout esperando: ${reason ?? 'condición'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  late FakeSerialPort port;
  late GrblSerialService service;

  setUp(() async {
    port = FakeSerialPort();
    service = GrblSerialService(
      port: port,
      defaultTimeout: const Duration(seconds: 1),
    );
    await service.connect(portName: 'FAKE0');
    service.startStatusPolling(interval: const Duration(milliseconds: 2));
    await waitUntil(() => service.state == MachineState.idle);
  });

  tearDown(() => service.dispose());

  group('jogging', () {
    test('envía el bloque de jog con avance', () async {
      service.jog(
        JogCommand(
          values: <MachineAxis, double>{MachineAxis.x: 1},
          feedMmMin: 500,
        ),
      );

      await waitUntil(
        () => port.writtenLines.any((String line) => line.startsWith(r'$J=')),
      );

      expect(port.writtenLines.last, r'$J=G91 X1.000 F500.000');
    });

    test('rechaza el jog fuera de Idle/Jog', () async {
      port.state = 'Run';
      await waitUntil(() => service.state == MachineState.run);

      expect(
        () => service.jog(
          JogCommand(
            values: <MachineAxis, double>{MachineAxis.y: 1},
            feedMmMin: 500,
          ),
        ),
        throwsA(isA<GrblSafetyException>()),
      );
    });
  });

  group('escritura de parámetros', () {
    test('envía solo los cambios, uno a uno', () async {
      final int written = await service.writeSettings(<int, String>{
        100: '255.102',
        20: '1',
      });

      expect(written, 2);
      expect(
        port.writtenLines,
        containsAllInOrder(<String>[r'$100=255.102', r'$20=1']),
      );
    });

    test('sin cambios no escribe nada', () async {
      final int written = await service.writeSettings(const <int, String>{});

      expect(written, 0);
      expect(
        port.writtenLines.where((String line) => line.startsWith(r'$100=')),
        isEmpty,
      );
    });

    test('un error: al escribir no se silencia', () async {
      port.autoAck = false;

      final Future<int> pending = service.writeSettings(<int, String>{
        100: '255.102',
      });
      await waitUntil(() => port.writtenLines.contains(r'$100=255.102'));
      port.emitError('error:3');

      await expectLater(pending, throwsA(isA<GrblProtocolException>()));
    });
  });
}
