import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/formatting/date_formatter.dart';
import 'package:nisbati/core/formatting/digits_normalizer.dart';
import 'package:nisbati/core/text/arabic_normalizer.dart';

void main() {
  group('ArabicNormalizer (القسم 12.2)', () {
    String n(String s) => ArabicNormalizer.normalize(s);

    test('«احمد» يطابق «أحمد» و«إحمد» و«آحمد»', () {
      expect(n('أحمد'), n('احمد'));
      expect(n('إحمد'), n('احمد'));
      expect(n('آحمد'), n('احمد'));
    });

    test('«مؤسسه» يطابق «مؤسسة»', () {
      expect(n('مؤسسة'), n('مؤسسه'));
      expect(n('مؤسسة'), 'موسسه');
    });

    test('ى ← ي، ئ ← ي', () {
      expect(n('مصطفى'), 'مصطفي');
      expect(n('هيئة'), 'هييه');
    });

    test('حذف التشكيل والتطويل', () {
      expect(n('مُحَمَّد'), 'محمد');
      expect(n('محـــمد'), 'محمد');
    });

    test('المسافات والحروف اللاتينية والأرقام', () {
      expect(n('  مصنع   هابي  '), 'مصنع هابي');
      expect(n('HAPPY Factory'), 'happy factory');
      expect(n('٠٩١٢٣'), '09123');
    });
  });

  group('DigitsNormalizer', () {
    test('الهندية والفارسية والفواصل', () {
      expect(DigitsNormalizer.toWestern('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(DigitsNormalizer.toWestern('۱۲۳'), '123');
      expect(DigitsNormalizer.toWestern('١٬٠٠٠٫٥'), '1,000.5');
    });
  });

  group('DateFormatter', () {
    final date = DateTime(2026, 10, 5);

    test('صيغ العرض', () {
      expect(DateFormatter.short(date), '05/10/2026');
      expect(DateFormatter.long(date), '5 أكتوبر 2026');
      expect(DateFormatter.monthYear(date), 'أكتوبر 2026');
    });

    test('التخزين ذهاباً وإياباً', () {
      expect(DateFormatter.toStorage(date), '2026-10-05');
      expect(DateFormatter.fromStorage('2026-10-05'), date);
      expect(() => DateFormatter.fromStorage('05/10/2026'), throwsFormatException);
    });
  });
}
