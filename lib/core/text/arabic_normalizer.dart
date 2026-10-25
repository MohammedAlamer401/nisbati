import '../formatting/digits_normalizer.dart';

/// تطبيع النص العربي للبحث — انظر القسم 12.2 في الوثيقة.
///
/// يُطبَّق على النص المخزَّن في أعمدة `*_normalized` وعلى نص البحث معاً،
/// فيجد البحث بـ«احمد» الاسم «أحمد».
abstract final class ArabicNormalizer {
  static final _whitespace = RegExp(r'\s+');

  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in DigitsNormalizer.toWestern(input).runes) {
      // التشكيل، والألف الخنجرية، والتطويل.
      if ((rune >= 0x064B && rune <= 0x065F) || rune == 0x0670 || rune == 0x0640) {
        continue;
      }
      buffer.writeCharCode(switch (rune) {
        0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627, // آ أ إ ٱ ← ا
        0x0629 => 0x0647, // ة ← ه
        0x0649 => 0x064A, // ى ← ي
        0x0624 => 0x0648, // ؤ ← و
        0x0626 => 0x064A, // ئ ← ي
        _ => rune,
      });
    }
    return buffer.toString().toLowerCase().replaceAll(_whitespace, ' ').trim();
  }
}
