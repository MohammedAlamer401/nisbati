import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import 'widgets/verify_pin_pad.dart';

/// تأكيد الرمز الحالي قبل عملية حساسة؛ تُغلق بـ `true` عند القبول.
class PinVerifyScreen extends StatelessWidget {
  const PinVerifyScreen({super.key, this.title = 'تأكيد الهوية'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('أدخل رمزك السري الحالي', style: AppTextStyles.cardTitle),
                const SizedBox(height: 24),
                VerifyPinPad(onVerified: (_) => context.pop(true)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
