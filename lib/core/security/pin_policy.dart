/// قواعد الرمز السري والمحاولات الخاطئة — القسمان 6.5 و10 (الشاشة 4).
abstract final class PinPolicy {
  static const length = 6;

  static const weakPinMessage = 'اختر رمزاً أصعب تخميناً';

  /// الأرقام المتطابقة (111111) والمتتالية صعوداً أو نزولاً (123456، 654321).
  static bool isWeak(String pin) {
    final digits = pin.codeUnits.map((c) => c - 0x30).toList();
    var same = true, ascending = true, descending = true;
    for (var i = 1; i < digits.length; i++) {
      final step = digits[i] - digits[i - 1];
      same &= step == 0;
      ascending &= step == 1;
      descending &= step == -1;
    }
    return same || ascending || descending;
  }

  /// مدة الانتظار بعد عدد المحاولات الخاطئة المتتالية.
  static Duration lockoutFor(int failures) => switch (failures) {
        < 5 => Duration.zero,
        5 => const Duration(seconds: 30),
        6 => const Duration(minutes: 1),
        7 => const Duration(minutes: 2),
        8 => const Duration(minutes: 5),
        9 => const Duration(minutes: 15),
        _ => const Duration(minutes: 30),
      };

  /// عدد محاولات البصمة الفاشلة التي تفرض الرمز السري.
  static const maxBiometricFailures = 3;

  /// المدة القصوى بين دخولين بالرمز السري قبل فرضه بدل البصمة.
  static const pinReminderInterval = Duration(days: 7);
}
