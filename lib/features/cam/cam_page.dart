import 'package:material_ui/material_ui.dart';

import '../../core/widgets/phase_placeholder.dart';

/// Generador de G-code a partir de imágenes (vectorización, dithering, relieve).
class CamPage extends StatelessWidget {
  const CamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhasePlaceholder(
      title: 'CAM',
      phase: 'Fase 4',
      icon: Icons.auto_fix_high,
      description:
          'Procesamiento de imágenes en isolate: detección de bordes y '
          'vectorización, umbrales/dithering láser con M4 y mapa de altitud '
          '2.5D. Previsualización obligatoria antes del envío.',
    );
  }
}
