import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/data/serial/grbl_serial_service.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/data/serial/grbl_worker.dart';
import 'package:grbl_app/domain/entities/axis.dart';
import 'package:grbl_app/domain/entities/grbl_handshake.dart';
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
  group('handshake del servicio', () {
    late FakeSerialPort port;
    late GrblSerialService service;

    setUp(() {
      port = FakeSerialPort();
      service = GrblSerialService(
        port: port,
        defaultTimeout: const Duration(seconds: 1),
      );
    });

    tearDown(() => service.dispose());

    test('lee build info, EEPROM, estado modal y offsets', () async {
      final GrblHandshake result = await service.connectAndIdentify(
        portName: 'FAKE0',
      );

      expect(result.bannerReceived, isTrue);
      expect(result.buildInfo, isNotNull);
      expect(result.buildInfo!.version, '1.1h');
      expect(result.buildInfo!.buildDate, '20190825');
      expect(result.buildInfo!.hasVariableSpindle, isTrue);
      expect(result.buildInfo!.plannerBlocks, 15);
      expect(result.settings.integer(32), 1);
      expect(result.settings.stepsPerMm(MachineAxis.z), 400);
      expect(result.parserState.isMetric, isTrue);
      expect(result.parserState.workCoordinateSystem, 'G54');
      expect(result.parserState.spindleMode, 'M5');
      expect(result.offsets['G54'], <double>[0, 0, 0]);
      expect(result.rxBufferSize, 128);
    });

    test('detecta un búfer de 256 B y ajusta el presupuesto', () async {
      port.buildInfoLines = <String>['[VER:1.1h.20190825:]', '[OPT:VN,32,256]'];

      final GrblHandshake result = await service.connectAndIdentify(
        portName: 'FAKE0',
      );

      expect(result.buildInfo!.plannerBlocks, 32);
      expect(result.rxBufferSize, 256);
      expect(service.rxBufferSize, 256);
      expect(service.buffer.budget, 255);
    });

    test('no asume 128 B si el firmware no publica build info', () async {
      port.buildInfoLines = <String>[];

      final GrblHandshake result = await service.connectAndIdentify(
        portName: 'FAKE0',
      );

      expect(result.buildInfo, isNull);
      expect(result.rxBufferSize, 128);
      expect(result.firmwareVersion, 'desconocida');
      expect(result.settings.integer(32), 1);
    });

    test('no consulta la EEPROM con la máquina en movimiento', () async {
      await service.connectAndIdentify(portName: 'FAKE0');
      port.state = 'Run';
      service.startStatusPolling(interval: const Duration(milliseconds: 2));
      await waitUntil(() => service.state == MachineState.run);

      await expectLater(
        service.readSettings(),
        throwsA(isA<GrblSafetyException>()),
      );
    });
  });

  group('worker en proceso', () {
    late FakeSerialPort port;
    late GrblWorkerClient client;

    setUp(() {
      port = FakeSerialPort();
      client = GrblWorkerClient.inProcess(port: port);
    });

    tearDown(() => client.dispose());

    test('connect devuelve el handshake por el canal', () async {
      final GrblHandshake handshake = await client.connect(portName: 'FAKE0');

      expect(handshake.buildInfo!.version, '1.1h');
      expect(handshake.settings.integer(32), 1);
      expect(handshake.rxBufferSize, 128);
    });

    test('la telemetría llega al cliente', () async {
      await client.connect(portName: 'FAKE0');
      await client.startPolling(interval: const Duration(milliseconds: 5));

      final report = await client.statusReports.first;

      expect(report.state, MachineState.idle);
    });

    test('stop exige confirmar la persistencia (SEG-03)', () async {
      await client.connect(portName: 'FAKE0');
      port.state = 'Run';
      port.spindle = 500;
      await client.startPolling(interval: const Duration(milliseconds: 5));
      await client.statusReports.firstWhere(
        (report) => report.state == MachineState.run,
      );

      final List<WorkerPersistRequest> requests = <WorkerPersistRequest>[];
      final StreamSubscription<WorkerPersistRequest> sub = client
          .persistRequests
          .listen((WorkerPersistRequest request) {
            requests.add(request);
            request.confirmPersisted();
          });

      await client.stopJob();

      expect(requests, hasLength(1));
      expect(requests.first.status?.state, MachineState.hold);
      expect(port.realtimeBytes, contains(0x18));
      await sub.cancel();
    });

    test('un comando inválido devuelve error tipado al cliente', () async {
      await client.connect(portName: 'FAKE0');

      await expectLater(
        client.resume(toolOnLine: ''),
        throwsA(isA<GrblWorkerException>()),
      );
    });
  });
}
