import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/commission.dart';
import '../../../core/money/money.dart';
import '../../../core/text/arabic_normalizer.dart';
import '../../../core/validation/contact_validators.dart';
import '../domain/service_models.dart';

/// خدمة في القوائم مع اسم نوعها وعميلها وحالة تحصيلها.
class ServiceListItem {
  const ServiceListItem({
    required this.service,
    required this.typeName,
    required this.clientName,
    required this.collection,
  });

  final ServiceRecord service;
  final String typeName;
  final String clientName;
  final CollectionSummary collection;
}

/// الخدمات: الحفظ مع حساب المستحق، والقوائم والفلاتر، وقواعد التعديل والحذف (القسمان 5.1 و5.4).
class ServicesRepository {
  ServicesRepository(this._db);

  final AppDatabase _db;

  /// الخدمات مع اسم النوع والعميل والمحصّل، تحت الاسم المستعار `x`.
  static const baseQuery = '''
    SELECT * FROM (
      SELECT s.*, t.name AS type_name, c.name AS client_name, c.name_normalized AS client_name_normalized,
        COALESCE((SELECT SUM(col.amount_minor) FROM collections col WHERE col.service_id = s.id), 0) AS collected
      FROM services s
      JOIN service_types t ON t.id = s.service_type_id
      JOIN clients c ON c.id = s.client_id
    ) x
  ''';

  Set<ResultSetImplementation<dynamic, dynamic>> get tables =>
      {_db.services, _db.serviceTypes, _db.clients, _db.collections};

  /// شرط WHERE (أو نص فارغ) ومتغيراته لفلتر [filter] على [baseQuery]. يُستخدم في التقارير أيضاً.
  static ({String sql, List<Variable<Object>> variables}) whereFor(ServiceFilter filter) {
    final where = <String>[];
    final variables = <Variable<Object>>[];

    final query = ArabicNormalizer.normalize(filter.query);
    if (query.isNotEmpty) {
      where.add(r"(x.title_normalized LIKE ? ESCAPE '\' OR x.client_name_normalized LIKE ? ESCAPE '\')");
      final like = '%${_escapeLike(query)}%';
      variables.addAll([Variable.withString(like), Variable.withString(like)]);
    }
    if (filter.status != null) {
      where.add(switch (filter.status!) {
        CollectionStatus.noCommission => 'x.commission_minor = 0',
        CollectionStatus.uncollected => 'x.commission_minor > 0 AND x.collected = 0',
        CollectionStatus.partial => 'x.collected > 0 AND x.collected < x.commission_minor',
        CollectionStatus.collected => 'x.commission_minor > 0 AND x.collected >= x.commission_minor',
      });
    }
    if (filter.serviceTypeId != null) {
      where.add('x.service_type_id = ?');
      variables.add(Variable.withInt(filter.serviceTypeId!));
    }
    if (filter.clientId != null) {
      where.add('x.client_id = ?');
      variables.add(Variable.withInt(filter.clientId!));
    }
    if (filter.period.startKey != null) {
      where.add('x.service_date >= ?');
      variables.add(Variable.withString(filter.period.startKey!));
    }
    if (filter.period.endKey != null) {
      where.add('x.service_date <= ?');
      variables.add(Variable.withString(filter.period.endKey!));
    }
    if (filter.outstandingOnly) where.add('x.commission_minor > x.collected');
    return (sql: where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}', variables: variables);
  }

  Stream<List<ServiceListItem>> watchServices(ServiceFilter filter, {int? limit}) {
    final (:sql, :variables) = whereFor(filter);
    final order = switch (filter.sort) {
      ServiceSort.newest => 'x.service_date DESC, x.id DESC',
      ServiceSort.highestValue => 'x.service_value_minor DESC, x.id DESC',
      ServiceSort.highestCommission => 'x.commission_minor DESC, x.id DESC',
      ServiceSort.highestRemaining => '(x.commission_minor - x.collected) DESC, x.id DESC',
    };

    return _db
        .customSelect(
          '$baseQuery $sql ORDER BY $order${limit == null ? '' : ' LIMIT $limit'}',
          variables: variables,
          readsFrom: tables,
        )
        .watch()
        .map((rows) => rows.map(_toItem).toList());
  }

  Stream<List<ServiceListItem>> watchForClient(int clientId) => watchServices(ServiceFilter(clientId: clientId));

  Stream<ServiceListItem?> watchService(int id) => _db
      .customSelect('$baseQuery WHERE x.id = ?', variables: [Variable.withInt(id)], readsFrom: tables)
      .watchSingleOrNull()
      .map((row) => row == null ? null : _toItem(row));

  Future<ServiceRecord?> get(int id) =>
      (_db.select(_db.services)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> create(ServiceInput input) => _db.into(_db.services).insert(ServicesCompanion.insert(
        clientId: input.clientId,
        serviceTypeId: input.serviceTypeId,
        title: input.title.trim(),
        titleNormalized: ArabicNormalizer.normalize(input.title),
        description: Value(ContactValidators.clean(input.description)),
        serviceDate: DateFormatter.toStorage(input.serviceDate),
        serviceValueMinor: input.value.minor,
        commissionBp: input.percent.bp,
        commissionMinor: input.commission.minor,
        notes: Value(ContactValidators.clean(input.notes)),
      ));

  /// يرمي [CommissionBelowCollectedException] إذا صار المستحق أقل من المحصّل.
  Future<void> update(int id, ServiceInput input) => _db.transaction(() async {
        final collected = await collectedFor(id);
        if (input.commission < collected) {
          throw CommissionBelowCollectedException(collected: collected, newCommission: input.commission);
        }
        await (_db.update(_db.services)..where((s) => s.id.equals(id))).write(ServicesCompanion(
          clientId: Value(input.clientId),
          serviceTypeId: Value(input.serviceTypeId),
          title: Value(input.title.trim()),
          titleNormalized: Value(ArabicNormalizer.normalize(input.title)),
          description: Value(ContactValidators.clean(input.description)),
          serviceDate: Value(DateFormatter.toStorage(input.serviceDate)),
          serviceValueMinor: Value(input.value.minor),
          commissionBp: Value(input.percent.bp),
          commissionMinor: Value(input.commission.minor),
          notes: Value(ContactValidators.clean(input.notes)),
          updatedAt: Value(DateTime.now()),
        ));
      });

  Future<Money> collectedFor(int serviceId) async {
    final sum = _db.collections.amountMinor.sum();
    final total = await (_db.selectOnly(_db.collections)
          ..addColumns([sum])
          ..where(_db.collections.serviceId.equals(serviceId)))
        .map((row) => row.read(sum) ?? 0)
        .getSingle();
    return Money(total);
  }

  Future<int> collectionCount(int serviceId) async {
    final count = _db.collections.id.count();
    return (_db.selectOnly(_db.collections)
          ..addColumns([count])
          ..where(_db.collections.serviceId.equals(serviceId)))
        .map((row) => row.read(count) ?? 0)
        .getSingle();
  }

  /// يحذف الخدمة ودفعاتها في معاملة واحدة (القسم 5.4).
  Future<void> delete(int id) => _db.transaction(() async {
        await (_db.delete(_db.collections)..where((c) => c.serviceId.equals(id))).go();
        await (_db.delete(_db.services)..where((s) => s.id.equals(id))).go();
      });

  ServiceListItem _toItem(QueryRow row) {
    final service = _db.services.map(row.data);
    return ServiceListItem(
      service: service,
      typeName: row.read<String>('type_name'),
      clientName: row.read<String>('client_name'),
      collection: CollectionSummary(
        commission: Money(service.commissionMinor),
        collected: Money(row.read<int>('collected')),
      ),
    );
  }

  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}

final servicesRepositoryProvider =
    Provider<ServicesRepository>((ref) => ServicesRepository(ref.watch(appDatabaseProvider)));

final serviceListProvider = StreamProvider.autoDispose.family<List<ServiceListItem>, ServiceFilter>(
  (ref, filter) => ref.watch(servicesRepositoryProvider).watchServices(filter),
);

/// آخر الخدمات المسجلة (للرئيسية).
final latestServicesProvider = StreamProvider.autoDispose<List<ServiceListItem>>(
  (ref) => ref.watch(servicesRepositoryProvider).watchServices(const ServiceFilter(), limit: 5),
);

final clientServicesProvider = StreamProvider.autoDispose.family<List<ServiceListItem>, int>(
  (ref, clientId) => ref.watch(servicesRepositoryProvider).watchForClient(clientId),
);

final serviceProvider = StreamProvider.autoDispose.family<ServiceListItem?, int>(
  (ref, id) => ref.watch(servicesRepositoryProvider).watchService(id),
);
