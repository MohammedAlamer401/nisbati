import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/pin_hasher.dart';
import '../../../core/security/pin_policy.dart';
import '../../../core/security/recovery_code.dart';
import '../../../core/security/secure_store.dart';

/// نتيجة التحقق من رمز سري أو رمز استرداد.
sealed class SecretCheck {
  const SecretCheck();
}

class SecretAccepted extends SecretCheck {
  const SecretAccepted();
}

class SecretRejected extends SecretCheck {
  const SecretRejected({required this.failures, this.lockedUntil});

  final int failures;

  /// موعد انتهاء الانتظار إن فرضته هذه المحاولة.
  final DateTime? lockedUntil;
}

/// المحاولة رُفضت دون تحقق لأن فترة الانتظار لم تنتهِ.
class SecretLockedOut extends SecretCheck {
  const SecretLockedOut(this.until);

  final DateTime until;
}

/// مفاتيح التخزين الآمن — القسم 7.7.
abstract final class SecureKeys {
  static const pinHash = 'pin_hash';
  static const pinSalt = 'pin_salt';
  static const pinIterations = 'pin_iterations';
  static const recoveryHash = 'recovery_hash';
  static const recoverySalt = 'recovery_salt';
  static const recoveryIterations = 'recovery_iterations';
  static const failedAttempts = 'failed_attempts';
  static const lockoutUntil = 'lockout_until';
  static const biometricEnabled = 'biometric_enabled';
  static const biometricFailures = 'biometric_failures';
  static const lastPinAuthAt = 'last_pin_auth_at';
}

/// الرمز السري، ورمز الاسترداد، والمحاولات الخاطئة، وإعداد البصمة — القسم 6.
class AuthRepository {
  AuthRepository(this._store, this._hasher, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SecureStore _store;
  final PinHasher _hasher;
  final DateTime Function() _clock;

  Future<bool> hasPin() async => await _store.read(SecureKeys.pinHash) != null;

  /// يحفظ رمزاً جديداً ويصفّر المحاولات، ويُحتسب دخولاً بالرمز.
  Future<void> setPin(String pin) async {
    await _writeHash(pin, SecureKeys.pinHash, SecureKeys.pinSalt, SecureKeys.pinIterations);
    await _resetFailures();
    await _store.write(SecureKeys.lastPinAuthAt, _clock().toIso8601String());
  }

  Future<SecretCheck> verifyPin(String pin) => _verify(
        pin,
        SecureKeys.pinHash,
        SecureKeys.pinSalt,
        SecureKeys.pinIterations,
        onAccepted: () async {
          await _store.write(SecureKeys.lastPinAuthAt, _clock().toIso8601String());
          await _store.delete(SecureKeys.biometricFailures);
        },
      );

  /// يولّد رمز استرداد جديداً، ويُلغي القديم، ويعيده نصاً للعرض مرة واحدة.
  Future<String> createRecoveryCode() async {
    final code = RecoveryCode.generate();
    await _writeHash(
      RecoveryCode.normalize(code),
      SecureKeys.recoveryHash,
      SecureKeys.recoverySalt,
      SecureKeys.recoveryIterations,
    );
    return code;
  }

  Future<SecretCheck> verifyRecoveryCode(String input) => _verify(
        RecoveryCode.normalize(input),
        SecureKeys.recoveryHash,
        SecureKeys.recoverySalt,
        SecureKeys.recoveryIterations,
      );

  /// موعد انتهاء الانتظار الحالي، أو `null` إن لم يكن هناك انتظار.
  Future<DateTime?> lockedUntil() async {
    final raw = await _store.read(SecureKeys.lockoutUntil);
    final until = raw == null ? null : DateTime.tryParse(raw);
    return until != null && until.isAfter(_clock()) ? until : null;
  }

  Future<int> failedAttempts() async =>
      int.tryParse(await _store.read(SecureKeys.failedAttempts) ?? '') ?? 0;

  // --- البصمة ---

  Future<bool> isBiometricEnabled() async => await _store.read(SecureKeys.biometricEnabled) == 'true';

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      await _store.write(SecureKeys.biometricEnabled, 'true');
    } else {
      await _store.delete(SecureKeys.biometricEnabled);
    }
    await _store.delete(SecureKeys.biometricFailures);
  }

  Future<void> recordBiometricFailure() async {
    final count = int.tryParse(await _store.read(SecureKeys.biometricFailures) ?? '') ?? 0;
    await _store.write(SecureKeys.biometricFailures, '${count + 1}');
  }

  Future<void> recordBiometricSuccess() => _store.delete(SecureKeys.biometricFailures);

  /// هل يجب إدخال الرمز بدل البصمة؟ (القسم 6.3)
  Future<PinRequirement> pinRequirement() async {
    final failures = int.tryParse(await _store.read(SecureKeys.biometricFailures) ?? '') ?? 0;
    if (failures >= PinPolicy.maxBiometricFailures) return PinRequirement.biometricFailures;
    final raw = await _store.read(SecureKeys.lastPinAuthAt);
    final last = raw == null ? null : DateTime.tryParse(raw);
    if (last == null) return PinRequirement.noRecentPin;
    if (_clock().difference(last) >= PinPolicy.pinReminderInterval) return PinRequirement.weeklyReminder;
    return PinRequirement.none;
  }

  /// يمسح كل الأسرار (عند المسح الكامل أو التثبيت الجديد).
  Future<void> wipe() => _store.deleteAll();

  // --- داخلي ---

  Future<void> _writeHash(String secret, String hashKey, String saltKey, String iterationsKey) async {
    final hashed = await _hasher.hash(secret);
    await _store.write(hashKey, hashed.hash);
    await _store.write(saltKey, hashed.salt);
    await _store.write(iterationsKey, '${hashed.iterations}');
  }

  Future<SecretCheck> _verify(
    String secret,
    String hashKey,
    String saltKey,
    String iterationsKey, {
    Future<void> Function()? onAccepted,
  }) async {
    final current = await lockedUntil();
    if (current != null) return SecretLockedOut(current);

    final hash = await _store.read(hashKey);
    final salt = await _store.read(saltKey);
    final iterations = int.tryParse(await _store.read(iterationsKey) ?? '');
    final ok = hash != null &&
        salt != null &&
        iterations != null &&
        await _hasher.verify(secret, SecretHash(hash: hash, salt: salt, iterations: iterations));

    if (ok) {
      await _resetFailures();
      await onAccepted?.call();
      return const SecretAccepted();
    }

    final failures = await failedAttempts() + 1;
    await _store.write(SecureKeys.failedAttempts, '$failures');
    final wait = PinPolicy.lockoutFor(failures);
    DateTime? until;
    if (wait > Duration.zero) {
      until = _clock().add(wait);
      await _store.write(SecureKeys.lockoutUntil, until.toIso8601String());
    }
    return SecretRejected(failures: failures, lockedUntil: until);
  }

  Future<void> _resetFailures() async {
    await _store.delete(SecureKeys.failedAttempts);
    await _store.delete(SecureKeys.lockoutUntil);
  }
}

/// سبب فرض الرمز السري بدل البصمة.
enum PinRequirement { none, biometricFailures, weeklyReminder, noRecentPin }

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(secureStoreProvider), ref.watch(pinHasherProvider)),
);
