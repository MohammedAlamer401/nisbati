import '../../../core/database/app_database.dart';
import '../../../core/money/commission.dart';
import '../../../core/money/money.dart';

/// عميل مع إجماليات خدماته (القسم 5.2 — شاشتا القائمة والتفاصيل).
class ClientSummary {
  const ClientSummary({
    required this.client,
    required this.serviceCount,
    required this.totalValue,
    required this.collection,
  });

  final Client client;
  final int serviceCount;

  /// مجموع قيم الخدمات (ليست دخلاً للمستخدم).
  final Money totalValue;

  /// مجموع المستحقات والمحصّل منها.
  final CollectionSummary collection;
}

/// بيانات نموذج العميل قبل الحفظ.
class ClientInput {
  const ClientInput({required this.name, this.phone, this.contactName, this.address, this.notes});

  final String name;
  final String? phone;
  final String? contactName;
  final String? address;
  final String? notes;
}

/// لا يُحذف عميل له خدمات؛ تُتاح الأرشفة بدلاً من ذلك (القسم 5.4).
class ClientHasServicesException implements Exception {
  const ClientHasServicesException(this.serviceCount);

  final int serviceCount;

  @override
  String toString() => 'ClientHasServicesException($serviceCount)';
}
