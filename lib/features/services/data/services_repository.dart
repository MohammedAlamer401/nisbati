import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/commission.dart';
import '../../../core/money/money.dart';

/// خدمة في القوائم مع اسم نوعها وحالة تحصيلها.
class ServiceListItem {
  const ServiceListItem({required this.service, required this.typeName, required this.collection});

  final ServiceRecord service;
  final String typeName;
  final CollectionSummary collection;
}

/// الخدمات — يُستكمل في المرحلة 5؛ حالياً قائمة خدمات عميل لشاشة تفاصيله.
class ServicesRepository {
  ServicesRepository(this._db);

  final AppDatabase _db;

  Stream<List<ServiceListItem>> watchForClient(int clientId) => _db
      .customSelect(
        '''
        SELECT s.*, t.name AS type_name,
          COALESCE((SELECT SUM(col.amount_minor) FROM collections col WHERE col.service_id = s.id), 0) AS collected
        FROM services s
        JOIN service_types t ON t.id = s.service_type_id
        WHERE s.client_id = ?
        ORDER BY s.service_date DESC, s.id DESC
        ''',
        variables: [Variable.withInt(clientId)],
        readsFrom: {_db.services, _db.serviceTypes, _db.collections},
      )
      .watch()
      .map((rows) => rows.map((row) {
            final service = _db.services.map(row.data);
            return ServiceListItem(
              service: service,
              typeName: row.read<String>('type_name'),
              collection: CollectionSummary(
                commission: Money(service.commissionMinor),
                collected: Money(row.read<int>('collected')),
              ),
            );
          }).toList());
}

final servicesRepositoryProvider =
    Provider<ServicesRepository>((ref) => ServicesRepository(ref.watch(appDatabaseProvider)));

final clientServicesProvider = StreamProvider.autoDispose.family<List<ServiceListItem>, int>(
  (ref, clientId) => ref.watch(servicesRepositoryProvider).watchForClient(clientId),
);
