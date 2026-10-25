import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../data/auth_repository.dart';
import 'widgets/recovery_code_view.dart';
import 'widgets/verify_pin_pad.dart';

/// إنشاء رمز استرداد جديد بعد إدخال الرمز السري؛ يُلغى القديم (القسم 6.6).
class NewRecoveryCodeScreen extends ConsumerStatefulWidget {
  const NewRecoveryCodeScreen({super.key});

  @override
  ConsumerState<NewRecoveryCodeScreen> createState() => _NewRecoveryCodeScreenState();
}

class _NewRecoveryCodeScreenState extends ConsumerState<NewRecoveryCodeScreen> {
  String? _code;

  Future<void> _create(String _) async {
    final code = await ref.read(authRepositoryProvider).createRecoveryCode();
    if (mounted) setState(() => _code = code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رمز استرداد جديد')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _code == null
                ? Column(
                    children: [
                      Text('أدخل رمزك السري الحالي', style: AppTextStyles.screenTitle),
                      const SizedBox(height: 4),
                      Text('سيتوقف رمز الاسترداد القديم عن العمل', style: AppTextStyles.caption),
                      const SizedBox(height: 24),
                      VerifyPinPad(onVerified: _create),
                    ],
                  )
                : RecoveryCodeView(code: _code!, continueLabel: 'تم', onContinue: () => context.pop()),
          ),
        ),
      ),
    );
  }
}
