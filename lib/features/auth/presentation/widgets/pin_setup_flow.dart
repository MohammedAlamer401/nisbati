import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/security/pin_policy.dart';
import '../../../../core/widgets/pin_entry.dart';

/// إنشاء رمز جديد: إدخال ثم تأكيد، مع رفض الرموز الضعيفة (الشاشة 4).
class PinSetupFlow extends StatefulWidget {
  const PinSetupFlow({
    super.key,
    required this.onConfirmed,
    this.title = 'أنشئ رمز الدخول',
    this.subtitle = '6 أرقام تستخدمها لفتح التطبيق',
    this.validate,
  });

  final Future<void> Function(String pin) onConfirmed;
  final String title;
  final String subtitle;

  /// قاعدة إضافية على الرمز الجديد (مثل ألا يساوي الحالي).
  final Future<String?> Function(String pin)? validate;

  @override
  State<PinSetupFlow> createState() => _PinSetupFlowState();
}

class _PinSetupFlowState extends State<PinSetupFlow> {
  String? _first;
  String? _notice;

  Future<String?> _onCompleted(String pin) async {
    final first = _first;
    if (first == null) {
      if (PinPolicy.isWeak(pin)) return PinPolicy.weakPinMessage;
      final extra = await widget.validate?.call(pin);
      if (extra != null) return extra;
      setState(() {
        _first = pin;
        _notice = null;
      });
      return null;
    }
    if (pin != first) {
      setState(() {
        _first = null;
        _notice = 'الرمزان غير متطابقين، أعد المحاولة';
      });
      return null;
    }
    await widget.onConfirmed(pin);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _first != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(confirming ? 'أعد إدخال الرمز للتأكيد' : widget.title, style: AppTextStyles.screenTitle),
        const SizedBox(height: 4),
        Text(
          _notice ?? widget.subtitle,
          style: _notice != null ? AppTextStyles.label.copyWith(color: AppColors.error) : AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // مفتاح مختلف لكل مرحلة يمسح الإدخال عند الانتقال.
        PinEntry(key: ValueKey(confirming), onCompleted: _onCompleted),
      ],
    );
  }
}
