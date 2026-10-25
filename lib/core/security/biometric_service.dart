import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

enum BiometricAvailability {
  available,

  /// الجهاز يدعمها لكن لا توجد بصمة مسجّلة.
  notEnrolled,
  unsupported,
}

enum BiometricResult { success, failed, canceled, unavailable }

/// البصمة طريق مختصر فقط؛ الرمز السري هو المرجع دائماً (القسم 6.1).
abstract interface class BiometricService {
  Future<BiometricAvailability> availability();
  Future<BiometricResult> authenticate(String reason);
}

class LocalBiometricService implements BiometricService {
  final _auth = LocalAuthentication();

  @override
  Future<BiometricAvailability> availability() async {
    try {
      if (!await _auth.isDeviceSupported()) return BiometricAvailability.unsupported;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty ? BiometricAvailability.notEnrolled : BiometricAvailability.available;
    } catch (_) {
      return BiometricAvailability.unsupported;
    }
  }

  @override
  Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'افتح نسبتي',
            signInHint: 'استخدم بصمتك للمتابعة',
            cancelButton: 'استخدام الرمز',
          ),
          IOSAuthMessages(cancelButton: 'استخدام الرمز'),
        ],
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.authInProgress =>
          BiometricResult.canceled,
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.uiUnavailable =>
          BiometricResult.unavailable,
        _ => BiometricResult.failed,
      };
    } catch (_) {
      return BiometricResult.unavailable;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>((ref) => LocalBiometricService());
