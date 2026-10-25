import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addClient([String name = 'مصنع هابي']) => db.into(db.clients).insert(
        ClientsCompanion.insert(name: name, nameNormalized: name),
      );

  Future<int> addService(int clientId) => db.into(db.services).insert(
        ServicesCompanion.insert(
          clientId: clientId,
          serviceTypeId: 1,
          title: 'تركيب 5 نقاط شبكة',
          titleNormalized: 'تركيب 5 نقاط شبكه',
          serviceDate: '2026-10-25',
          serviceValueMinor: 100000,
          commissionBp: 2000,
          commissionMinor: 20000,
        ),
      );

  test('البذور: أنواع الخدمات الستة و«أخرى» نوع نظامي', () async {
    final types = await (db.select(db.serviceTypes)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    expect(types.map((t) => t.name), defaultServiceTypes);
    expect(types.where((t) => t.isSystem).single.name, 'أخرى');
  });

  test('البذور: الإعدادات الافتراضية', () async {
    final settings = await db.select(db.appSettings).get();
    final map = {for (final s in settings) s.key: s.value};
    expect(map, SettingKeys.defaults);
  });

  test('لا يُحذف عميل له خدمات (ON DELETE RESTRICT)', () async {
    final clientId = await addClient();
    await addService(clientId);
    expect(
      () => (db.delete(db.clients)..where((c) => c.id.equals(clientId))).go(),
      throwsA(isA<SqliteException>()),
    );
  });

  test('حذف الخدمة يحذف دفعاتها (ON DELETE CASCADE)', () async {
    final serviceId = await addService(await addClient());
    for (final amount in [5000, 3000]) {
      await db.into(db.collections).insert(CollectionsCompanion.insert(
            serviceId: serviceId,
            amountMinor: amount,
            collectionDate: '2026-10-26',
            paymentMethod: PaymentMethod.cash,
          ));
    }
    expect(await db.select(db.collections).get(), hasLength(2));
    await (db.delete(db.services)..where((s) => s.id.equals(serviceId))).go();
    expect(await db.select(db.collections).get(), isEmpty);
  });

  test('القيود ترفض النسبة فوق 100% والدفعة الصفرية', () async {
    final clientId = await addClient();
    expect(
      () => db.into(db.services).insert(ServicesCompanion.insert(
            clientId: clientId,
            serviceTypeId: 1,
            title: 'خدمة',
            titleNormalized: 'خدمه',
            serviceDate: '2026-10-25',
            serviceValueMinor: 100000,
            commissionBp: 15000,
            commissionMinor: 150000,
          )),
      throwsA(isA<SqliteException>()),
    );

    final serviceId = await addService(clientId);
    expect(
      () => db.into(db.collections).insert(CollectionsCompanion.insert(
            serviceId: serviceId,
            amountMinor: 0,
            collectionDate: '2026-10-26',
            paymentMethod: PaymentMethod.transfer,
          )),
      throwsA(isA<SqliteException>()),
    );
  });
}
