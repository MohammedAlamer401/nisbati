import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_svg_icon.dart';

/// الصدفة الرئيسية مع شريط التنقل السفلي (القسم 9.2).
///
/// الاتجاه RTL يجعل «الرئيسية» أول عنصر من اليمين تلقائياً.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    NavigationDestination(
      icon: AppSvgIcon(AppSvgIcons.home, muted: true),
      selectedIcon: AppSvgIcon(AppSvgIcons.home),
      label: 'الرئيسية',
    ),
    NavigationDestination(
      icon: AppSvgIcon(AppSvgIcons.clients, muted: true),
      selectedIcon: AppSvgIcon(AppSvgIcons.clients),
      label: 'العملاء',
    ),
    NavigationDestination(
      icon: AppSvgIcon(AppSvgIcons.services, muted: true),
      selectedIcon: AppSvgIcon(AppSvgIcons.services),
      label: 'الخدمات',
    ),
    NavigationDestination(
      icon: AppSvgIcon(AppSvgIcons.reports, muted: true),
      selectedIcon: AppSvgIcon(AppSvgIcons.reports),
      label: 'التقارير',
    ),
    NavigationDestination(
      icon: AppSvgIcon(AppSvgIcons.settings, muted: true),
      selectedIcon: AppSvgIcon(AppSvgIcons.settings),
      label: 'الإعدادات',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: destinations,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
