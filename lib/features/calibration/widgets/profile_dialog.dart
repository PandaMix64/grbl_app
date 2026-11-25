import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/machine_profile.dart';

/// Formulario de creación/edición de un perfil de máquina.
///
/// Valida con `MachineProfile.validate()` antes de devolver el perfil, de modo
/// que no se guarda un volumen de trabajo imposible.
class ProfileDialog extends StatefulWidget {
  const ProfileDialog({this.profile, super.key});

  final MachineProfile? profile;

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _travelX;
  late final TextEditingController _travelY;
  late final TextEditingController _travelZ;
  late final TextEditingController _safeZ;
  late final TextEditingController _backlashX;
  late final TextEditingController _backlashY;
  late final TextEditingController _feed;
  late final TextEditingController _spindle;
  late ToolType _tool;
  String? _error;

  @override
  void initState() {
    super.initState();
    final MachineProfile? profile = widget.profile;
    _name = TextEditingController(text: profile?.name ?? '');
    _travelX = TextEditingController(text: _fmt(profile?.travelXmm ?? 300));
    _travelY = TextEditingController(text: _fmt(profile?.travelYmm ?? 180));
    _travelZ = TextEditingController(text: _fmt(profile?.travelZmm ?? 45));
    _safeZ = TextEditingController(text: _fmt(profile?.safeZmm ?? 5));
    _backlashX = TextEditingController(text: _fmt(profile?.backlashXmm ?? 0));
    _backlashY = TextEditingController(text: _fmt(profile?.backlashYmm ?? 0));
    _feed = TextEditingController(text: _fmt(profile?.defaultFeedMmMin ?? 800));
    _spindle = TextEditingController(
      text: _fmt(profile?.maxSpindleRpm ?? 1000),
    );
    _tool = profile?.tool ?? ToolType.mill;
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _travelX,
      _travelY,
      _travelZ,
      _safeZ,
      _backlashX,
      _backlashY,
      _feed,
      _spindle,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  static double? _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _save() {
    final MachineProfile profile = MachineProfile(
      id:
          widget.profile?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      tool: _tool,
      travelXmm: _parse(_travelX) ?? 0,
      travelYmm: _parse(_travelY) ?? 0,
      travelZmm: _parse(_travelZ) ?? 0,
      safeZmm: _parse(_safeZ) ?? 0,
      backlashXmm: _parse(_backlashX) ?? 0,
      backlashYmm: _parse(_backlashY) ?? 0,
      defaultFeedMmMin: _parse(_feed) ?? 0,
      maxSpindleRpm: _parse(_spindle) ?? 0,
    );
    final List<String> errors = profile.validate();
    if (errors.isNotEmpty) {
      setState(() => _error = errors.first);
      return;
    }
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.profile == null ? 'Nuevo perfil' : 'Editar perfil'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Text('Herramienta', style: theme.textTheme.labelLarge),
                  const SizedBox(width: 12),
                  DropdownButton<ToolType>(
                    value: _tool,
                    onChanged: (ToolType? tool) {
                      if (tool != null) {
                        setState(() => _tool = tool);
                      }
                    },
                    items: <DropdownMenuItem<ToolType>>[
                      for (final ToolType tool in ToolType.values)
                        DropdownMenuItem<ToolType>(
                          value: tool,
                          child: Text(tool.name),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: _number(_travelX, 'Recorrido X (mm)')),
                  const SizedBox(width: 8),
                  Expanded(child: _number(_travelY, 'Recorrido Y (mm)')),
                  const SizedBox(width: 8),
                  Expanded(child: _number(_travelZ, 'Recorrido Z (mm)')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: _number(_safeZ, 'Altura segura (mm)')),
                  const SizedBox(width: 8),
                  Expanded(child: _number(_backlashX, 'Holgura X (mm)')),
                  const SizedBox(width: 8),
                  Expanded(child: _number(_backlashY, 'Holgura Y (mm)')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: _number(_feed, 'Avance por defecto')),
                  const SizedBox(width: 8),
                  Expanded(child: _number(_spindle, 'Husillo máx. (RPM)')),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  Widget _number(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
