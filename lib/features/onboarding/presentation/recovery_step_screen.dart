import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/widgets/recovery_code_view.dart';
import 'onboarding_scaffold.dart';

/// الخطوة 3: رمز الاسترداد (الشاشة 5). يُولَّد عند فتح الشاشة ويُعرض مرة واحدة.
class RecoveryStepScreen extends ConsumerStatefulWidget {
  const RecoveryStepScreen({super.key});

  @override
  ConsumerState<RecoveryStepScreen> createState() => _RecoveryStepScreenState();
}

class _RecoveryStepScreenState extends ConsumerState<RecoveryStepScreen> {
  late final Future<String> _code = ref.read(authRepositoryProvider).createRecoveryCode();

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: OnboardingStep.recovery,
      child: FutureBuilder(
        future: _code,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return RecoveryCodeView(
            code: snapshot.data!,
            onContinue: () => ref.read(authControllerProvider.notifier).completeStep(OnboardingStep.recovery),
          );
        },
      ),
    );
  }
}
