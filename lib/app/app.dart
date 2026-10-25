import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class NisbatiApp extends ConsumerWidget {
  const NisbatiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'نسبتي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      // العربية فقط؛ الاتجاه RTL يأتي من اللغة تلقائياً.
      locale: const Locale('ar', 'LY'),
      supportedLocales: const [Locale('ar', 'LY'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
