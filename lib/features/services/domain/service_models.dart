import 'package:flutter/foundation.dart';

import '../../../core/money/commission.dart';
import '../../../core/money/money.dart';
import '../../../core/time/date_period.dart';

/// بيانات نموذج الخدمة قبل الحفظ (القسم 5.3).
class ServiceInput {
  const ServiceInput({
    required this.clientId,
    required this.serviceTypeId,
    required this.title,
    required this.serviceDate,
    required this.value,
    required this.percent,
    this.description,
    this.notes,
  });

  final int clientId;
  final int serviceTypeId;
  final String title;
  final DateTime serviceDate;
  final Money value;
  final Percent percent;
  final String? description;
  final String? notes;

  Money get commission => computeCommission(value, percent);
}

/// ترتيب قائمة الخدمات.
enum ServiceSort {
  newest('الأحدث'),
  highestValue('الأعلى قيمة'),
  highestCommission('الأعلى مستحقاً'),
  highestRemaining('الأعلى متبقياً');

  const ServiceSort(this.label);
  final String label;
}

/// فلتر قائمة الخدمات.
@immutable
class ServiceFilter {
  const ServiceFilter({
    this.query = '',
    this.status,
    this.serviceTypeId,
    this.clientId,
    this.period = DatePeriod.all,
    this.sort = ServiceSort.newest,
  });

  final String query;
  final CollectionStatus? status;
  final int? serviceTypeId;
  final int? clientId;
  final DatePeriod period;
  final ServiceSort sort;

  ServiceFilter copyWith({
    String? query,
    CollectionStatus? Function()? status,
    int? Function()? serviceTypeId,
    DatePeriod? period,
    ServiceSort? sort,
  }) =>
      ServiceFilter(
        query: query ?? this.query,
        status: status != null ? status() : this.status,
        serviceTypeId: serviceTypeId != null ? serviceTypeId() : this.serviceTypeId,
        clientId: clientId,
        period: period ?? this.period,
        sort: sort ?? this.sort,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceFilter &&
      other.query == query &&
      other.status == status &&
      other.serviceTypeId == serviceTypeId &&
      other.clientId == clientId &&
      other.period == period &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(query, status, serviceTypeId, clientId, period, sort);
}

/// التعديل يجعل المستحق أقل من المحصّل (القسم 5.4).
class CommissionBelowCollectedException implements Exception {
  const CommissionBelowCollectedException({required this.collected, required this.newCommission});

  final Money collected;
  final Money newCommission;
}
