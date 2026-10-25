import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/validation/contact_validators.dart';
import '../domain/collection_models.dart';

/// الدفعات: التسجيل والتعديل والحذف مع منع تجاوز المستحق (القسمان 5.4 و5.5).
class CollectionsRepository {
  CollectionsRepository(this._db);

  final AppDatabase _db;

  Stream<List<CollectionEntry>> watchForService(int serviceId) => (_db.select(_db.collections)
        ..where((c) => c.serviceId.equals(serviceId))
        ..orderBy([
          (c) => OrderingTerm(expression: c.collectionDate, mode: OrderingMode.desc),
          (c) => OrderingTerm(expression: c.id, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<CollectionEntry?> get(int id) =>
      (_db.select(_db.collections)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// أقصى مبلغ يمكن قبوله لدفعة على [serviceId]، مع استثناء دفعة قيد التعديل.
  Future<Money> available(int serviceId, {int? excludeCollectionId}) async {
    final service = await (_db.select(_db.services)..where((s) => s.id.equals(serviceId))).getSingle();
    final sum = _db.collections.amountMinor.sum();
    final query = _db.selectOnly(_db.collections)
      ..addColumns([sum])
      ..where(_db.collections.serviceId.equals(serviceId));
    if (excludeCollectionId != null) query.where(_db.collections.id.equals(excludeCollectionId).not());
    final collected = await query.map((row) => row.read(sum) ?? 0).getSingle();
    final left = service.commissionMinor - collected;
    return Money(left < 0 ? 0 : left);
  }

  Future<int> create(CollectionInput input) => _db.transaction(() async {
        await _check(input);
        return _db.into(_db.collections).insert(CollectionsCompanion.insert(
              serviceId: input.serviceId,
              amountMinor: input.amount.minor,
              collectionDate: DateFormatter.toStorage(input.date),
              paymentMethod: input.method,
              reference: Value(ContactValidators.clean(input.reference)),
            ));
      });

  Future<void> update(int id, CollectionInput input) => _db.transaction(() async {
        await _check(input, excludeCollectionId: id);
        await (_db.update(_db.collections)..where((c) => c.id.equals(id))).write(CollectionsCompanion(
          amountMinor: Value(input.amount.minor),
          collectionDate: Value(DateFormatter.toStorage(input.date)),
          paymentMethod: Value(input.method),
          reference: Value(ContactValidators.clean(input.reference)),
          updatedAt: Value(DateTime.now()),
        ));
      });

  Future<void> delete(int id) => (_db.delete(_db.collections)..where((c) => c.id.equals(id))).go();

  Future<void> _check(CollectionInput input, {int? excludeCollectionId}) async {
    if (input.amount <= Money.zero) throw const InvalidCollectionAmountException();
    final available = await this.available(input.serviceId, excludeCollectionId: excludeCollectionId);
    if (input.amount > available) throw CollectionExceedsRemainingException(available);
  }
}

final collectionsRepositoryProvider =
    Provider<CollectionsRepository>((ref) => CollectionsRepository(ref.watch(appDatabaseProvider)));

final serviceCollectionsProvider = StreamProvider.autoDispose.family<List<CollectionEntry>, int>(
  (ref, serviceId) => ref.watch(collectionsRepositoryProvider).watchForService(serviceId),
);
