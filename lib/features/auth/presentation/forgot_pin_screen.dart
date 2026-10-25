import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/security/recovery_code.dart';
import '../../../core/widgets/labeled_field.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import 'widgets/pin_setup_flow.dart';
import 'widgets/recovery_code_view.dart';

enum _Stage { code, newPin, newRecovery }

/// نسيت الرمز (الشاشة 9): رمز الاسترداد ← رمز جديد ← رمز استرداد جديد.
class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  final _code = TextEditingController();
  final _confirmWipe = TextEditingController();
  var _stage = _Stage.code;
  String? _error;
  String? _newRecovery;
  var _busy = false;
  var _showWipe = false;

  static const _wipeWord = 'مسح';

  @override
  void dispose() {
    _code.dispose();
    _confirmWipe.dispose();
    super.dispose();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _verifyCode() async {
    final normalized = RecoveryCode.normalize(_code.text);
    if (!RecoveryCode.isWellFormed(normalized)) {
      setState(() => _error = 'رمز الاسترداد يتكون من 12 حرفاً ورقماً');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _repo.verifyRecoveryCode(normalized);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case SecretAccepted():
          _stage = _Stage.newPin;
        case SecretRejected(:final lockedUntil):
          _error = lockedUntil == null
              ? 'رمز الاسترداد غير صحيح'
              : 'رمز الاسترداد غير صحيح. حاول بعد ${_minutesUntil(lockedUntil)}';
        case SecretLockedOut(:final until):
          _error = 'محاولات كثيرة. حاول بعد ${_minutesUntil(until)}';
      }
    });
  }

  String _minutesUntil(DateTime until) {
    final seconds = until.difference(DateTime.now()).inSeconds;
    if (seconds < 60) return '$seconds ثانية';
    return '${(seconds / 60).ceil()} دقيقة';
  }

  Future<void> _setNewPin(String pin) async {
    await _repo.setPin(pin);
    final code = await _repo.createRecoveryCode();
    if (!mounted) return;
    setState(() {
      _newRecovery = code;
      _stage = _Stage.newRecovery;
    });
  }

  Future<void> _wipe() async {
    setState(() => _busy = true);
    await ref.read(authControllerProvider.notifier).wipeEverything();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استعادة الدخول'),
        // بعد قبول رمز الاسترداد لا رجوع حتى يكتمل الرمز الجديد.
        automaticallyImplyLeading: _stage == _Stage.code,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: switch (_stage) {
            _Stage.code => _codeStage(),
            _Stage.newPin => Center(
                child: PinSetupFlow(title: 'أنشئ رمزاً جديداً', onConfirmed: _setNewPin),
              ),
            _Stage.newRecovery => RecoveryCodeView(
                code: _newRecovery!,
                continueLabel: 'فتح التطبيق',
                onContinue: ref.read(authControllerProvider.notifier).unlock,
              ),
          },
        ),
      ),
    );
  }

  Widget _codeStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'أدخل رمز الاسترداد الذي حفظته عند إعداد التطبيق.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        LabeledField(
          label: 'رمز الاسترداد',
          required: true,
          controller: _code,
          hint: 'XXXX-XXXX-XXXX',
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          maxLength: 16,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppTextStyles.label.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _verifyCode, child: const Text('تحقق')),
        const SizedBox(height: 40),
        TextButton(
          onPressed: () => setState(() => _showWipe = !_showWipe),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('فقدت رمز الاسترداد أيضاً؟'),
        ),
        if (_showWipe) _wipeSection(),
      ],
    );
  }

  Widget _wipeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'البيانات محفوظة على جهازك فقط، ولا يمكن فتحها دون الرمز أو رمز الاسترداد. '
            'الحل الوحيد هو مسح كل البيانات والبدء من جديد، ثم استعادة نسخة احتياطية إن وُجدت.',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'اكتب كلمة «$_wipeWord» للتأكيد',
            controller: _confirmWipe,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _confirmWipe.text.trim() != _wipeWord ? null : _wipe,
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('مسح كل البيانات والبدء من جديد'),
          ),
        ],
      ),
    );
  }
}
