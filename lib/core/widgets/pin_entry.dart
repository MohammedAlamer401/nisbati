import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../security/pin_policy.dart';

/// إدخال رمز من 6 أرقام بلوحة أرقام داخلية (القسمان 10 و11).
///
/// يتحقق تلقائياً بعد الرقم الأخير دون زر تأكيد. ترتيب الأرقام ثابت كلوحة
/// الهاتف (1 2 3 من اليسار) ولا يُعكس في RTL.
class PinEntry extends StatefulWidget {
  const PinEntry({
    super.key,
    required this.onCompleted,
    this.enabled = true,
    this.leading,
    this.message,
  });

  /// تُستدعى بعد الرقم الأخير، وتعيد رسالة خطأ (فيُمسح الإدخال مع اهتزاز) أو `null`.
  final Future<String?> Function(String pin) onCompleted;

  /// تعطيل اللوحة (مثلاً أثناء الانتظار بعد محاولات خاطئة).
  final bool enabled;

  /// زر اختياري في الخانة السفلى اليسرى (البصمة).
  final Widget? leading;

  /// رسالة خارجية تُعرض مكان رسالة الخطأ (مثل العداد التنازلي).
  final String? message;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry> with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  var _value = '';
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _active => widget.enabled && !_busy;

  void _onDigit(int digit) {
    if (!_active || _value.length >= PinPolicy.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _value += '$digit';
      _error = null;
    });
    if (_value.length == PinPolicy.length) _submit();
  }

  void _onBackspace() {
    if (!_active || _value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final error = await widget.onCompleted(_value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error != null) {
        _error = error;
        _value = '';
      }
    });
    if (error != null) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message ?? _error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            return Transform.translate(offset: Offset(sin(t * pi * 6) * 12 * (1 - t), 0), child: child);
          },
          child: Semantics(
            label: 'تم إدخال ${_value.length} من ${PinPolicy.length} أرقام',
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < PinPolicy.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _value.length
                            ? (_error != null ? AppColors.error : AppColors.primary)
                            : Colors.transparent,
                        border: Border.all(
                          color: i < _value.length ? AppColors.primary : AppColors.textSecondary,
                          width: 1.6,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: Center(
            child: message == null
                ? (_busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : null)
                : Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(
                      color: widget.message != null ? AppColors.textSecondary : AppColors.error,
                    ),
                  ),
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in const [
                  [1, 2, 3],
                  [4, 5, 6],
                  [7, 8, 9],
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final d in row) _DigitKey(digit: d, onTap: () => _onDigit(d))],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(dimension: _DigitKey.size + 16, child: Center(child: widget.leading)),
                    _DigitKey(digit: 0, onTap: () => _onDigit(0)),
                    _KeyButton(
                      onTap: _onBackspace,
                      semanticLabel: 'حذف',
                      child: const Icon(Icons.backspace_outlined, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.digit, required this.onTap});

  static const size = 72.0;

  final int digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _KeyButton(
      onTap: onTap,
      semanticLabel: '$digit',
      filled: true,
      child: Text('$digit', style: AppTextStyles.style(28, FontWeight.w600, height: 1)),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.onTap,
    required this.semanticLabel,
    required this.child,
    this.filled = false,
  });

  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: Material(
          color: filled ? AppColors.surface : Colors.transparent,
          shape: CircleBorder(side: filled ? const BorderSide(color: AppColors.border) : BorderSide.none),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(dimension: _DigitKey.size, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}
