import 'dart:math';

/// رمز الاسترداد: 12 حرفاً بصيغة `XXXX-XXXX-XXXX` — القسم 6.6.
abstract final class RecoveryCode {
  /// حروف إنجليزية كبيرة وأرقام دون الملتبسة (O/0/I/1).
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const length = 12;

  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    final chars = List.generate(length, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
    return format(chars);
  }

  /// يقبل الإدخال بشرطات أو مسافات أو بدونها، وبحروف صغيرة أو كبيرة.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isWellFormed(String normalized) =>
      normalized.length == length && normalized.split('').every(alphabet.contains);

  static String format(String normalized) => [
        for (var i = 0; i < normalized.length; i += 4)
          normalized.substring(i, min(i + 4, normalized.length)),
      ].join('-');
}
