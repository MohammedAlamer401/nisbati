import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'نقدي',
        PaymentMethod.transfer => 'تحويل',
        PaymentMethod.other => 'أخرى',
      };
}

/// بيانات دفعة قبل الحفظ (القسم 5.5).
class CollectionInput {
  const CollectionInput({
    required this.serviceId,
    required this.amount,
    required this.date,
    required this.method,
    this.reference,
  });

  final int serviceId;
  final Money amount;
  final DateTime date;
  final PaymentMethod method;
  final String? reference;
}

/// مجموع الدفعات سيتجاوز المستحق (التحصيل الزائد ممنوع — القسم 4).
class CollectionExceedsRemainingException implements Exception {
  const CollectionExceedsRemainingException(this.available);

  /// أقصى مبلغ مسموح لهذه الدفعة.
  final Money available;
}

/// مبلغ الدفعة صفر أو أقل.
class InvalidCollectionAmountException implements Exception {
  const InvalidCollectionAmountException();
}
