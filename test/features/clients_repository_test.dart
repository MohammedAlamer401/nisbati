import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/database/app_database.dart';
import 'package:nisbati/core/money/money.dart';
import 'package:nisbati/features/clients/data/clients_repository.dart';
import 'package:nisbati/features/clients/domain/client_models.dart';

void main() {
  late AppDatabase db;
  late ClientsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ClientsRepository(db);
  });
  tearDown(() => db.close());

  Future<List<ClientSummary>> list({String query = '', bool archived = false}) =>
      repo.watchClients((query: query, archived: archived)).first;

  Future<int> addService(int clientId, int valueMinor, int bp) => db.into(db.services).insert(
        ServicesCompanion.insert(
          clientId: clientId,
          serviceTypeId: 1,
          title: 'خدمة',
          titleNormalized: 'خدمه',
          serviceDate: '2026-10-25',
          serviceValueMinor: valueMinor,
          commissionBp: bp,
          commissionMinor: (valueMinor * bp + 5000) ~/ 10000,
        ),
      );

  test('الحفظ يطبّع الاسم والهاتف ويحوّل الفارغ إلى null', () async {
    final id = await repo.create(const ClientInput(name: '  مؤسسة أحمد  ', phone: '٠٩١ ٢٣٤-٥٦٧٨', contactName: ' '));
    final client = (await repo.get(id))!;
    expect(client.name, 'مؤسسة أحمد');
    expect(client.nameNormalized, 'موسسه احمد');
    expect(client.phone, '0912345678');
    expect(client.contactName, isNull);
    expect(client.isArchived, isFalse);
  });

  group('البحث (القسم 12.2)', () {
    setUp(() async {
      await repo.create(const ClientInput(name: 'أحمد للتقنية', phone: '0912345678'));
      await repo.create(const ClientInput(name: 'مؤسسة النور', phone: '0923334444'));
      await repo.create(const ClientInput(name: 'مصنع هابي'));
    });

    test('بلا بحث: الكل مرتباً بالاسم', () async {
      expect((await list()).map((s) => s.client.name), ['احمد للتقنية', 'مصنع هابي', 'موسسه النور'].map((n) {
        return {'احمد للتقنية': 'أحمد للتقنية', 'مصنع هابي': 'مصنع هابي', 'موسسه النور': 'مؤسسة النور'}[n];
      }));
    });

    test('«احمد» يجد «أحمد»، و«مؤسسه» يجد «مؤسسة»', () async {
      expect((await list(query: 'احمد')).single.client.name, 'أحمد للتقنية');
      expect((await list(query: 'مؤسسه')).single.client.name, 'مؤسسة النور');
    });

    test('البحث بجزء من الهاتف وبالأرقام الهندية', () async {
      expect((await list(query: '2345')).single.client.name, 'أحمد للتقنية');
      expect((await list(query: '٠٩٢٣')).single.client.name, 'مؤسسة النور');
    });

    test('رموز LIKE تُعامل كنص عادي', () async {
      expect(await list(query: '%'), isEmpty);
      expect(await list(query: '_'), isEmpty);
    });
  });

  test('الأرشفة تنقل العميل بين القائمتين', () async {
    final id = await repo.create(const ClientInput(name: 'مصنع هابي'));
    await repo.setArchived(id, true);
    expect(await list(), isEmpty);
    expect((await list(archived: true)).single.client.id, id);
    expect(await repo.activeClients(), isEmpty);
    await repo.setArchived(id, false);
    expect(await list(archived: true), isEmpty);
  });

  test('الإجماليات: الخدمات والقيم والمستحقات والمحصّل والمتبقي', () async {
    final id = await repo.create(const ClientInput(name: 'مصنع هابي'));
    final first = await addService(id, 100000, 2000); // 1,000 × 20% = 200
    await addService(id, 50000, 1000); // 500 × 10% = 50
    await db.into(db.collections).insert(CollectionsCompanion.insert(
          serviceId: first,
          amountMinor: 5000,
          collectionDate: '2026-10-26',
          paymentMethod: PaymentMethod.cash,
        ));

    final summary = (await repo.watchClient(id).first)!;
    expect(summary.serviceCount, 2);
    expect(summary.totalValue, const Money(150000));
    expect(summary.collection.commission, const Money(25000));
    expect(summary.collection.collected, const Money(5000));
    expect(summary.collection.remaining, const Money(20000));

    // عميل بلا خدمات: أصفار.
    final empty = await repo.create(const ClientInput(name: 'عميل جديد'));
    final emptySummary = (await repo.watchClient(empty).first)!;
    expect(emptySummary.serviceCount, 0);
    expect(emptySummary.collection.commission, Money.zero);
  });

  test('لا يُحذف عميل له خدمات، ويُحذف إن لم تكن له', () async {
    final withServices = await repo.create(const ClientInput(name: 'مصنع هابي'));
    await addService(withServices, 100000, 2000);
    expect(() => repo.delete(withServices), throwsA(isA<ClientHasServicesException>()));
    expect(await repo.get(withServices), isNotNull);

    final empty = await repo.create(const ClientInput(name: 'عميل جديد'));
    await repo.delete(empty);
    expect(await repo.get(empty), isNull);
  });

  test('الاسم المكرر بعد التطبيع، مع استثناء العميل نفسه عند التعديل', () async {
    final id = await repo.create(const ClientInput(name: 'مؤسسة أحمد'));
    expect(await repo.hasDuplicateName('موسسه احمد'), isTrue);
    expect(await repo.hasDuplicateName('مؤسسة أحمد', excludeId: id), isFalse);
    expect(await repo.hasDuplicateName('مصنع هابي'), isFalse);
  });

  test('التعديل يحدّث الاسم المطبَّع', () async {
    final id = await repo.create(const ClientInput(name: 'مصنع هابي'));
    await repo.update(id, const ClientInput(name: 'مصنع إشراق', phone: '0911111111'));
    final client = (await repo.get(id))!;
    expect(client.name, 'مصنع إشراق');
    expect(client.nameNormalized, 'مصنع اشراق');
    expect((await list(query: 'اشراق')).single.client.id, id);
  });
}
