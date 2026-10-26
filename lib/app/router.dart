import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/change_pin_screen.dart';
import '../features/auth/presentation/forgot_pin_screen.dart';
import '../features/auth/presentation/lock_screen.dart';
import '../features/auth/presentation/new_recovery_code_screen.dart';
import '../features/auth/presentation/pin_verify_screen.dart';
import '../features/backup/presentation/backup_screen.dart';
import '../features/clients/presentation/client_details_screen.dart';
import '../features/clients/presentation/client_form_screen.dart';
import '../features/clients/presentation/clients_screen.dart';
import '../features/collections/presentation/collection_form_screen.dart';
import '../features/collections/presentation/collections_log_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/onboarding/presentation/biometric_step_screen.dart';
import '../features/onboarding/presentation/pin_step_screen.dart';
import '../features/onboarding/presentation/preferences_step_screen.dart';
import '../features/onboarding/presentation/profile_step_screen.dart';
import '../features/onboarding/presentation/recovery_step_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/services/presentation/service_details_screen.dart';
import '../features/services/presentation/service_form_screen.dart';
import '../features/services/presentation/services_screen.dart';
import '../features/settings/presentation/service_types_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/presentation/splash_screen.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const lock = '/lock';
  static const forgotPin = '/lock/forgot';

  static const dashboard = '/';
  static const clients = '/clients';
  static const services = '/services';
  static const reports = '/reports';
  static const settings = '/settings';

  static const profile = '/settings/profile';
  static const changePin = '/settings/change-pin';
  static const newRecoveryCode = '/settings/recovery-code';
  static const verifyPin = '/settings/verify-pin';

  static const newClient = '/clients/new';
  static String clientDetails(int id) => '/clients/$id';
  static String editClient(int id) => '/clients/$id/edit';

  static String newService({int? clientId}) =>
      Uri(path: '/services/new', queryParameters: clientId == null ? null : {'clientId': '$clientId'}).toString();
  static const outstandingServices = '/services?outstanding=1';
  static String serviceDetails(int id) => '/services/$id';
  static String editService(int id) => '/services/$id/edit';
  static String newCollection(int serviceId) => '/services/$serviceId/collect';
  static String collections(int serviceId) => '/services/$serviceId/collections';
  static String editCollection(int serviceId, int collectionId) =>
      '/services/$serviceId/collections/$collectionId/edit';

  static const serviceTypes = '/settings/service-types';
  static const backup = '/settings/backup';

  static String onboardingStep(OnboardingStep step) => '$onboarding/${step.name}';
}

/// يوجّه حسب حالة الدخول (القسم 9.1).
String? authRedirect(AuthState auth, GoRouterState state) {
  final location = state.matchedLocation;
  final inLock = location.startsWith(AppRoutes.lock);
  final inEntry = location == AppRoutes.splash || location.startsWith(AppRoutes.onboarding) || inLock;

  switch (auth.status) {
    case AuthStatus.initializing:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthStatus.onboarding:
      final target = AppRoutes.onboardingStep(auth.step);
      return location == target ? null : target;
    case AuthStatus.locked:
      if (inLock) return null;
      // يُحفظ المسار للعودة إليه بعد فتح القفل.
      if (inEntry) return AppRoutes.lock;
      return Uri(path: AppRoutes.lock, queryParameters: {'from': state.uri.toString()}).toString();
    case AuthStatus.unlocked:
      if (!inEntry) return null;
      final from = state.uri.queryParameters['from'];
      return from != null && from.startsWith('/') ? from : AppRoutes.dashboard;
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

int _id(GoRouterState state) => int.parse(state.pathParameters['id']!);

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => auth.value = next);

  GoRoute fullScreen(String path, Widget Function() build) => GoRoute(
        path: path,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => build(),
      );

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) => authRedirect(auth.value, state),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      for (final (step, screen) in <(OnboardingStep, Widget)>[
        (OnboardingStep.welcome, const WelcomeScreen()),
        (OnboardingStep.profile, const ProfileStepScreen()),
        (OnboardingStep.pin, const PinStepScreen()),
        (OnboardingStep.recovery, const RecoveryStepScreen()),
        (OnboardingStep.biometric, const BiometricStepScreen()),
        (OnboardingStep.preferences, const PreferencesStepScreen()),
      ])
        GoRoute(
          path: AppRoutes.onboardingStep(step),
          pageBuilder: (context, state) => NoTransitionPage(child: screen),
        ),
      GoRoute(
        path: AppRoutes.lock,
        builder: (context, state) => const LockScreen(),
        routes: [GoRoute(path: 'forgot', builder: (context, state) => const ForgotPinScreen())],
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
              builder: (context, state) => const ClientsScreen(),
              routes: [
                fullScreen('new', ClientFormScreen.new),
                // التفاصيل فوق كل الأقسام حتى تُفتح من أي قسم دون تبديل التبويب.
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => ClientDetailsScreen(clientId: _id(state)),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => ClientFormScreen(clientId: _id(state)),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.services,
              // مفتاح حسب الاستعلام: فتح «غير المحصّل» من الرئيسية يعيد ضبط الفلتر.
              builder: (context, state) => ServicesScreen(
                key: ValueKey(state.uri.query),
                initialOutstanding: state.uri.queryParameters['outstanding'] == '1',
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => ServiceFormScreen(
                    initialClientId: int.tryParse(state.uri.queryParameters['clientId'] ?? ''),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => ServiceDetailsScreen(serviceId: _id(state)),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => ServiceFormScreen(serviceId: _id(state)),
                    ),
                    GoRoute(
                      path: 'collect',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => CollectionFormScreen(serviceId: _id(state)),
                    ),
                    GoRoute(
                      path: 'collections',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => CollectionsLogScreen(serviceId: _id(state)),
                      routes: [
                        GoRoute(
                          path: ':cid/edit',
                          parentNavigatorKey: _rootNavigatorKey,
                          builder: (context, state) => CollectionFormScreen(
                            serviceId: _id(state),
                            collectionId: int.parse(state.pathParameters['cid']!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.reports,
              builder: (context, state) => const ReportsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
              routes: [
                fullScreen('profile', ProfileScreen.new),
                fullScreen('change-pin', ChangePinScreen.new),
                fullScreen('recovery-code', NewRecoveryCodeScreen.new),
                fullScreen('verify-pin', PinVerifyScreen.new),
                fullScreen('service-types', ServiceTypesScreen.new),
                fullScreen('backup', BackupScreen.new),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    auth.dispose();
  });
  return router;
});
