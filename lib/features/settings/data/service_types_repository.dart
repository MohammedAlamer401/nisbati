import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

/// اسم نوع مكرر.
class DuplicateServiceTypeException implements Exception {
  const DuplicateServiceTypeException();
}

/// لا يُحذف نوع نظامي أو مستخدم في خدمات؛ يُعطّل فقط (القسم 5.4).
class ServiceTypeInUseException implements Exception {
  const ServiceTypeInUseException();
}

/// أنواع الخدمات: الإضافة، والتسمية، والتعطيل، والترتيب (الشاشة 23).
class ServiceTypesRepository {
  ServiceTypesRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$ServiceTypesTable, ServiceType> _ordered({bool activeOnly = false}) {
    final query = _db.select(_db.serviceTypes)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder), (t) => OrderingTerm(expression: t.id)]);
    if (activeOnly) query.where((t) => t.isActive.equals(true));
    return query;
  }

  Stream<List<ServiceType>> watchAll() => _ordered().watch();

  Future<List<ServiceType>> active() => _ordered(activeOnly: true).get();

  Future<List<ServiceType>> all() => _ordered().get();

  Future<int> add(String name) async {
    final trimmed = name.trim();
    if (await _exists(trimmed)) throw const DuplicateServiceTypeException();
    final maxOrder = _db.serviceTypes.sortOrder.max();
    final last = await (_db.selectOnly(_db.serviceTypes)..addColumns([maxOrder]))
        .map((row) => row.read(maxOrder) ?? 0)
        .getSingle();
    return _db.into(_db.serviceTypes).insert(
          ServiceTypesCompanion.insert(name: trimmed, sortOrder: Value(last + 1)),
        );
  }

  Future<void> rename(int id, String name) async {
    final trimmed = name.trim();
    if (await _exists(trimmed, excludeId: id)) throw const DuplicateServiceTypeException();
    await (_db.update(_db.serviceTypes)..where((t) => t.id.equals(id)))
        .write(ServiceTypesCompanion(name: Value(trimmed)));
  }

  /// النوع النظامي («أخرى») لا يُعطّل.
  Future<void> setActive(int id, bool active) =>
      (_db.update(_db.serviceTypes)..where((t) => t.id.equals(id) & t.isSystem.equals(false)))
          .write(ServiceTypesCompanion(isActive: Value(active)));

  /// يحفظ الترتيب الجديد بحسب موضع كل معرّف في [orderedIds].
  Future<void> reorder(List<int> orderedIds) => _db.batch((b) {
        for (final (i, id) in orderedIds.indexed) {
          b.update(_db.serviceTypes, ServiceTypesCompanion(sortOrder: Value(i)), where: (t) => t.id.equals(id));
        }
      });

  Future<bool> isInUse(int id) async {
    final count = _db.services.id.count();
    final used = await (_db.selectOnly(_db.services)
          ..addColumns([count])
          ..where(_db.services.serviceTypeId.equals(id)))
        .map((row) => row.read(count) ?? 0)
        .getSingle();
    return used > 0;
  }

  Future<void> delete(int id) async {
    final type = await (_db.select(_db.serviceTypes)..where((t) => t.id.equals(id))).getSingle();
    if (type.isSystem || await isInUse(id)) throw const ServiceTypeInUseException();
    await (_db.delete(_db.serviceTypes)..where((t) => t.id.equals(id))).go();
  }

  Future<bool> _exists(String name, {int? excludeId}) async {
    final query = _db.select(_db.serviceTypes)..where((t) => t.name.equals(name));
    if (excludeId != null) query.where((t) => t.id.equals(excludeId).not());
    return (await query.get()).isNotEmpty;
  }
}

final serviceTypesRepositoryProvider =
    Provider<ServiceTypesRepository>((ref) => ServiceTypesRepository(ref.watch(appDatabaseProvider)));

final serviceTypesProvider =
    StreamProvider<List<ServiceType>>((ref) => ref.watch(serviceTypesRepositoryProvider).watchAll());
