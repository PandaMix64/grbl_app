import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/data/serial/grbl_serial_service.dart';
import 'package:grbl_app/domain/entities/machine_state.dart';

import '../helpers/fake_serial_port.dart';

Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) {
      fail('Timeout esperando el estado del servicio.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late FakeSerialPort port;
  late GrblSerialService service;
  late List<String> console;

  setUp(() async {
    port = FakeSerialPort();
    service = GrblSerialService(
      port: port,
      defaultTimeout: const Duration(seconds: 1),
    );
    console = <String>[];
    service.consoleLines.listen(console.add);
    await service.connect(portName: 'FAKE0');
    service.startStatusPolling(interval: const Duration(milliseconds: 2));
    await waitUntil(() => service.state == MachineState.idle);
  });

  tearDown(() => service.dispose());

  test('envía comandos de consola y refleja el tráfico', () async {
    service.sendConsoleCommand(r'$H');

    await waitUntil(() => port.writtenLines.contains(r'$H'));
    await waitUntil(() => console.contains(r'← ok'));
    expect(console, contains(r'→ $H'));
  });

  test('rechaza comandos que no son de sistema fuera de Idle', () async {
    port.state = 'Run';
    service.startStatusPolling(interval: const Duration(milliseconds: 2));
    await waitUntil(() => service.state == MachineState.run);
    final int before = port.writtenLines.length;

    expect(
      () => service.sendConsoleCommand('G0 X10'),
      throwsA(isA<GrblSafetyException>()),
    );
    expect(port.writtenLines.length, before);
  });

  test('acepta comandos de sistema en Alarm', () async {
    port.state = 'Alarm';
    await waitUntil(() => service.state == MachineState.alarm);

    service.sendConsoleCommand(r'$X');

    await waitUntil(() => port.writtenLines.contains(r'$X'));
    await waitUntil(() => service.state == MachineState.idle);
  });

  test('el soft reset envía 0x18 y espera el banner', () async {
    await service.softReset();

    expect(port.realtimeBytes, contains(0x18));
    expect(console, anyElement(contains('→ soft reset')));
    expect(console, anyElement(startsWith('← Grbl ')));
  });

  test('la telemetría no ensucia la consola', () async {
    service.requestStatus();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(console.where((String line) => line.startsWith('← <')), isEmpty);
  });
}
