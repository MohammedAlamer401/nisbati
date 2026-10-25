// يلتقط صوراً للشاشات بالخط الحقيقي للمراجعة البصرية (لا يعمل في CI).
// التشغيل: flutter test tool/screenshots_test.dart --update-goldens
// الصور تُحفظ في build/screenshots/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/app/app.dart';
import 'package:nisbati/features/splash/presentation/splash_screen.dart';

Future<void> _loadFonts() async {
  final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
  await cairo.load();
  final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(icons.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [appInitProvider.overrideWith((ref) async {})],
      child: const NisbatiApp(),
    ));
    await tester.pump();
  }

  testWidgets('splash', (tester) async {
    await start(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/screenshots/splash.png'));
    await tester.pump(SplashScreen.minimumDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('dashboard', (tester) async {
    await start(tester);
    await tester.pump(SplashScreen.minimumDuration);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/screenshots/dashboard.png'));
  });
}
