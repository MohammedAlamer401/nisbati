import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../profile/data/profile_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../data/auth_repository.dart';

/// خطوات التشغيل الأول بالترتيب (القسم 6.2).
enum OnboardingStep {
  welcome,
  profile,
  pin,
  recovery,
  biometric,
  preferences,
  done;

  /// رقم الخطوة في مؤشر «1 من 5» (الترحيب خارج العدّ).
  int get number => index;
  static const total = 5;
}

enum AuthStatus { initializing, onboarding, locked, unlocked }

@immutable
class AuthState {
  const AuthState(this.status, {this.step = OnboardingStep.welcome});

  final AuthStatus status;
  final OnboardingStep step;
}

/// حالة الدخول: التشغيل الأول، والقفل، والقفل التلقائي (القسم 6).
class AuthController extends Notifier<AuthState> {
  DateTime? _hiddenAt;

  @override
  AuthState build() => const AuthState(AuthStatus.initializing);

  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// يحدد نقطة البداية بعد شاشة الإقلاع.
  Future<void> initialize() async {
    final raw = await _settings.read(SettingKeys.onboardingStep);
    var step = OnboardingStep.values.asNameMap()[raw];
    if (step == null) {
      // تثبيت جديد: قد يبقى في Keychain (iOS) رمز من تثبيت سابق حُذف.
      await _auth.wipe();
      step = OnboardingStep.welcome;
      await _saveStep(step);
    }
    if (step != OnboardingStep.done) {
      state = AuthState(AuthStatus.onboarding, step: step);
    } else if (!await _auth.hasPin()) {
      // البيانات موجودة لكن الأسرار فُقدت: يُطلب إنشاء رمز جديد.
      await _saveStep(OnboardingStep.pin);
      state = const AuthState(AuthStatus.onboarding, step: OnboardingStep.pin);
    } else {
      state = const AuthState(AuthStatus.locked);
    }
  }

  /// ينهي خطوة من التشغيل الأول وينتقل للتالية (أو يفتح التطبيق بعد الأخيرة).
  Future<void> completeStep(OnboardingStep current) async {
    final next = OnboardingStep.values[current.index + 1];
    await _saveStep(next);
    state = next == OnboardingStep.done
        ? const AuthState(AuthStatus.unlocked)
        : AuthState(AuthStatus.onboarding, step: next);
  }

  void unlock() => state = const AuthState(AuthStatus.unlocked);

  void lock() {
    if (state.status == AuthStatus.unlocked) state = const AuthState(AuthStatus.locked);
  }

  void onHidden() => _hiddenAt ??= DateTime.now();

  /// القفل التلقائي: يُحسب الوقت من لحظة انتقال التطبيق إلى الخلفية (القسم 6.4).
  Future<void> onResumed() async {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || state.status != AuthStatus.unlocked) return;
    final autoLock = (await _settings.preferences()).autoLock;
    if (DateTime.now().difference(hiddenAt) >= autoLock) lock();
  }

  /// مسح كل البيانات والأسرار والبدء من جديد (القسم 6.6).
  Future<void> wipeEverything() async {
    await ref.read(appDatabaseProvider).resetToDefaults();
    await ref.read(profileRepositoryProvider).deleteAllPhotos();
    await _auth.wipe();
    await _saveStep(OnboardingStep.welcome);
    state = const AuthState(AuthStatus.onboarding);
  }

  Future<void> _saveStep(OnboardingStep step) => _settings.write(SettingKeys.onboardingStep, step.name);
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
