import 'package:material_ui/material_ui.dart';

import '../features/calibration/calibration_page.dart';
import '../features/cam/cam_page.dart';
import '../features/home/home_page.dart';
import '../features/viewer/viewer_page.dart';
import 'widgets/app_top_bar.dart';

/// Ancho a partir del cual se usa [NavigationRail] (escritorio) en lugar de
/// [NavigationBar] (móvil). Coincide con el punto de corte de Material 3 para
/// ventanas compactas y evita saltos al redimensionar.
const double kRailBreakpoint = 720;

/// Contenedor principal con la navegación adaptativa de Material 3.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const List<_Destination> _destinations = <_Destination>[
    _Destination(
      label: 'Inicio',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _Destination(
      label: 'Calibración',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune,
    ),
    _Destination(
      label: 'Visor',
      icon: Icons.view_in_ar_outlined,
      selectedIcon: Icons.view_in_ar,
    ),
    _Destination(
      label: 'CAM',
      icon: Icons.auto_fix_high_outlined,
      selectedIcon: Icons.auto_fix_high,
    ),
  ];

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = _ModuleRouter(index: _selectedIndex);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= kRailBreakpoint;
        return Scaffold(
          body: Column(
            children: <Widget>[
              const AppTopBar(),
              const Divider(height: 1),
              Expanded(
                child: wide
                    ? Row(
                        children: <Widget>[
                          NavigationRail(
                            selectedIndex: _selectedIndex,
                            onDestinationSelected: _onDestinationSelected,
                            labelType: NavigationRailLabelType.all,
                            destinations: <NavigationRailDestination>[
                              for (final _Destination destination
                                  in _destinations)
                                NavigationRailDestination(
                                  icon: Icon(destination.icon),
                                  selectedIcon: Icon(destination.selectedIcon),
                                  label: Text(destination.label),
                                ),
                            ],
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: body),
                        ],
                      )
                    : body,
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: <NavigationDestination>[
                    for (final _Destination destination in _destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _ModuleRouter extends StatelessWidget {
  const _ModuleRouter({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return switch (index) {
      0 => const HomePage(),
      1 => const CalibrationPage(),
      2 => const ViewerPage(),
      _ => const CamPage(),
    };
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
