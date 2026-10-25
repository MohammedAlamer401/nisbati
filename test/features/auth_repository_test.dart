import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/security/pin_hasher.dart';
import 'package:nisbati/core/security/secure_store.dart';
import 'package:nisbati/features/auth/data/auth_repository.dart';

void main() {
  late MemorySecureStore store;
  late DateTime now;
  late AuthRepository repo;

  setUp(() {
    store = MemorySecureStore();
    now = DateTime(2026, 10, 25, 10);
    repo = AuthRepository(store, const PinHasher(iterations: 1000, useIsolate: false), clock: () => now);
  });

  Future<void> failTimes(int n) async {
    for (var i = 0; i < n; i++) {
      await repo.verifyPin('000001');
    }
  }

  test('لا يُخزَّن الرمز كنص', () async {
    await repo.setPin('482915');
    expect(await repo.hasPin(), isTrue);
    expect(store.values.values, isNot(contains('482915')));
  });

  test('الرمز الصحيح يُقبل والخاطئ يُرفض ويُعدّ', () async {
    await repo.setPin('482915');
    expect(await repo.verifyPin('482915'), isA<SecretAccepted>());
    final rejected = await repo.verifyPin('111222');
    expect(rejected, isA<SecretRejected>().having((r) => r.failures, 'failures', 1));
  });

  test('5 محاولات خاطئة ← انتظار 30 ثانية يبقى محفوظاً', () async {
    await repo.setPin('482915');
    await failTimes(4);
    expect(await repo.lockedUntil(), isNull);

    final fifth = await repo.verifyPin('000001') as SecretRejected;
    expect(fifth.lockedUntil, now.add(const Duration(seconds: 30)));

    // حتى الرمز الصحيح يُرفض دون تحقق أثناء الانتظار.
    expect(await repo.verifyPin('482915'), isA<SecretLockedOut>());

    // الحالة في التخزين الآمن، فتبقى مع نسخة جديدة من المستودع.
    final reopened = AuthRepository(store, const PinHasher(iterations: 1000, useIsolate: false), clock: () => now);
    expect(await reopened.lockedUntil(), isNotNull);

    now = now.add(const Duration(seconds: 31));
    expect(await repo.verifyPin('482915'), isA<SecretAccepted>());
    expect(await repo.failedAttempts(), 0);
  });

  test('الانتظار يتضاعف بعد المحاولة السادسة', () async {
    await repo.setPin('482915');
    await failTimes(5);
    now = now.add(const Duration(seconds: 31));
    final sixth = await repo.verifyPin('000001') as SecretRejected;
    expect(sixth.failures, 6);
    expect(sixth.lockedUntil, now.add(const Duration(minutes: 1)));
  });

  test('رمز الاسترداد: يُقبل بأي تنسيق، ويُلغى القديم عند إنشاء جديد', () async {
    final first = await repo.createRecoveryCode();
    expect(await repo.verifyRecoveryCode(first.toLowerCase().replaceAll('-', ' ')), isA<SecretAccepted>());

    final second = await repo.createRecoveryCode();
    expect(await repo.verifyRecoveryCode(first), isA<SecretRejected>());
    expect(await repo.verifyRecoveryCode(second), isA<SecretAccepted>());
  });

  group('فرض الرمز بدل البصمة (القسم 6.3)', () {
    setUp(() async {
      await repo.setPin('482915');
      await repo.setBiometricEnabled(true);
    });

    test('بعد إنشاء الرمز لا يُفرض', () async {
      expect(await repo.pinRequirement(), PinRequirement.none);
    });

    test('3 محاولات بصمة فاشلة', () async {
      await repo.recordBiometricFailure();
      await repo.recordBiometricFailure();
      expect(await repo.pinRequirement(), PinRequirement.none);
      await repo.recordBiometricFailure();
      expect(await repo.pinRequirement(), PinRequirement.biometricFailures);

      // الدخول بالرمز يصفّر العداد.
      await repo.verifyPin('482915');
      expect(await repo.pinRequirement(), PinRequirement.none);
    });

    test('مرور 7 أيام على آخر دخول بالرمز', () async {
      now = now.add(const Duration(days: 6, hours: 23));
      expect(await repo.pinRequirement(), PinRequirement.none);
      now = now.add(const Duration(hours: 2));
      expect(await repo.pinRequirement(), PinRequirement.weeklyReminder);
    });
  });

  test('المسح يزيل كل الأسرار', () async {
    await repo.setPin('482915');
    await repo.createRecoveryCode();
    await repo.setBiometricEnabled(true);
    await repo.wipe();
    expect(store.values, isEmpty);
    expect(await repo.hasPin(), isFalse);
    expect(await repo.isBiometricEnabled(), isFalse);
  });
}
