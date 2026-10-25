import '../money/money.dart';

/// تنسيق المبالغ والنسب للعرض — انظر القسم 12.3 في الوثيقة.
abstract final class CurrencyFormatter {
  static const defaultSymbol = 'د.ل';

  // عزل اتجاه الرقم (LRI … PDI) حتى لا تنقلب الإشارات والنسب داخل نص عربي.
  static final lri = String.fromCharCode(0x2066);
  static final pdi = String.fromCharCode(0x2069);

  /// `1,250.00`
  static String number(Money money) {
    final sign = money.isNegative ? '-' : '';
    final abs = money.minor.abs();
    final whole = (abs ~/ kMinorUnits).toString();
    final fraction = (abs % kMinorUnits).toString().padLeft(kFractionDigits, '0');
    final grouped = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
      grouped.write(whole[i]);
    }
    return '$sign$grouped.$fraction';
  }

  /// `1,250.00 د.ل` مع عزل اتجاه الرقم.
  static String format(Money money, {String symbol = defaultSymbol}) =>
      '$lri${number(money)}$pdi $symbol';

  /// `20%` مع عزل الاتجاه.
  static String percent(Percent percent) => '$lri${percent.toPlainString()}%$pdi';
}
