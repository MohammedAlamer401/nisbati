import '../../../core/validation/contact_validators.dart';

/// التحقق من حقول الملف الشخصي (القسم 6.7). كل دالة تعيد رسالة خطأ أو `null`.
abstract final class ProfileValidators {
  static String? fullName(String? value) => ContactValidators.requiredName(value, max: 60);

  static String? phone(String? value) => ContactValidators.phone(value);

  static String? email(String? value) => ContactValidators.email(value);

  static String? normalizePhone(String? value) => ContactValidators.normalizePhone(value);
}
