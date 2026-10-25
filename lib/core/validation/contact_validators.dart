import '../formatting/digits_normalizer.dart';

/// التحقق من بيانات الاتصال المشتركة بين الملف الشخصي والعملاء.
/// كل دالة تحقق تعيد رسالة خطأ أو `null`.
abstract final class ContactValidators {
  static final _phone = RegExp(r'^\+?[0-9]{7,15}$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// اسم إلزامي بين [min] و[max] حرفاً بعد إزالة المسافات الطرفية.
  static String? requiredName(String? value, {int min = 2, int max = 60}) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'الاسم مطلوب';
    if (name.length < min) return 'الاسم قصير جداً';
    if (name.length > max) return 'الاسم أطول من $max حرفاً';
    return null;
  }

  /// الهاتف اختياري: أرقام و`+` فقط، 7–15 رقماً.
  static String? phone(String? value) {
    final phone = normalizePhone(value);
    if (phone == null) return null;
    return _phone.hasMatch(phone) ? null : 'رقم هاتف غير صالح';
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    return _email.hasMatch(email) ? null : 'بريد إلكتروني غير صالح';
  }

  /// يحوّل الأرقام الهندية ويحذف المسافات والشرطات والأقواس؛ يعيد `null` للفارغ.
  static String? normalizePhone(String? value) {
    final phone = DigitsNormalizer.toWestern(value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    return phone.isEmpty ? null : phone;
  }

  /// يعيد النص بعد إزالة المسافات الطرفية، أو `null` إن كان فارغاً.
  static String? clean(String? value) => (value == null || value.trim().isEmpty) ? null : value.trim();
}
