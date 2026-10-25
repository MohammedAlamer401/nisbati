import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/widgets/pin_setup_flow.dart';
import 'onboarding_scaffold.dart';

/// الخطوة 2: إنشاء الرمز السري (الشاشة 4).
class PinStepScreen extends ConsumerWidget {
  const PinStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingScaffold(
      step: OnboardingStep.pin,
      child: PinSetupFlow(
        onConfirmed: (pin) async {
          await ref.read(authRepositoryProvider).setPin(pin);
          await ref.read(authControllerProvider.notifier).completeStep(OnboardingStep.pin);
        },
      ),
    );
  }
}
