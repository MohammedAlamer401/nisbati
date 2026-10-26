import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/profile_repository.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import 'widgets/verify_pin_pad.dart';

/// شاشة القفل (الشاشة 8): البصمة تلقائياً إن كانت مفعّلة، والرمز دائماً.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  var _biometric = false;
  var _requirement = PinRequirement.none;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _load() async {
    var enabled = await _repo.isBiometricEnabled();
    String? notice;
    if (enabled && await ref.read(biometricServiceProvider).availability() != BiometricAvailability.available) {
      // أُلغيت البصمة من إعدادات الجهاز: يتعطل الخيار في التطبيق تلقائياً.
      await _repo.setBiometricEnabled(false);
      enabled = false;
      notice = 'البصمة غير متاحة الآن، فأُوقف الدخول بها. يمكنك تفعيله من الإعدادات.';
    }
    final requirement = await _repo.pinRequirement();
    if (!mounted) return;
    setState(() {
      _biometric = enabled;
      _requirement = requirement;
      _notice = notice;
    });
    if (_canUseBiometric && await _repo.lockedUntil() == null) _tryBiometric();
  }

  bool get _canUseBiometric => _biometric && _requirement == PinRequirement.none;

  Future<void> _tryBiometric() async {
    final result = await ref.read(biometricServiceProvider).authenticate('استخدم بصمتك للمتابعة');
    if (!mounted) return;
    switch (result) {
      case BiometricResult.success:
        await _repo.recordBiometricSuccess();
        ref.read(authControllerProvider.notifier).unlock();
      case BiometricResult.failed:
        await _repo.recordBiometricFailure();
        final requirement = await _repo.pinRequirement();
        if (mounted) setState(() => _requirement = requirement);
      case BiometricResult.canceled || BiometricResult.unavailable:
        break;
    }
  }

  String? get _requirementMessage => switch (_requirement) {
        PinRequirement.weeklyReminder when _biometric =>
          'أدخل رمزك السري للتأكد (مرّ أسبوع على آخر استخدام له)',
        PinRequirement.biometricFailures when _biometric => 'تعذّر التعرف على البصمة، أدخل رمزك السري',
        PinRequirement.noRecentPin when _biometric => 'أدخل رمزك السري للمتابعة',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(profileProvider).value?.fullName.trim().split(RegExp(r'\s+')).first;
    final notice = _notice ?? _requirementMessage;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                const CurrentUserAvatar(radius: 40),
                const SizedBox(height: 12),
                Text(name == null ? 'مرحباً' : 'مرحباً، $name', style: AppTextStyles.screenTitle),
                const SizedBox(height: 4),
                Text('أدخل رمز الدخول', style: AppTextStyles.caption),
                if (notice != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(notice, style: AppTextStyles.label, textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 24),
                VerifyPinPad(
                  onVerified: (_) => ref.read(authControllerProvider.notifier).unlock(),
                  leading: _canUseBiometric
                      ? IconButton(
                          onPressed: _tryBiometric,
                          iconSize: 36,
                          tooltip: 'الدخول بالبصمة',
                          icon: const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.push(AppRoutes.forgotPin),
                  child: const Text('نسيت الرمز؟'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
