import 'package:material_ui/material_ui.dart';

import 'home_shell.dart';

/// Raíz de la aplicación.
///
/// Tema oscuro de alto contraste por defecto (entorno de taller) y localización
/// en español desde el primer commit, tal como recomienda la revisión técnica
/// (P2-6): retrofitear traducciones en un CNC es caro por la cantidad de
/// mensajes de seguridad.
class GrblApp extends StatelessWidget {
  const GrblApp({super.key});

  /// Verde de seguridad industrial: buen contraste sobre superficies oscuras.
  static const Color _seedColor = Color(0xFF00E5A0);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GRBL CNC',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _buildTheme(Brightness.dark),
      darkTheme: _buildTheme(Brightness.dark),
      locale: const Locale('es'),
      supportedLocales: const <Locale>[Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeShell(),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
        contrastLevel: 0.6,
      ),
    );
  }
}
