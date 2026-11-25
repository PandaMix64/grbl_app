import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/app.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';

import 'helpers/fake_serial_port.dart';

void main() {
  late FakeSerialPort port;
  late GrblWorkerClient client;
  late AppDatabase database;

  setUp(() {
    port = FakeSerialPort();
    client = GrblWorkerClient.inProcess(port: port);
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await client.dispose();
    await database.close();
  });

  Widget buildApp() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      grblWorkerProvider.overrideWith((Ref ref) => client),
    ],
    child: const GrblApp(),
  );

  /// Deja avanzar el event loop real (los `SendPort`/`ReceivePort` del worker
  /// no se mueven con el reloj falso de `testWidgets`) y repinta.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets('arranca en Inicio con la barra de conexión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Conexión'), findsOneWidget);
    expect(find.text('Conectar'), findsOneWidget);
    expect(find.text('Pendiente — Fase 1'), findsOneWidget);
    expect(find.text('FAKE0'), findsOneWidget);
  });

  testWidgets('el botón de refresco vuelve a enumerar los puertos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    await tester.tap(find.byTooltip('Actualizar puertos'));
    await settle(tester);

    expect(find.text('FAKE0'), findsOneWidget);
    expect(find.text('Sin puertos'), findsNothing);
  });

  testWidgets('cambia de módulo al pulsar un destino', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    await tester.tap(find.text('Calibración').first);
    await tester.pump();

    expect(find.text('Pendiente — Fase 2'), findsOneWidget);
  });
}
