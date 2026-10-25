/// تنسيق التواريخ — ميلادي فقط بأرقام غربية (القسمان 4 و12.3 في الوثيقة).
///
/// التواريخ تُخزَّن «تاريخاً فقط» بصيغة `YYYY-MM-DD` دون وقت أو منطقة زمنية.
abstract final class DateFormatter {
  static const months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// `25/10/2026` للقوائم.
  static String short(DateTime date) => '${_two(date.day)}/${_two(date.month)}/${date.year}';

  /// `25 أكتوبر 2026` للتفاصيل والتقارير.
  static String long(DateTime date) => '${date.day} ${months[date.month - 1]} ${date.year}';

  /// `أكتوبر 2026` لعناوين الأشهر.
  static String monthYear(DateTime date) => '${months[date.month - 1]} ${date.year}';

  /// `2026-10-25` للتخزين.
  static String toStorage(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

  /// يقرأ `YYYY-MM-DD` ويعيد تاريخاً محلياً بلا وقت.
  static DateTime fromStorage(String value) {
    final parts = value.split('-');
    if (parts.length != 3) throw FormatException('صيغة تاريخ غير صالحة', value);
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// تاريخ اليوم بلا وقت.
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
