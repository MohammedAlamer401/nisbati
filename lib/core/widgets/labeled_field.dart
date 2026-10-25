import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// حقل بتسمية ثابتة أعلاه و`*` للإلزامي، ورسالة خطأ تحته (القسم 11).
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textDirection,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.maxLength,
    this.suffixText,
    this.onChanged,
    this.maxLines = 1,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;

  /// لحقول الأرقام والبريد داخل الواجهة العربية.
  final TextDirection? textDirection;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? suffixText;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
            ],
          ),
          style: AppTextStyles.label,
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          validator: validator,
          keyboardType: keyboardType,
          textDirection: textDirection,
          // الأرقام (LTR) تُحاذى يميناً في الواجهة العربية فتبتعد عن رمز العملة أو %.
          textAlign: textDirection == TextDirection.ltr ? TextAlign.right : TextAlign.start,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 2 : null,
          onChanged: onChanged,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            suffixText: suffixText,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
