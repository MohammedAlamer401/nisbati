import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/security/biometric_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import 'onboarding_scaffold.dart';

/// الخطوة 4: تفعيل البصمة (الشاشة 6). تُتخطى تلقائياً إن لم يدعمها الجهاز.
class BiometricStepScreen extends ConsumerStatefulWidget {
  const BiometricStepScreen({super.key});

  @override
  ConsumerState<BiometricStepScreen> createState() => _BiometricStepScreenState();
}

class _BiometricStepScreenState extends ConsumerState<BiometricStepScreen> {
  BiometricAvailability? _availability;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final availability = await ref.read(biometricServiceProvider).availability();
    if (!mounted) return;
    if (availability == BiometricAvailability.unsupported) return _next();
    setState(() => _availability = availability);
  }

  Future<void> _next() => ref.read(authControllerProvider.notifier).completeStep(OnboardingStep.biometric);

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    // لا يُفعَّل الخيار إلا بعد نجاح البصمة فعلاً.
    final result = await ref.read(biometricServiceProvider).authenticate('أكّد بصمتك لتفعيل الدخول بها');
    if (!mounted) return;
    if (result == BiometricResult.success) {
      await ref.read(authRepositoryProvider).setBiometricEnabled(true);
      await _next();
      return;
    }
    setState(() {
      _busy = false;
      _error = switch (result) {
        BiometricResult.canceled => null,
        BiometricResult.unavailable => 'البصمة غير متاحة على هذا الجهاز',
        _ => 'لم نتعرف على البصمة، حاول مرة أخرى',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final availability = _availability;
    return OnboardingScaffold(
      step: OnboardingStep.biometric,
      child: availability == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                    child: const Icon(Icons.fingerprint_rounded, size: 72, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 24),
                StepHeading(
                  title: 'افتح التطبيق ببصمتك',
                  subtitle: availability == BiometricAvailability.available
                      ? 'أسرع من كتابة الرمز في كل مرة، ويبقى الرمز متاحاً دائماً'
                      : 'أضف بصمة من إعدادات الجهاز أولاً، ثم فعّلها لاحقاً من إعدادات التطبيق',
                ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: AppTextStyles.label.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                if (availability == BiometricAvailability.available) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _enable,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('تفعيل البصمة'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _busy ? null : _next, child: const Text('ليس الآن')),
                ] else
                  FilledButton(onPressed: _next, child: const Text('تخطي')),
              ],
            ),
    );
  }
}
