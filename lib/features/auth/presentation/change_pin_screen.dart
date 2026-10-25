import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../data/auth_repository.dart';
import 'widgets/pin_setup_flow.dart';
import 'widgets/verify_pin_pad.dart';

/// تغيير الرمز السري (الشاشة 22): الحالي ← الجديد ← التأكيد.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  String? _current;

  Future<void> _save(String pin) async {
    await ref.read(authRepositoryProvider).setPin(pin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير الرمز السري')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تغيير الرمز السري')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _current == null
                ? Column(
                    children: [
                      Text('أدخل رمزك السري الحالي', style: AppTextStyles.screenTitle),
                      const SizedBox(height: 24),
                      VerifyPinPad(onVerified: (pin) => setState(() => _current = pin)),
                    ],
                  )
                : PinSetupFlow(
                    title: 'أدخل الرمز الجديد',
                    subtitle: '6 أرقام مختلفة عن الرمز الحالي',
                    validate: (pin) async => pin == _current ? 'الرمز الجديد يجب أن يختلف عن الحالي' : null,
                    onConfirmed: _save,
                  ),
          ),
        ),
      ),
    );
  }
}
