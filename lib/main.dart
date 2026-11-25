import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';

/// Punto de entrada de la aplicación.
///
/// El árbol completo se envuelve en [ProviderScope] porque toda la gestión de
/// estado y la inyección de dependencias del proyecto usa Riverpod (ADR-001).
void main() {
  runApp(const ProviderScope(child: GrblApp()));
}
