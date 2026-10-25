import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// عرض رمز الاسترداد مرة واحدة مع تأكيد حفظه (الشاشة 5).
class RecoveryCodeView extends StatefulWidget {
  const RecoveryCodeView({super.key, required this.code, required this.onContinue, this.continueLabel = 'التالي'});

  final String code;
  final VoidCallback onContinue;
  final String continueLabel;

  @override
  State<RecoveryCodeView> createState() => _RecoveryCodeViewState();
}

class _RecoveryCodeViewState extends State<RecoveryCodeView> {
  var _saved = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رمز الاسترداد')));
  }

  Future<void> _share() => SharePlus.instance.share(ShareParams(text: 'رمز استرداد تطبيق نسبتي: ${widget.code}'));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('احفظ رمز الاسترداد', style: AppTextStyles.screenTitle, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'تحتاجه لاستعادة الدخول إذا نسيت رمزك السري',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                widget.code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('مشاركة'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'هذا الرمز هو الطريقة الوحيدة لاستعادة الدخول إذا نسيت رمزك. لن يظهر مرة أخرى.',
                  style: AppTextStyles.label.copyWith(color: AppColors.warning),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _saved,
          onChanged: (v) => setState(() => _saved = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('حفظت رمز الاسترداد في مكان آمن', style: AppTextStyles.body),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saved ? widget.onContinue : null, child: Text(widget.continueLabel)),
      ],
    );
  }
}
