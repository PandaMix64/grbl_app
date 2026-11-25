import 'package:material_ui/material_ui.dart';

import '../../core/widgets/phase_placeholder.dart';

/// Visor de proyectos, simulación 3D y ejecución con pausa/reanudación segura.
class ViewerPage extends StatelessWidget {
  const ViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhasePlaceholder(
      title: 'Visor',
      phase: 'Fase 3',
      icon: Icons.view_in_ar,
      description:
          r'Renderizado de trayectorias con CustomPainter, interpretación de '
          'G-code (incluidos arcos I/J/K), pausa con apagado de herramienta y '
          r'reanudación con verificación de `$G` y `$#`.',
    );
  }
}
