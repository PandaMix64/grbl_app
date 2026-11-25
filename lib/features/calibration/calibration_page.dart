import 'package:material_ui/material_ui.dart';

import '../../core/widgets/phase_placeholder.dart';

/// Calibración de ejes, parámetros `$` y perfiles de máquina.
class CalibrationPage extends StatelessWidget {
  const CalibrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhasePlaceholder(
      title: 'Calibración',
      phase: 'Fase 2',
      icon: Icons.straighten,
      description:
          r'Jogging con `$J=` y cancelación con 0x85, cálculo de pasos/mm, '
          'lectura y escritura de parámetros GRBL, perfiles de máquina y '
          'compensación de holgura con movimiento real (nunca con G92).',
    );
  }
}
