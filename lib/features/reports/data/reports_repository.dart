import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/commission.dart';
import '../../../core/money/money.dart';
import '../../../core/time/date_period.dart';
import '../../services/data/services_repository.dart';
import '../../services/domain/service_models.dart';

/// إجماليات مجموعة خدمات (القسم 5.2): الفترة تعتمد تاريخ الخدمة،
/// والمحصّل منها يشمل كل دفعات تلك الخدمات مهما كان تاريخها.
class Totals {
  const Totals({required this.count, required this.value, required this.collection});

  static const empty = Totals(
    count: 0,
    value: Money.zero,
    collection: CollectionSummary(commission: Money.zero, collected: Money.zero),
  );

  final int count;
  final Money value;
  final CollectionSummary collection;
}

/// صف مجمّع (عميل، أو نوع، أو شهر).
class GroupTotals {
  const GroupTotals({required this.key, required this.label, required this.totals});

  final Object key;
  final String label;
  final Totals totals;
}

/// دفعة في تقرير التحصيلات.
class CollectionRow {
  const CollectionRow({required this.entry, required this.serviceTitle, required this.clientName});

  final CollectionEntry entry;
  final String serviceTitle;
  final String clientName;
}

/// تقارير وإجماليات الرئيسية (الشاشتان 10 و19).
class ReportsRepository {
  ReportsRepository(this._db);

  final AppDatabase _db;

  static const _totalsColumns =
      'COUNT(*) AS cnt, '
      'COALESCE(SUM(x.service_value_minor), 0) AS value, '
      'COALESCE(SUM(x.commission_minor), 0) AS commission, '
      'COALESCE(SUM(x.collected), 0) AS collected';

  /// استعلام الخدمات الأساسي بأعمدة مختارة بدل `*`.
  static String _select(String columns) => ServicesRepository.baseQuery.replaceFirst('SELECT *', 'SELECT $columns');

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    _db.services,
    _db.serviceTypes,
    _db.clients,
    _db.collections,
  };

  Stream<Totals> watchTotals(ServiceFilter filter) {
    final (:sql, :variables) = ServicesRepository.whereFor(filter);
    return _db
        .customSelect('${_select(_totalsColumns)} $sql', variables: variables, readsFrom: _tables)
        .watchSingle()
        .map(_toTotals);
  }

  /// إجمالي غير المحصّل حتى الآن، بلا فترة.
  Stream<Money> watchOutstanding() => _db
      .customSelect(
        '${_select('COALESCE(SUM(x.commission_minor - x.collected), 0) AS remaining')} '
        'WHERE x.commission_minor > x.collected',
        readsFrom: _tables,
      )
      .watchSingle()
      .map((row) => Money(row.read<int>('remaining')));

  /// المستحقات حسب الشهر داخل الفلتر، من الأقدم.
  Stream<List<GroupTotals>> watchByMonth(ServiceFilter filter) =>
      _grouped(
        filter,
        keyExpr: 'substr(x.service_date, 1, 7)',
        labelExpr: 'substr(x.service_date, 1, 7)',
        order: 'k ASC',
      ).map(
        (rows) => [
          for (final r in rows)
            GroupTotals(
              key: r.key,
              label: DateFormatter.monthYear(DateFormatter.fromStorage('${r.key}-01')),
              totals: r.totals,
            ),
        ],
      );

  /// آخر [months] أشهر حتى الشهر الحالي؛ الأشهر بلا خدمات أصفار (للرسم البياني).
  Stream<List<GroupTotals>> watchRecentMonths({int months = 6, DateTime? today}) {
    final now = today ?? DateFormatter.today();
    final first = DateTime(now.year, now.month - months + 1);
    final period = DatePeriod.of(PeriodKind.custom, start: first, end: DateTime(now.year, now.month + 1, 0));
    return watchByMonth(ServiceFilter(period: period)).map((rows) {
      final byKey = {for (final r in rows) r.key: r};
      return [for (var i = 0; i < months; i++) _monthOrEmpty(byKey, DateTime(first.year, first.month + i))];
    });
  }

  Stream<List<GroupTotals>> watchByClient(ServiceFilter filter) =>
      _grouped(filter, keyExpr: 'x.client_id', labelExpr: 'x.client_name', order: 'commission DESC, label ASC');

  Stream<List<GroupTotals>> watchByType(ServiceFilter filter) =>
      _grouped(filter, keyExpr: 'x.service_type_id', labelExpr: 'x.type_name', order: 'commission DESC, label ASC');

  /// الدفعات حسب تاريخ التحصيل داخل الفترة، مع فلتر العميل والنوع (القسم 5.2).
  Stream<List<CollectionRow>> watchCollections(ServiceFilter filter) {
    final where = <String>[];
    final variables = <Variable<Object>>[];
    if (filter.period.startKey != null) {
      where.add('col.collection_date >= ?');
      variables.add(Variable.withString(filter.period.startKey!));
    }
    if (filter.period.endKey != null) {
      where.add('col.collection_date <= ?');
      variables.add(Variable.withString(filter.period.endKey!));
    }
    if (filter.clientId != null) {
      where.add('s.client_id = ?');
      variables.add(Variable.withInt(filter.clientId!));
    }
    if (filter.serviceTypeId != null) {
      where.add('s.service_type_id = ?');
      variables.add(Variable.withInt(filter.serviceTypeId!));
    }
    return _db
        .customSelect(
          'SELECT col.*, s.title AS service_title, c.name AS client_name '
          'FROM collections col JOIN services s ON s.id = col.service_id JOIN clients c ON c.id = s.client_id '
          '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
          'ORDER BY col.collection_date DESC, col.id DESC',
          variables: variables,
          readsFrom: {_db.collections, _db.services, _db.clients},
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              CollectionRow(
                entry: _db.collections.map(row.data),
                serviceTitle: row.read<String>('service_title'),
                clientName: row.read<String>('client_name'),
              ),
          ],
        );
  }

  Stream<List<GroupTotals>> _grouped(
    ServiceFilter filter, {
    required String keyExpr,
    required String labelExpr,
    required String order,
  }) {
    final (:sql, :variables) = ServicesRepository.whereFor(filter);
    return _db
        .customSelect(
          '${_select('$keyExpr AS k, $labelExpr AS label, $_totalsColumns')} $sql GROUP BY $keyExpr ORDER BY $order',
          variables: variables,
          readsFrom: _tables,
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              GroupTotals(key: row.data['k'] as Object, label: row.read<String>('label'), totals: _toTotals(row)),
          ],
        );
  }

  static GroupTotals _monthOrEmpty(Map<Object, GroupTotals> byKey, DateTime month) {
    final key = DateFormatter.toStorage(month).substring(0, 7);
    return byKey[key] ?? GroupTotals(key: key, label: DateFormatter.monthYear(month), totals: Totals.empty);
  }

  static Totals _toTotals(QueryRow row) => Totals(
    count: row.read<int>('cnt'),
    value: Money(row.read<int>('value')),
    collection: CollectionSummary(
      commission: Money(row.read<int>('commission')),
      collected: Money(row.read<int>('collected')),
    ),
  );
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(appDatabaseProvider)),
);

final totalsProvider = StreamProvider.autoDispose.family<Totals, ServiceFilter>(
  (ref, filter) => ref.watch(reportsRepositoryProvider).watchTotals(filter),
);

final outstandingProvider = StreamProvider.autoDispose<Money>(
  (ref) => ref.watch(reportsRepositoryProvider).watchOutstanding(),
);

final recentMonthsProvider = StreamProvider.autoDispose<List<GroupTotals>>(
  (ref) => ref.watch(reportsRepositoryProvider).watchRecentMonths(),
);

final byMonthProvider = StreamProvider.autoDispose.family<List<GroupTotals>, ServiceFilter>(
  (ref, filter) => ref.watch(reportsRepositoryProvider).watchByMonth(filter),
);

final byClientProvider = StreamProvider.autoDispose.family<List<GroupTotals>, ServiceFilter>(
  (ref, filter) => ref.watch(reportsRepositoryProvider).watchByClient(filter),
);

final byTypeProvider = StreamProvider.autoDispose.family<List<GroupTotals>, ServiceFilter>(
  (ref, filter) => ref.watch(reportsRepositoryProvider).watchByType(filter),
);

final collectionRowsProvider = StreamProvider.autoDispose.family<List<CollectionRow>, ServiceFilter>(
  (ref, filter) => ref.watch(reportsRepositoryProvider).watchCollections(filter),
);
