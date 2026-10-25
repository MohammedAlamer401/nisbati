/// يحوّل الأرقام العربية الهندية (٠–٩) والفارسية (۰–۹) إلى أرقام غربية،
/// والفاصلة العشرية العربية `٫` إلى نقطة، وفاصل الآلاف `٬` إلى فاصلة.
abstract final class DigitsNormalizer {
  static String toWestern(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune == 0x066B) {
        buffer.write('.');
      } else if (rune == 0x066C) {
        buffer.write(',');
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
