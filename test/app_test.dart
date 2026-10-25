import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/security/biometric_service.dart';
import 'package:nisbati/features/auth/data/auth_repository.dart';

import 'helpers/test_app.dart';

/// من الترحيب حتى شاشة رمز الاسترداد بالاسم والرمز المعطيين.
Future<void> onboardUntilRecovery(WidgetTester tester, {String pin = '482915'}) async {
  await tapVisible(tester, find.text('ابدأ'));
  await tester.enterText(find.byType(TextFormField).first, 'أحمد محمد');
  await tapVisible(tester, find.text('التالي'));
  await enterPin(tester, pin);
  await enterPin(tester, pin);
}

Future<void> confirmRecoveryAndContinue(WidgetTester tester) async {
  await tapVisible(tester, find.byType(CheckboxListTile));
  await tapVisible(tester, find.widgetWithText(FilledButton, 'التالي'));
}

void main() {
  group('التشغيل الأول (القسم 6.2)', () {
    appTest('تثبيت جديد: الإقلاع ثم الترحيب، ويمسح أسرار تثبيت سابق', (tester, app) async {
      app.store.values[SecureKeys.pinHash] = 'stale-from-old-install';
      await app.pump(tester);

      expect(find.text('كل خدمة ... لها حقك'), findsOneWidget);
      expect(find.text('ابدأ'), findsOneWidget);
      expect(app.store.values, isEmpty);
    });

    appTest('المسار الكامل حتى الرئيسية', (tester, app) async {
      await app.pump(tester);

      await tapVisible(tester, find.text('ابدأ'));
      expect(find.text('عرّفنا بنفسك'), findsOneWidget);
      expect(find.text('1 من 5'), findsOneWidget);

      // الاسم مطلوب.
      await tapVisible(tester, find.text('التالي'));
      expect(find.text('الاسم مطلوب'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'أحمد محمد');
      await tapVisible(tester, find.text('التالي'));

      // الرمز: رفض الضعيف، ثم عدم التطابق، ثم النجاح.
      expect(find.text('أنشئ رمز الدخول'), findsOneWidget);
      await enterPin(tester, '123456');
      expect(find.text('اختر رمزاً أصعب تخميناً'), findsOneWidget);
      await enterPin(tester, '482915');
      expect(find.text('أعد إدخال الرمز للتأكيد'), findsOneWidget);
      await enterPin(tester, '482916');
      expect(find.text('الرمزان غير متطابقين، أعد المحاولة'), findsOneWidget);
      await enterPin(tester, '482915');
      await enterPin(tester, '482915');
      expect(await app.auth.hasPin(), isTrue);

      // رمز الاسترداد: لا متابعة قبل تأكيد الحفظ.
      expect(find.text('احفظ رمز الاسترداد'), findsOneWidget);
      final next = find.widgetWithText(FilledButton, 'التالي');
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      await confirmRecoveryAndContinue(tester);

      // البصمة: ليس الآن.
      expect(find.text('افتح التطبيق ببصمتك'), findsOneWidget);
      await tapVisible(tester, find.text('ليس الآن'));

      expect(find.text('إعدادات الحساب'), findsOneWidget);
      await tapVisible(tester, find.text('ابدأ استخدام التطبيق'));

      expect(find.text('ملخص أعمالي'), findsOneWidget);
      expect(find.text('مرحباً، أحمد'), findsOneWidget);
      expect(await app.auth.isBiometricEnabled(), isFalse);
    });

    appTest('تفعيل البصمة أثناء الإعداد', (tester, app) async {
      await app.pump(tester);
      await onboardUntilRecovery(tester);
      await confirmRecoveryAndContinue(tester);

      await tapVisible(tester, find.text('تفعيل البصمة'));
      expect(app.biometric.prompts, 1);
      expect(await app.auth.isBiometricEnabled(), isTrue);
      expect(find.text('إعدادات الحساب'), findsOneWidget);
    });

    appTest(
      'جهاز بلا بصمة: خطوة البصمة تُتخطى تلقائياً',
      biometric: FakeBiometricService(available: BiometricAvailability.unsupported),
      (tester, app) async {
        await app.pump(tester);
        await onboardUntilRecovery(tester);
        await confirmRecoveryAndContinue(tester);

        expect(find.text('افتح التطبيق ببصمتك'), findsNothing);
        expect(find.text('إعدادات الحساب'), findsOneWidget);
      },
    );
  });

  group('شاشة القفل (القسم 6.3)', () {
    appTest('مستخدم موجود: القفل، ثم رمز خاطئ، ثم صحيح', (tester, app) async {
      await app.seedExistingUser();
      await app.pump(tester);

      expect(find.text('مرحباً، أحمد'), findsOneWidget);
      expect(find.text('أدخل رمز الدخول'), findsOneWidget);

      await enterPin(tester, '111222');
      expect(find.text('الرمز غير صحيح'), findsOneWidget);

      await enterPin(tester, '482915');
      expect(find.text('ملخص أعمالي'), findsOneWidget);
    });

    appTest('البصمة المفعّلة تفتح التطبيق تلقائياً', (tester, app) async {
      await app.seedExistingUser(biometricEnabled: true);
      await app.pump(tester);

      expect(app.biometric.prompts, 1);
      expect(find.text('ملخص أعمالي'), findsOneWidget);
    });

    appTest(
      'حذف البصمات من الجهاز يعطّل الخيار مع رسالة',
      biometric: FakeBiometricService(available: BiometricAvailability.notEnrolled),
      (tester, app) async {
        await app.seedExistingUser(biometricEnabled: true);
        await app.pump(tester);

        expect(app.biometric.prompts, 0);
        expect(find.textContaining('البصمة غير متاحة الآن'), findsOneWidget);
        expect(await app.auth.isBiometricEnabled(), isFalse);
      },
    );

    appTest('قفل التطبيق الآن من الإعدادات ثم العودة إليها', (tester, app) async {
      await app.seedExistingUser();
      await app.pump(tester);
      await enterPin(tester, '482915');

      await tapVisible(tester, find.text('الإعدادات'));
      expect(find.text('أحمد محمد'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('قفل التطبيق الآن'), 200);
      await tapVisible(tester, find.text('قفل التطبيق الآن'));

      expect(find.text('أدخل رمز الدخول'), findsOneWidget);
      await enterPin(tester, '482915');
      // يعود إلى الإعدادات لا إلى الرئيسية.
      expect(find.text('الأمان'), findsOneWidget);
      expect(find.text('ملخص أعمالي'), findsNothing);
    });

    appTest('نسيت الرمز: رمز الاسترداد ثم رمز جديد', (tester, app) async {
      await app.seedExistingUser();
      final recovery = await app.auth.createRecoveryCode();
      await app.pump(tester);

      await tapVisible(tester, find.text('نسيت الرمز؟'));
      await tester.enterText(find.byType(TextFormField).first, recovery.toLowerCase());
      await tapVisible(tester, find.text('تحقق'));

      expect(find.text('أنشئ رمزاً جديداً'), findsOneWidget);
      await enterPin(tester, '735142');
      await enterPin(tester, '735142');

      expect(find.text('احفظ رمز الاسترداد'), findsOneWidget);
      expect(await app.auth.verifyRecoveryCode(recovery), isA<SecretRejected>());
      expect(await app.auth.verifyPin('735142'), isA<SecretAccepted>());
    });
  });

  group('الواجهة بعد الدخول', () {
    Future<void> unlock(WidgetTester tester, TestApp app) async {
      await app.seedExistingUser();
      await app.pump(tester);
      await enterPin(tester, '482915');
    }

    appTest('الرئيسية بالعربية واتجاه RTL، و«الرئيسية» أول عنصر من اليمين', (tester, app) async {
      await unlock(tester, app);
      expect(find.text('مستحقاتي خلال الفترة'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('ملخص أعمالي'))), TextDirection.rtl);
      expect(tester.getCenter(find.text('الرئيسية')).dx, greaterThan(tester.getCenter(find.text('الإعدادات')).dx));
    });

    appTest('التنقل بين الأقسام', (tester, app) async {
      await unlock(tester, app);
      await tapVisible(tester, find.text('العملاء'));
      expect(find.text('لا يوجد عملاء بعد'), findsOneWidget);

      await tapVisible(tester, find.text('الرئيسية'));
      await tapVisible(tester, find.text('أضف أول خدمة'));
      expect(find.text('لا توجد خدمات بعد'), findsOneWidget);
    });

    appTest('لا تجاوز للحدود على شاشة 360dp مع تكبير الخط 130%', (tester, app) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await app.seedExistingUser();
      await app.pump(tester);
      expect(tester.takeException(), isNull);
      await enterPin(tester, '482915');
      expect(tester.takeException(), isNull);
    });
  });
}
