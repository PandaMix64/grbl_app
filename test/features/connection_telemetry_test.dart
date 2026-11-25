import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/features/connection/connection_controller.dart';

import '../helpers/fake_serial_port.dart';

Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
  String? reason,
}) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) {
      fail('Timeout esperando: ${reason ?? 'condición'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late FakeSerialPort port;
  late GrblWorkerClient client;
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    port = FakeSerialPort();
    client = GrblWorkerClient.inProcess(port: port);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        grblWorkerProvider.overrideWith((Ref ref) => client),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await client.dispose();
    await database.close();
  });

  ConnectionUiState state() => container.read(connectionControllerProvider);
  List<double>? position() => state().workPosition;

  Future<void> connect() async {
    final ConnectionController connection = container.read(
      connectionControllerProvider.notifier,
    );
    await connection.refreshPorts();
    await connection.connect();
    expect(state().isConnected, isTrue);
    await client.stopPolling();
  }

  test('resuelve WPos con el WCO memorizado si el reporte no lo trae', () async {
    await connect();

    port.emitLine(
      '<Idle|MPos:10.000,20.000,5.000|FS:0,0|WCO:1.000,2.000,0.000>',
    );
    await waitUntil(() => position()?.first == 9.0, reason: 'primer WPos');

    // GRBL omite `WCO` en la mayoría de reportes: debe usar el último conocido.
    port.emitLine('<Idle|MPos:12.000,22.000,5.000|FS:0,0>');
    await waitUntil(() => position()?.first == 11.0, reason: 'WPos sin WCO');

    expect(position(), <double>[11.0, 20.0, 5.0]);
    expect(state().positionIsLive, isTrue);
  });

  test('conserva la última posición si el reporte no trae ninguna', () async {
    await connect();

    port.emitLine('<Idle|MPos:10.000,20.000,5.000|FS:0,0>');
    await waitUntil(() => position() != null, reason: 'posición inicial');

    port.emitLine('<Idle|FS:0,0>');
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(position(), isNotNull);
    expect(position(), <double>[10.0, 20.0, 5.0]);
    expect(state().positionIsLive, isFalse);
  });

  test('descarta posiciones no finitas', () async {
    await connect();

    port.emitLine('<Idle|MPos:NaN,20.000,5.000|FS:0,0>');
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(position(), anyOf(isNull, isNot(contains(double.nan))));
    expect(state().machineState.isMoving, isFalse);
  });
}
