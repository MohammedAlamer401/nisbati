import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/app/app.dart';
import 'package:nisbati/features/splash/presentation/splash_screen.dart';

void main() {
  Future<void> startApp(WidgetTester tester) async {
    // التهيئة الحقيقية تفتح ملف قاعدة البيانات؛ في الاختبار تكتمل فوراً.
    await tester.pumpWidget(ProviderScope(
      overrides: [appInitProvider.overrideWith((ref) async {})],
      child: const NisbatiApp(),
    ));
    await tester.pump();
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await startApp(tester);
    await tester.pump(SplashScreen.minimumDuration);
    await tester.pumpAndSettle();
  }

  testWidgets('شاشة الإقلاع تظهر ثم تنتقل إلى الرئيسية', (tester) async {
    await startApp(tester);
    expect(find.text('نسبتي'), findsOneWidget);
    expect(find.text('حساب مستحقات الخدمات'), findsOneWidget);
    expect(find.text('كل خدمة .. مستحقك محسوب'), findsOneWidget);
    expect(find.text('جاري التحميل...'), findsOneWidget);

    await tester.pump(SplashScreen.minimumDuration);
    await tester.pumpAndSettle();
    expect(find.text('ملخص أعمالي'), findsOneWidget);
  });

  testWidgets('الرئيسية تظهر بالعربية واتجاه RTL', (tester) async {
    await pumpApp(tester);

    expect(find.text('ملخص أعمالي'), findsOneWidget);
    expect(find.text('مستحقاتي خلال الفترة'), findsOneWidget);
    expect(find.text('أضف أول خدمة'), findsOneWidget);

    final direction = Directionality.of(tester.element(find.text('ملخص أعمالي')));
    expect(direction, TextDirection.rtl);
  });

  testWidgets('شريط التنقل: «الرئيسية» أول عنصر من اليمين', (tester) async {
    await pumpApp(tester);

    final home = tester.getCenter(find.text('الرئيسية'));
    final settings = tester.getCenter(find.text('الإعدادات'));
    expect(home.dx, greaterThan(settings.dx));
  });

  testWidgets('التنقل بين الأقسام', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('العملاء'));
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد عملاء بعد'), findsOneWidget);

    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('أضف أول خدمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أضف أول خدمة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد خدمات بعد'), findsOneWidget);
  });

  testWidgets('لا تجاوز للحدود على شاشة 360dp مع تكبير الخط 130%', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);
    expect(tester.takeException(), isNull);
  });
}
