// يلتقط صوراً للشاشات بالخط الحقيقي للمراجعة البصرية (لا يعمل في CI).
// التشغيل: flutter test tool/screenshots_test.dart --update-goldens
// الصور تُحفظ في build/screenshots/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/test_app.dart';

Future<void> _loadFonts() async {
  final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
  await cairo.load();
  // خط أيقونات Material من نسخة Flutter المثبتة.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (flutterRoot != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}

Future<void> _shot(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/screenshots/$name.png'));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(_loadFonts);

  appTest('welcome + onboarding', (tester, app) async {
    _phone(tester);
    await app.pump(tester);
    await _shot('01_welcome');
    await tapVisible(tester, find.text('ابدأ'));
    await tester.enterText(find.byType(TextFormField).first, 'أحمد محمد');
    await tester.enterText(find.byType(TextFormField).at(1), 'فني شبكات وكاميرات');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await _shot('02_profile_step');
    await tapVisible(tester, find.text('التالي'));
    await enterPin(tester, '482');
    await _shot('03_pin_step');
    await enterPin(tester, '915');
    await enterPin(tester, '482915');
    await tapVisible(tester, find.byType(CheckboxListTile));
    await tester.scrollUntilVisible(find.text('احفظ رمز الاسترداد'), -200);
    await settle(tester);
    await _shot('04_recovery_step');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'التالي'));
    await _shot('05_biometric_step');
  });

  appTest('lock + settings', (tester, app) async {
    _phone(tester);
    await app.seedExistingUser();
    await app.pump(tester);
    await enterPin(tester, '11');
    await _shot('06_lock');
    await enterPin(tester, '1111');
    await enterPin(tester, '482915');
    await _shot('07_dashboard');
    await tapVisible(tester, find.text('الإعدادات'));
    await _shot('08_settings');
  });
}
