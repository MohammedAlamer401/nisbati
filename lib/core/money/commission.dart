import 'money.dart';

/// حساب المستحق — انظر القسم 5.1 في الوثيقة.
///
/// `مستحقاتي = قيمة الخدمة × النسبة ÷ 100`، بأعداد صحيحة وتقريب نصف للأعلى.
Money computeCommission(Money serviceValue, Percent percent) {
  assert(!serviceValue.isNegative, 'قيمة الخدمة لا تكون سالبة');
  return Money((serviceValue.minor * percent.bp + 5000) ~/ 10000);
}

/// حالة التحصيل — انظر القسم 5.3 في الوثيقة.
enum CollectionStatus {
  /// المستحق صفر (قيمة أو نسبة صفر).
  noCommission,
  uncollected,
  partial,
  collected,
}

/// ملخص تحصيل خدمة واحدة أو مجموعة خدمات.
class CollectionSummary {
  const CollectionSummary({required this.commission, required this.collected});

  final Money commission;
  final Money collected;

  /// المتبقي لا يكون سالباً أبداً؛ قواعد الإدخال تمنع التحصيل الزائد.
  Money get remaining => collected >= commission ? Money.zero : commission - collected;

  CollectionStatus get status {
    if (commission.isZero) return CollectionStatus.noCommission;
    if (collected.isZero) return CollectionStatus.uncollected;
    if (remaining.isZero) return CollectionStatus.collected;
    return CollectionStatus.partial;
  }

  /// هل يمكن قبول دفعة بهذا المبلغ؟ (أكبر من صفر ولا تتجاوز المتبقي)
  bool canAccept(Money payment) => payment > Money.zero && payment <= remaining;
}
