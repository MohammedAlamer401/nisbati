import 'package:flutter/foundation.dart';

import '../formatting/digits_normalizer.dart';

/// عدد الوحدات الصغرى في الوحدة الواحدة (قرش). تغييره يتطلب ترحيل بيانات.
const kMinorUnits = 100;
const kFractionDigits = 2;

final _decimalPattern = RegExp(r'^(\d+)(?:\.(\d*))?$');

/// يحلل نصاً عشرياً موجباً إلى عدد صحيح بالوحدات الصغرى، دون المرور بـ `double`.
/// يعيد `null` إذا كان النص غير صالح أو فيه أكثر من [kFractionDigits] منازل.
int? _parseScaled(String input) {
  final cleaned = DigitsNormalizer.toWestern(input).replaceAll(',', '').replaceAll(' ', '').trim();
  final match = _decimalPattern.firstMatch(cleaned);
  if (match == null) return null;
  final fraction = match.group(2) ?? '';
  if (fraction.length > kFractionDigits) return null;
  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return null;
  return whole * kMinorUnits + int.parse(fraction.padRight(kFractionDigits, '0'));
}

/// مبلغ مالي مخزَّن كعدد صحيح بالقرش — انظر القسمين 4 و5.1 في الوثيقة.
@immutable
class Money implements Comparable<Money> {
  const Money(this.minor);

  /// أقصى قيمة مسموحة: 999,999,999.99
  static const maxMinor = 99999999999;
  static const zero = Money(0);

  final int minor;

  /// يحلل مبلغاً أدخله المستخدم، ويقبل الأرقام الهندية وفاصل الآلاف.
  static Money? tryParse(String input) {
    final scaled = _parseScaled(input);
    if (scaled == null || scaled > maxMinor) return null;
    return Money(scaled);
  }

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;

  Money operator +(Money other) => Money(minor + other.minor);
  Money operator -(Money other) => Money(minor - other.minor);
  bool operator <(Money other) => minor < other.minor;
  bool operator >(Money other) => minor > other.minor;
  bool operator <=(Money other) => minor <= other.minor;
  bool operator >=(Money other) => minor >= other.minor;

  /// نص عشري بلا تنسيق آلاف، مثل `1000.00`.
  String toPlainString() {
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    final fraction = (abs % kMinorUnits).toString().padLeft(kFractionDigits, '0');
    return '$sign${abs ~/ kMinorUnits}.$fraction';
  }

  @override
  int compareTo(Money other) => minor.compareTo(other.minor);

  @override
  bool operator ==(Object other) => other is Money && other.minor == minor;

  @override
  int get hashCode => minor.hashCode;

  @override
  String toString() => 'Money(${toPlainString()})';
}

/// نسبة مئوية مخزّنة بنقاط الأساس: 20.5% ← 2050.
@immutable
class Percent implements Comparable<Percent> {
  const Percent(this.bp) : assert(bp >= 0 && bp <= maxBp);

  static const maxBp = 10000;

  final int bp;

  /// يحلل نسبة من 0 إلى 100 بحد أقصى منزلتين عشريتين.
  static Percent? tryParse(String input) {
    final scaled = _parseScaled(input.replaceAll('%', '').replaceAll('٪', ''));
    if (scaled == null || scaled > maxBp) return null;
    return Percent(scaled);
  }

  /// نص مختصر بلا أصفار زائدة: `20`، `7.5`، `12.25`.
  String toPlainString() {
    final whole = bp ~/ 100;
    final fraction = bp % 100;
    if (fraction == 0) return '$whole';
    final digits = fraction.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '');
    return '$whole.$digits';
  }

  @override
  int compareTo(Percent other) => bp.compareTo(other.bp);

  @override
  bool operator ==(Object other) => other is Percent && other.bp == bp;

  @override
  int get hashCode => bp.hashCode;

  @override
  String toString() => 'Percent(${toPlainString()}%)';
}
