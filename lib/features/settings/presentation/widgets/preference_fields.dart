import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/widgets/labeled_field.dart';

/// حقل رمز العملة. تغييره يغيّر الرمز المعروض فقط دون تحويل المبالغ.
class CurrencyField extends StatelessWidget {
  const CurrencyField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: 'رمز العملة',
      required: true,
      controller: controller,
      maxLength: 6,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'رمز العملة مطلوب' : null,
    );
  }
}

/// حقل النسبة الافتراضية للخدمات الجديدة (0–100 بحد أقصى منزلتين).
class PercentField extends StatelessWidget {
  const PercentField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: 'النسبة الافتراضية للخدمات الجديدة',
      required: true,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      suffixText: '%',
      textInputAction: TextInputAction.done,
      validator: (v) => Percent.tryParse(v ?? '') == null ? 'أدخل نسبة من 0 إلى 100' : null,
    );
  }
}
