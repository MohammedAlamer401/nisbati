import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/widgets/profile_form.dart';
import 'onboarding_scaffold.dart';

/// الخطوة 1: إنشاء الملف الشخصي (الشاشة 3).
class ProfileStepScreen extends ConsumerWidget {
  const ProfileStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // إن أُغلق التطبيق بعد الحفظ وقبل الانتقال تُعرض البيانات المحفوظة.
    final profile = ref.watch(profileProvider);
    return OnboardingScaffold(
      step: OnboardingStep.profile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepHeading(title: 'عرّفنا بنفسك', subtitle: 'بياناتك تبقى على جهازك فقط'),
          if (profile.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ProfileForm(
              initial: profile.value,
              initialPhoto: ref.watch(profilePhotoProvider).value,
              compact: true,
              submitLabel: 'التالي',
              onSaved: () => ref.read(authControllerProvider.notifier).completeStep(OnboardingStep.profile),
            ),
        ],
      ),
    );
  }
}
