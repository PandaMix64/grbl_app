import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/app.dart';
import 'package:grbl_app/app/providers.dart';
import 'package:grbl_app/data/database/app_database.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:material_ui/material_ui.dart';

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
    await tester.pump();

    expect(find.text('Control manual (jog)'), findsOneWidget);
    expect(find.text('Parámetros de GRBL'), findsOneWidget);
    expect(find.text('Pasos por milímetro'), findsOneWidget);
    expect(find.text('Perfiles de máquina'), findsOneWidget);

    await tester.tap(find.text('CAM').first);
    await tester.pump();
    await tester.pump();

    expect(find.text('CAM · Grabado láser'), findsOneWidget);
    expect(find.text('Elegir imagen'), findsOneWidget);
    expect(find.text('Parámetros de grabado'), findsOneWidget);
    expect(find.textContaining('Generar'), findsWidgets);
  });

  testWidgets('el visor carga el ejemplo y dibuja el lienzo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    await tester.tap(find.text('Visor').first);
    await tester.pump();

    expect(find.textContaining('Abre un archivo'), findsOneWidget);

    await tester.tap(find.text('Ejemplo'));
    await tester.pump();

    expect(find.byKey(const Key('viewer-canvas')), findsOneWidget);
    expect(find.textContaining('arcos'), findsOneWidget);
    expect(find.textContaining('segmentos'), findsOneWidget);

    // Centrar el trazado devuelve la vista a su encuadre sin romper el lienzo.
    await tester.tap(find.byTooltip('Centrar trazado'));
    await tester.pump();
    expect(find.byKey(const Key('viewer-canvas')), findsOneWidget);

    // La barra de ejecución compacta vive sobre el lienzo y queda bloqueada sin
    // conexión.
    expect(find.byTooltip('Ejecutar programa'), findsOneWidget);
    expect(
      find.textContaining('Conecta la máquina para ejecutar'),
      findsOneWidget,
    );
    final IconButton runButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Ejecutar programa'),
        matching: find.byType(IconButton),
      ),
    );
    expect(runButton.onPressed, isNull);
  });

  testWidgets('la barra superior ofrece consola y comandos básicos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(find.text('Sin perfil de máquina'), findsOneWidget);
    final IconButton softReset = tester.widget<IconButton>(
      find.byKey(const Key('topbar-soft-reset')),
    );
    expect(softReset.onPressed, isNull);
    final IconButton unlock = tester.widget<IconButton>(
      find.byKey(const Key('topbar-unlock')),
    );
    expect(unlock.onPressed, isNull);

    await tester.tap(find.byKey(const Key('topbar-console')));
    await tester.pumpAndSettle();

    expect(find.text('Consola'), findsOneWidget);
    expect(find.text('Sin tráfico todavía.'), findsOneWidget);
    expect(find.textContaining('Sin conexión'), findsWidgets);
  });
}
