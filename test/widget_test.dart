import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/app/app.dart';

void main() {
  testWidgets('arranca en Inicio con navegación Material 3', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: GrblApp()));

    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Pendiente — Fase 1'), findsOneWidget);
  });

  testWidgets('cambia de módulo al pulsar una destino', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: GrblApp()));

    await tester.tap(find.text('Calibración').first);
    await tester.pumpAndSettle();

    expect(find.text('Pendiente — Fase 2'), findsOneWidget);
  });
}
