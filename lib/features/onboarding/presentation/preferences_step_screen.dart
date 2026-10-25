import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../auth/application/auth_controller.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/widgets/preference_fields.dart';
import 'onboarding_scaffold.dart';

/// الخطوة 5: العملة والنسبة الافتراضية (الشاشة 7).
class PreferencesStepScreen extends ConsumerStatefulWidget {
  const PreferencesStepScreen({super.key});

  @override
  ConsumerState<PreferencesStepScreen> createState() => _PreferencesStepScreenState();
}

class _PreferencesStepScreenState extends ConsumerState<PreferencesStepScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currency = TextEditingController(text: 'د.ل');
  final _percent = TextEditingController(text: '20');
  var _saving = false;

  @override
  void dispose() {
    _currency.dispose();
    _percent.dispose();
    super.dispose();
  }

  Future<void> _finish({bool save = true}) async {
    if (save && !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final settings = ref.read(settingsRepositoryProvider);
    if (save) {
      await settings.setCurrencySymbol(_currency.text);
      await settings.setDefaultCommission(Percent.tryParse(_percent.text)!);
    }
    await ref.read(authControllerProvider.notifier).completeStep(OnboardingStep.preferences);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: OnboardingStep.preferences,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepHeading(title: 'إعدادات الحساب', subtitle: 'يمكنك تغييرها لاحقاً من الإعدادات'),
            CurrencyField(controller: _currency),
            const SizedBox(height: 16),
            PercentField(controller: _percent),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _finish,
              child: const Text('ابدأ استخدام التطبيق'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : () => _finish(save: false),
              child: const Text('تخطي واستخدام الافتراضي'),
            ),
          ],
        ),
      ),
    );
  }
}
