import 'package:flutter/material.dart';

import '../formatting/currency_formatter.dart';
import '../money/money.dart';
import 'labeled_field.dart';

/// حقل مبلغ: لوحة أرقام عشرية، وتنسيق آلاف عند مغادرة الحقل لا أثناء الكتابة (الشاشة 15).
///
/// يقبل الأرقام الهندية والفاصلة العربية عبر [Money.tryParse].
class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    required this.label,
    required this.controller,
    this.required = true,
    this.validator,
    this.suffixText,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final FormFieldValidator<String>? validator;
  final String? suffixText;
  final TextInputAction textInputAction;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final money = Money.tryParse(widget.controller.text);
    if (money == null) return;
    // عند التركيز: نص بلا فواصل للتعديل؛ عند المغادرة: تنسيق الآلاف.
    widget.controller.text = _focus.hasFocus ? _plain(money) : CurrencyFormatter.number(money);
  }

  static String _plain(Money money) {
    final text = money.toPlainString();
    return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
  }

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      required: widget.required,
      controller: widget.controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      textInputAction: widget.textInputAction,
      suffixText: widget.suffixText,
      validator: widget.validator ??
          (v) {
            if ((v ?? '').trim().isEmpty) return widget.required ? 'المبلغ مطلوب' : null;
            return Money.tryParse(v!) == null ? 'يرجى إدخال قيمة صحيحة' : null;
          },
    );
  }
}
