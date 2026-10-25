import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/formatting/currency_formatter.dart';
import 'package:nisbati/core/money/commission.dart';
import 'package:nisbati/core/money/money.dart';

Money m(String s) => Money.tryParse(s)!;
Percent p(String s) => Percent.tryParse(s)!;

void main() {
  group('Money.tryParse', () {
    test('يقبل الأعداد الصحيحة والعشرية وفاصل الآلاف', () {
      expect(m('1000').minor, 100000);
      expect(m('1,000.00').minor, 100000);
      expect(m('333.33').minor, 33333);
      expect(m('0.5').minor, 50);
      expect(m('12.').minor, 1200);
    });

    test('يقبل الأرقام الهندية والفاصلة العشرية العربية', () {
      expect(m('١٠٠٠').minor, 100000);
      expect(m('٢٥٫٥').minor, 2550);
    });

    test('يرفض السالب وغير الرقمي والمنازل الزائدة والقيم الكبيرة', () {
      expect(Money.tryParse('-5'), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('1.234'), isNull);
      expect(Money.tryParse('1000000000'), isNull);
      expect(Money.tryParse('999999999.99')?.minor, Money.maxMinor);
    });
  });

  group('Percent.tryParse', () {
    test('من 0 إلى 100 بمنزلتين', () {
      expect(p('20').bp, 2000);
      expect(p('7.5').bp, 750);
      expect(p('20%').bp, 2000);
      expect(p('0').bp, 0);
      expect(p('100').bp, 10000);
    });

    test('يرفض ما فوق 100 والمنازل الزائدة', () {
      expect(Percent.tryParse('150'), isNull);
      expect(Percent.tryParse('100.01'), isNull);
      expect(Percent.tryParse('1.234'), isNull);
    });

    test('النص المختصر', () {
      expect(p('20').toPlainString(), '20');
      expect(p('7.5').toPlainString(), '7.5');
      expect(p('12.25').toPlainString(), '12.25');
      expect(p('0.05').toPlainString(), '0.05');
    });
  });

  group('computeCommission (القسم 5.1 و17.1)', () {
    test('1,000 × 20% = 200', () => expect(computeCommission(m('1000'), p('20')), m('200')));
    test('1,000 × 5% = 50', () => expect(computeCommission(m('1000'), p('5')), m('50')));
    test('333.33 × 7.5% = 25.00 (تقريب نصف للأعلى)',
        () => expect(computeCommission(m('333.33'), p('7.5')), m('25.00')));
    test('قيمة صفر', () => expect(computeCommission(Money.zero, p('20')), Money.zero));
    test('نسبة صفر', () => expect(computeCommission(m('1000'), p('0')), Money.zero));
    test('التقريب عند النصف بالضبط', () {
      // 0.05 × 10% = 0.005 ← 0.01
      expect(computeCommission(m('0.05'), p('10')), m('0.01'));
      // 0.04 × 10% = 0.004 ← 0.00
      expect(computeCommission(m('0.04'), p('10')), Money.zero);
    });
    test('أكبر قيمة لا تفيض', () {
      expect(computeCommission(const Money(Money.maxMinor), p('100')), const Money(Money.maxMinor));
    });
  });

  group('CollectionSummary (القسم 5.3)', () {
    test('غير محصّل', () {
      final s = CollectionSummary(commission: m('200'), collected: Money.zero);
      expect(s.status, CollectionStatus.uncollected);
      expect(s.remaining, m('200'));
    });

    test('مستحق 200 وتحصيل 50 ← متبقٍ 150 ومحصّل جزئياً', () {
      final s = CollectionSummary(commission: m('200'), collected: m('50'));
      expect(s.remaining, m('150'));
      expect(s.status, CollectionStatus.partial);
    });

    test('تحصيل كامل', () {
      final s = CollectionSummary(commission: m('200'), collected: m('200'));
      expect(s.remaining, Money.zero);
      expect(s.status, CollectionStatus.collected);
    });

    test('مستحق صفر ← لا مستحق', () {
      final s = CollectionSummary(commission: Money.zero, collected: Money.zero);
      expect(s.status, CollectionStatus.noCommission);
    });

    test('قبول الدفعة: أكبر من صفر ولا تتجاوز المتبقي', () {
      final s = CollectionSummary(commission: m('200'), collected: m('50'));
      expect(s.canAccept(m('150')), isTrue);
      expect(s.canAccept(m('160')), isFalse);
      expect(s.canAccept(Money.zero), isFalse);
    });
  });

  group('CurrencyFormatter', () {
    test('تنسيق الآلاف', () {
      expect(CurrencyFormatter.number(m('1250')), '1,250.00');
      expect(CurrencyFormatter.number(m('999999999.99')), '999,999,999.99');
      expect(CurrencyFormatter.number(m('100')), '100.00');
      expect(CurrencyFormatter.number(Money.zero), '0.00');
      expect(CurrencyFormatter.number(const Money(-15000)), '-150.00');
    });

    test('المبلغ مع رمز العملة وعزل الاتجاه', () {
      final lri = CurrencyFormatter.lri, pdi = CurrencyFormatter.pdi;
      expect(CurrencyFormatter.format(m('1250')), '${lri}1,250.00$pdi د.ل');
      expect(CurrencyFormatter.percent(p('20')), '${lri}20%$pdi');
    });
  });
}
