import 'package:material_ui/material_ui.dart';

import '../../core/widgets/phase_placeholder.dart';

/// Pantalla principal: conexión, perfil activo, accesos a módulos e historial.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhasePlaceholder(
      title: 'Inicio',
      phase: 'Fase 1',
      icon: Icons.link_outlined,
      description:
          'Barra de conexión serial (puerto, velocidad e indicador de estado '
          'Idle/Run/Hold/Alarm/Disconnected), selector de perfil de máquina y '
          'accesos a los módulos. Requiere el núcleo serial de la Fase 1.',
    );
  }
}
