import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/formatting/digits_normalizer.dart';
import '../../../core/money/commission.dart';
import '../../../core/money/money.dart';
import '../../../core/text/arabic_normalizer.dart';
import '../../../core/validation/contact_validators.dart';
import '../domain/client_models.dart';

/// فلتر قائمة العملاء.
typedef ClientFilter = ({String query, bool archived});

/// العملاء: الحفظ، والبحث المطبَّع، والإجماليات، والأرشفة (القسمان 5.4 و12.2).
class ClientsRepository {
  ClientsRepository(this._db);

  final AppDatabase _db;

  // إجماليات كل عميل: الخدمات، والقيم، والمستحقات، والمحصّل منها.
  static const _summarySelect = '''
    SELECT c.*,
      COUNT(s.id) AS service_count,
      COALESCE(SUM(s.service_value_minor), 0) AS total_value,
      COALESCE(SUM(s.commission_minor), 0) AS total_commission,
      COALESCE(SUM((SELECT SUM(col.amount_minor) FROM collections col WHERE col.service_id = s.id)), 0) AS collected
    FROM clients c
    LEFT JOIN services s ON s.client_id = c.id
  ''';

  Stream<List<ClientSummary>> watchClients(ClientFilter filter) {
    final query = ArabicNormalizer.normalize(filter.query);
    final digits = DigitsNormalizer.toWestern(filter.query).replaceAll(RegExp(r'[^0-9]'), '');
    return _db
        .customSelect(
          '$_summarySelect'
          r"WHERE c.is_archived = ? AND (? = '' OR c.name_normalized LIKE ? ESCAPE '\' OR c.phone LIKE ? ESCAPE '\') "
          'GROUP BY c.id ORDER BY c.name_normalized',
          variables: [
            Variable.withBool(filter.archived),
            Variable.withString(query),
            Variable.withString('%${_escapeLike(query)}%'),
            // بلا أرقام في البحث لا يُطابَق الهاتف (LIKE NULL لا يطابق شيئاً).
            Variable<String>(digits.isEmpty ? null : '%$digits%'),
          ],
          readsFrom: {_db.clients, _db.services, _db.collections},
        )
        .watch()
        .map((rows) => rows.map(_toSummary).toList());
  }

  Stream<ClientSummary?> watchClient(int id) => _db
      .customSelect(
        '$_summarySelect WHERE c.id = ? GROUP BY c.id',
        variables: [Variable.withInt(id)],
        readsFrom: {_db.clients, _db.services, _db.collections},
      )
      .watchSingleOrNull()
      .map((row) => row == null ? null : _toSummary(row));

  Future<Client?> get(int id) => (_db.select(_db.clients)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// العملاء النشطون لاختيارهم في نموذج الخدمة.
  Future<List<Client>> activeClients() => (_db.select(_db.clients)
        ..where((c) => c.isArchived.equals(false))
        ..orderBy([(c) => OrderingTerm(expression: c.nameNormalized)]))
      .get();

  Future<int> create(ClientInput input) => _db.into(_db.clients).insert(ClientsCompanion.insert(
        name: input.name.trim(),
        nameNormalized: ArabicNormalizer.normalize(input.name),
        phone: Value(ContactValidators.normalizePhone(input.phone)),
        contactName: Value(ContactValidators.clean(input.contactName)),
        address: Value(ContactValidators.clean(input.address)),
        notes: Value(ContactValidators.clean(input.notes)),
      ));

  Future<void> update(int id, ClientInput input) =>
      (_db.update(_db.clients)..where((c) => c.id.equals(id))).write(ClientsCompanion(
        name: Value(input.name.trim()),
        nameNormalized: Value(ArabicNormalizer.normalize(input.name)),
        phone: Value(ContactValidators.normalizePhone(input.phone)),
        contactName: Value(ContactValidators.clean(input.contactName)),
        address: Value(ContactValidators.clean(input.address)),
        notes: Value(ContactValidators.clean(input.notes)),
        updatedAt: Value(DateTime.now()),
      ));

  /// هل يوجد عميل آخر بالاسم نفسه بعد التطبيع؟ (تنبيه غير مانع — القسم 5.4)
  Future<bool> hasDuplicateName(String name, {int? excludeId}) async {
    final normalized = ArabicNormalizer.normalize(name);
    final query = _db.select(_db.clients)..where((c) => c.nameNormalized.equals(normalized));
    if (excludeId != null) query.where((c) => c.id.equals(excludeId).not());
    return (await query.get()).isNotEmpty;
  }

  Future<void> setArchived(int id, bool archived) =>
      (_db.update(_db.clients)..where((c) => c.id.equals(id)))
          .write(ClientsCompanion(isArchived: Value(archived), updatedAt: Value(DateTime.now())));

  /// يحذف عميلاً بلا خدمات؛ وإلا يرمي [ClientHasServicesException].
  Future<void> delete(int id) async {
    final count = await (_db.selectOnly(_db.services)
          ..addColumns([_db.services.id.count()])
          ..where(_db.services.clientId.equals(id)))
        .map((row) => row.read(_db.services.id.count()) ?? 0)
        .getSingle();
    if (count > 0) throw ClientHasServicesException(count);
    await (_db.delete(_db.clients)..where((c) => c.id.equals(id))).go();
  }

  ClientSummary _toSummary(QueryRow row) => ClientSummary(
        client: _db.clients.map(row.data),
        serviceCount: row.read<int>('service_count'),
        totalValue: Money(row.read<int>('total_value')),
        collection: CollectionSummary(
          commission: Money(row.read<int>('total_commission')),
          collected: Money(row.read<int>('collected')),
        ),
      );

  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) => ClientsRepository(ref.watch(appDatabaseProvider)));

final clientListProvider = StreamProvider.autoDispose.family<List<ClientSummary>, ClientFilter>(
  (ref, filter) => ref.watch(clientsRepositoryProvider).watchClients(filter),
);

final clientProvider = StreamProvider.autoDispose.family<ClientSummary?, int>(
  (ref, id) => ref.watch(clientsRepositoryProvider).watchClient(id),
);
