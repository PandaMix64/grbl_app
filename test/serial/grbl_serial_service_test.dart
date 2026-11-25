import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/data/serial/grbl_serial_service.dart';
import 'package:grbl_app/domain/entities/machine_state.dart';
import 'package:grbl_app/domain/entities/status_report.dart';

import '../helpers/fake_serial_port.dart';

/// Espera activa hasta que se cumpla [condition] (máximo [timeout]).
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
    await waitUntil(() => service.lastStatus != null);
  });

  tearDown(() async {
    await service.dispose();
  });

  test('parsea la telemetría del controlador', () {
    final StatusReport? report = service.lastStatus;

    expect(report, isNotNull);
    expect(service.state, MachineState.idle);
    expect(report!.machinePosition, <double>[10, 20, 5]);
    expect(report.isSpindleOn, isFalse);
  });

  test('el streaming mantiene el búfer bajo el límite real', () async {
    final List<String> program = <String>[
      for (int i = 0; i < 500; i++) 'G1 X${i % 50}.000 Y1.000',
    ];

    service.streamGcode(program);
    await waitUntil(() => service.sentBlocks == program.length);

    expect(port.overflowDetected, isFalse);
    expect(port.peakUnackedBytes, lessThanOrEqualTo(128));
    expect(service.buffer.isBusy, isFalse);
  });

  test('un error: libera el presupuesto igual que un ok', () async {
    port.autoAck = false;
    service.streamGcode(<String>['G1 X1', 'G1 X2']);
    await waitUntil(() => port.writtenLines.length >= 2);
    expect(service.buffer.bytesInFlight, 12);

    port.emitError('error:9');

    await waitUntil(() => service.buffer.inFlightCount == 1);
    port.emitLine('ok');
    await waitUntil(() => service.buffer.bytesInFlight == 0);
  });

  test('la pausa apaga la herramienta (SEG-01)', () async {
    port.state = 'Run';
    port.spindle = 800;
    await waitUntil(() => service.state == MachineState.run);

    final StatusReport report = await service.pauseSafely();

    expect(report.state, MachineState.hold);
    expect(report.isSpindleOn, isFalse);
    expect(port.realtimeBytes, containsAllInOrder(<int>[0x21, 0x9E]));
  });

  test('cancelar jog se ignora fuera del estado Jog (SEG-04)', () async {
    port.state = 'Run';
    await waitUntil(() => service.state == MachineState.run);
    final List<String> messages = <String>[];
    final StreamSubscription<String> sub = service.messages.listen(
      messages.add,
    );

    await service.cancelJog();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(port.realtimeBytes, isNot(contains(0x85)));
    expect(
      messages.any((String message) => message.contains('ignorado')),
      isTrue,
    );
    await sub.cancel();
  });

  test('cancelar jog en Jog envía 0x85 y vuelve a Idle', () async {
    port.state = 'Jog';
    await waitUntil(() => service.state == MachineState.jog);

    await service.cancelJog();

    expect(port.realtimeBytes, contains(0x85));
    await waitUntil(() => service.state == MachineState.idle);
  });

  test('no se resetea sin persistir el progreso (SEG-03)', () async {
    port.state = 'Run';
    port.spindle = 600;
    await waitUntil(() => service.state == MachineState.run);

    int resetsWhenPersisted = -1;
    int? bytesWhenPersisted;
    StatusReport? reportPassed;
    await service.stopJob(
      persistProgress: (StatusReport? report) async {
        bytesWhenPersisted = port.realtimeBytes.length;
        resetsWhenPersisted = port.realtimeBytes
            .where((int byte) => byte == 0x18)
            .length;
        reportPassed = report;
      },
    );

    expect(reportPassed, isNotNull);
    expect(bytesWhenPersisted, isNotNull);
    // Lo que importa: al persistir todavía no se había reseteado nada.
    expect(resetsWhenPersisted, 0);
    expect(port.realtimeBytes, contains(0x18));
    expect(
      port.realtimeBytes.indexOf(0x18),
      greaterThanOrEqualTo(bytesWhenPersisted!),
    );
    expect(port.writtenLines, contains(r'$X'));
  });

  test('la reanudación reactiva la herramienta antes de ~', () async {
    port.state = 'Hold';
    port.spindle = 0;
    await waitUntil(() => service.state == MachineState.hold);

    await service.resumeAfterPause(
      toolOnLine: 'M4 S500',
      settle: Duration.zero,
    );

    expect(port.writtenLines, contains('M4 S500'));
    expect(port.realtimeBytes, contains(0x7E));
    await waitUntil(() => service.state == MachineState.run);
  });

  test('rechaza reanudar si no está en Hold ni Door', () async {
    port.state = 'Idle';
    await waitUntil(() => service.state == MachineState.idle);

    await expectLater(
      service.resumeAfterPause(toolOnLine: 'M3 S100', settle: Duration.zero),
      throwsA(isA<GrblSafetyException>()),
    );
  });

  test('no permite pausar si la máquina está detenida', () async {
    await waitUntil(() => service.state == MachineState.idle);

    await expectLater(
      service.pauseSafely(),
      throwsA(isA<GrblSafetyException>()),
    );
  });
}
