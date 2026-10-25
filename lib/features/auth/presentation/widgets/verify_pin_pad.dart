import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/widgets/pin_entry.dart';
import '../../data/auth_repository.dart';

/// إدخال الرمز الحالي والتحقق منه مع قواعد المحاولات الخاطئة والعداد (القسم 6.5).
class VerifyPinPad extends ConsumerStatefulWidget {
  const VerifyPinPad({super.key, required this.onVerified, this.leading});

  /// يُستدعى بعد قبول الرمز، ويستلم الرمز المُدخل.
  final FutureOr<void> Function(String pin) onVerified;
  final Widget? leading;

  @override
  ConsumerState<VerifyPinPad> createState() => _VerifyPinPadState();
}

class _VerifyPinPadState extends ConsumerState<VerifyPinPad> {
  DateTime? _lockedUntil;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    ref.read(authRepositoryProvider).lockedUntil().then(_setLockout);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _setLockout(DateTime? until) {
    if (!mounted) return;
    _ticker?.cancel();
    setState(() => _lockedUntil = until);
    if (until == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(until)) {
        _ticker?.cancel();
        setState(() => _lockedUntil = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<String?> _onCompleted(String pin) async {
    final result = await ref.read(authRepositoryProvider).verifyPin(pin);
    switch (result) {
      case SecretAccepted():
        await widget.onVerified(pin);
        return null;
      case SecretRejected(:final lockedUntil):
        if (lockedUntil != null) _setLockout(lockedUntil);
        return 'الرمز غير صحيح';
      case SecretLockedOut(:final until):
        _setLockout(until);
        return null;
    }
  }

  String? get _countdown {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    final seconds = left.inSeconds < 0 ? 0 : left.inSeconds + 1;
    String two(int n) => n.toString().padLeft(2, '0');
    return 'حاول مجدداً بعد ${CurrencyFormatter.lri}${two(seconds ~/ 60)}:${two(seconds % 60)}${CurrencyFormatter.pdi}';
  }

  @override
  Widget build(BuildContext context) {
    return PinEntry(
      onCompleted: _onCompleted,
      enabled: _lockedUntil == null,
      message: _countdown,
      leading: _lockedUntil == null ? widget.leading : null,
    );
  }
}
