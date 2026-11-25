import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'calibration_controller.dart';
import 'widgets/jog_panel.dart';
import 'widgets/profiles_panel.dart';
import 'widgets/settings_panel.dart';
import 'widgets/steps_panel.dart';

/// Calibración de ejes, parámetros `$`, pasos/mm y perfiles de máquina.
class CalibrationPage extends ConsumerStatefulWidget {
  const CalibrationPage({super.key});

  @override
  ConsumerState<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends ConsumerState<CalibrationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref.read(calibrationControllerProvider.notifier).loadProfiles(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final CalibrationUiState state = ref.watch(calibrationControllerProvider);
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Calibración', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            if (state.error != null)
              _Notice(
                text: state.error!,
                icon: Icons.error_outline,
                color: theme.colorScheme.error,
              ),
            if (state.message != null)
              _Notice(
                text: state.message!,
                icon: Icons.info_outline,
                color: theme.colorScheme.primary,
              ),
            const JogPanel(),
            const SizedBox(height: 16),
            const SettingsPanel(),
            const SizedBox(height: 16),
            const StepsCalibrationPanel(),
            const SizedBox(height: 16),
            const ProfilesPanel(),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon, required this.color});

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
