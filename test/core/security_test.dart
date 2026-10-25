import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/security/pin_hasher.dart';
import 'package:nisbati/core/security/pin_policy.dart';
import 'package:nisbati/core/security/recovery_code.dart';

void main() {
  group('PinPolicy.isWeak', () {
    test('يرفض المتطابقة والمتتالية صعوداً ونزولاً', () {
      for (final pin in ['111111', '000000', '123456', '012345', '456789', '654321', '987654']) {
        expect(PinPolicy.isWeak(pin), isTrue, reason: pin);
      }
    });

    test('يقبل الرموز العادية', () {
      for (final pin in ['482915', '135790', '112233', '123457', '909090']) {
        expect(PinPolicy.isWeak(pin), isFalse, reason: pin);
      }
    });
  });

  test('PinPolicy.lockoutFor حسب جدول القسم 6.5', () {
    expect(PinPolicy.lockoutFor(1), Duration.zero);
    expect(PinPolicy.lockoutFor(4), Duration.zero);
    expect(PinPolicy.lockoutFor(5), const Duration(seconds: 30));
    expect(PinPolicy.lockoutFor(6), const Duration(minutes: 1));
    expect(PinPolicy.lockoutFor(7), const Duration(minutes: 2));
    expect(PinPolicy.lockoutFor(8), const Duration(minutes: 5));
    expect(PinPolicy.lockoutFor(9), const Duration(minutes: 15));
    expect(PinPolicy.lockoutFor(10), const Duration(minutes: 30));
    expect(PinPolicy.lockoutFor(25), const Duration(minutes: 30));
  });

  group('RecoveryCode', () {
    test('الصيغة XXXX-XXXX-XXXX بلا أحرف ملتبسة', () {
      final code = RecoveryCode.generate(Random(1));
      expect(code, matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$')));
      expect(code, isNot(contains(RegExp('[O0I1]'))));
      expect(RecoveryCode.isWellFormed(RecoveryCode.normalize(code)), isTrue);
    });

    test('التطبيع يقبل الشرطات والمسافات والحروف الصغيرة', () {
      expect(RecoveryCode.normalize('k7qm-4xrp 9hwt'), 'K7QM4XRP9HWT');
      expect(RecoveryCode.format('K7QM4XRP9HWT'), 'K7QM-4XRP-9HWT');
    });

    test('يرفض الطول الخاطئ والأحرف الملتبسة', () {
      expect(RecoveryCode.isWellFormed('K7QM4XRP9HW'), isFalse);
      expect(RecoveryCode.isWellFormed('K7QM4XRP9HW0'), isFalse);
    });
  });

  group('PinHasher', () {
    const hasher = PinHasher(iterations: 1000, useIsolate: false);

    test('يقبل السرّ الصحيح ويرفض غيره', () async {
      final hashed = await hasher.hash('482915');
      expect(hashed.iterations, 1000);
      expect(await hasher.verify('482915', hashed), isTrue);
      expect(await hasher.verify('482916', hashed), isFalse);
    });

    test('ملح مختلف لكل تجزئة، والسرّ لا يظهر في الناتج', () async {
      final a = await hasher.hash('482915');
      final b = await hasher.hash('482915');
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
      expect(a.hash, isNot(contains('482915')));
    });

    test('الإعداد الافتراضي 210,000 تكرار', () {
      expect(const PinHasher().iterations, 210000);
    });
  });
}
