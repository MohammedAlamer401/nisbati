import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/app/app.dart';
import 'package:nisbati/core/database/app_database.dart';
import 'package:nisbati/core/security/biometric_service.dart';
import 'package:nisbati/core/security/pin_hasher.dart';
import 'package:nisbati/core/security/secure_store.dart';
import 'package:nisbati/core/widgets/pin_entry.dart';
import 'package:nisbati/features/auth/application/auth_controller.dart';
import 'package:nisbati/features/auth/data/auth_repository.dart';
import 'package:nisbati/features/profile/data/profile_repository.dart';
import 'package:nisbati/features/settings/data/settings_repository.dart';
import 'package:nisbati/features/splash/presentation/splash_screen.dart';

class FakeBiometricService implements BiometricService {
  FakeBiometricService({this.available = BiometricAvailability.available, this.result = BiometricResult.success});

  BiometricAvailability available;
  BiometricResult result;
  var prompts = 0;

  @override
  Future<BiometricAvailability> availability() async => available;

  @override
  Future<BiometricResult> authenticate(String reason) async {
    prompts++;
    return result;
  }
}

/// تطبيق كامل بقاعدة في الذاكرة وتخزين آمن وهمي وبصمة وهمية.
class TestApp {
  TestApp({FakeBiometricService? biometric})
      : biometric = biometric ?? FakeBiometricService(),
        db = AppDatabase(NativeDatabase.memory()),
        store = MemorySecureStore();

  final AppDatabase db;
  final MemorySecureStore store;
  final FakeBiometricService biometric;

  static const hasher = PinHasher(iterations: 1000, useIsolate: false);

  AuthRepository get auth => AuthRepository(store, hasher);

  /// مستخدم أنهى التشغيل الأول سابقاً.
  Future<void> seedExistingUser({String pin = '482915', bool biometricEnabled = false}) async {
    await ProfileRepository(db).save(const ProfileInput(fullName: 'أحمد محمد', businessName: 'فني شبكات'));
    await SettingsRepository(db).write(SettingKeys.onboardingStep, OnboardingStep.done.name);
    await auth.setPin(pin);
    await auth.setBiometricEnabled(biometricEnabled);
  }

  Future<void> pump(WidgetTester tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureStoreProvider.overrideWithValue(store),
        pinHasherProvider.overrideWithValue(hasher),
        biometricServiceProvider.overrideWithValue(biometric),
        appInitProvider.overrideWith((ref) async {}),
      ],
      child: const NisbatiApp(),
    ));
    await tester.pump();
    await tester.pump(SplashScreen.minimumDuration);
    await settle(tester);
  }
}

/// اختبار واجهة على [TestApp] جديد، يُفكّ في نهايته قبل أن يتحقق الإطار من المؤقتات.
///
/// drift يجدول مؤقتاً صفرياً عند إغلاق تدفقات الاستعلام، فيُمرَّر الزمن بعد الفك.
/// القاعدة في الذاكرة لا تُغلق صراحةً: إغلاقها ينتظر عملاً في الزمن الوهمي.
void appTest(
  String description,
  Future<void> Function(WidgetTester tester, TestApp app) body, {
  FakeBiometricService? biometric,
}) {
  testWidgets(description, (tester) async {
    final app = TestApp(biometric: biometric);
    await body(tester, app);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}

/// يمرّر إلى العنصر إن كان خارج الشاشة ثم يضغطه.
///
/// الانتظار قبل التمرير وبعده يترك حركة «إظهار المؤشر» للحقل النشط تنتهي،
/// وإلا يتحرك العنصر بعد حساب موضع الضغط.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(milliseconds: 300));
  // إلى منتصف الشاشة إن أمكن، بعيداً عن الرسائل العائمة أسفلها.
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
  await settle(tester);
}

/// ينتظر انتهاء الانتقالات والعمليات غير المتزامنة (قاعدة البيانات في الذاكرة).
///
/// عدد ثابت من الإطارات بدل `pumpAndSettle`، لأن مؤشر الكتابة الوامض في حقل
/// نشط لا يستقر أبداً.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
}

/// يكتب رمزاً بالضغط على أزرار لوحة الأرقام.
Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.descendant(of: find.byType(PinEntry), matching: find.text(digit)));
    await tester.pump();
  }
  await settle(tester);
}
