import '../../../core/formatting/digits_normalizer.dart';

/// التحقق من حقول الملف الشخصي (القسم 6.7). كل دالة تعيد رسالة خطأ أو `null`.
abstract final class ProfileValidators {
  static final _phone = RegExp(r'^\+?[0-9]{7,15}$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? fullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'الاسم مطلوب';
    if (name.length < 2) return 'الاسم قصير جداً';
    if (name.length > 60) return 'الاسم أطول من 60 حرفاً';
    return null;
  }

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

  /// يحوّل الأرقام الهندية ويحذف المسافات والشرطات؛ يعيد `null` للفارغ.
  static String? normalizePhone(String? value) {
    final phone = DigitsNormalizer.toWestern(value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    return phone.isEmpty ? null : phone;
  }
}
