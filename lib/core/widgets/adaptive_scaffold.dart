import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/responsive.dart';

class _Dest {
  const _Dest(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Mobilde alt gezinme çubuğu, masaüstünde yan menü (NavigationRail) gösterir.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _Dest(Icons.home_outlined, Icons.home, 'Ana Sayfa'),
    _Dest(Icons.quiz_outlined, Icons.quiz, 'KPSS Matik'),
    _Dest(Icons.work_outline, Icons.work, 'Atamalar'),
    _Dest(Icons.settings_outlined, Icons.settings, 'Ayarlar'),
  ];

  void _onSelect(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = navigationShell.currentIndex;

    if (isDesktopWidth(context)) {
      final extended = MediaQuery.sizeOf(context).width >= 1200;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: extended,
              labelType:
                  extended ? null : NavigationRailLabelType.all,
              selectedIndex: selected,
              onDestinationSelected: _onSelect,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: _onSelect,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
