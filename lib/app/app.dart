import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/nisbati_logo.dart';
import '../features/auth/application/auth_controller.dart';
import 'router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class NisbatiApp extends ConsumerStatefulWidget {
  const NisbatiApp({super.key});

  @override
  ConsumerState<NisbatiApp> createState() => _NisbatiAppState();
}

class _NisbatiAppState extends ConsumerState<NisbatiApp> {
  late final AppLifecycleListener _lifecycle;
  var _obscured = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider.notifier);
    _lifecycle = AppLifecycleListener(
      onHide: auth.onHidden,
      onResume: auth.onResumed,
      onStateChange: (state) {
        // تغطية المحتوى في قائمة التطبيقات الأخيرة (القسم 6.4).
        final obscured = state != AppLifecycleState.resumed;
        if (obscured != _obscured) setState(() => _obscured = obscured);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // شاشة القفل نفسها ليست حساسة، ونافذة البصمة تجعل التطبيق «غير نشط» فوقها.
    final unlocked = ref.watch(authControllerProvider).status == AuthStatus.unlocked;
    return MaterialApp.router(
      title: 'نسبتي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      // العربية فقط؛ الاتجاه RTL يأتي من اللغة تلقائياً.
      locale: const Locale('ar', 'LY'),
      supportedLocales: const [Locale('ar', 'LY'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Stack(
        children: [
          child!,
          if (_obscured && unlocked)
            const Positioned.fill(
              child: ColoredBox(
                color: AppColors.background,
                child: Center(child: NisbatiLogo(size: 120)),
              ),
            ),
        ],
      ),
    );
  }
}
