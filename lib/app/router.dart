import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_svg_icon.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/placeholders/section_placeholder_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/presentation/splash_screen.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const dashboard = '/';
  static const clients = '/clients';
  static const services = '/services';
  static const reports = '/reports';
  static const settings = '/settings';
}

/// التوجيه (القسم 9). توجيه حالات الدخول (onboarding / lock) يُضاف في المرحلة 3.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.dashboard,
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.clients,
              builder: (context, state) => const SectionPlaceholderScreen(
                title: 'العملاء',
                icon: AppSvgIcons.clients,
                emptyTitle: 'لا يوجد عملاء بعد',
                phase: 4,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.services,
              builder: (context, state) => const SectionPlaceholderScreen(
                title: 'الخدمات',
                icon: AppSvgIcons.services,
                emptyTitle: 'لا توجد خدمات بعد',
                phase: 5,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.reports,
              builder: (context, state) => const SectionPlaceholderScreen(
                title: 'التقارير',
                icon: AppSvgIcons.reports,
                emptyTitle: 'لا توجد بيانات لعرضها',
                phase: 7,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SectionPlaceholderScreen(
                title: 'الإعدادات',
                icon: AppSvgIcons.settings,
                emptyTitle: 'الإعدادات',
                phase: 3,
              ),
            ),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
