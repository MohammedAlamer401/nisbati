import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/database/app_database.dart';
import 'package:nisbati/core/money/commission.dart';
import 'package:nisbati/core/money/money.dart';
import 'package:nisbati/core/time/date_period.dart';
import 'package:nisbati/features/clients/data/clients_repository.dart';
import 'package:nisbati/features/clients/domain/client_models.dart';
import 'package:nisbati/features/collections/data/collections_repository.dart';
import 'package:nisbati/features/collections/domain/collection_models.dart';
import 'package:nisbati/features/services/data/services_repository.dart';
import 'package:nisbati/features/services/domain/service_models.dart';
import 'package:nisbati/features/settings/data/service_types_repository.dart';

void main() {
  late AppDatabase db;
  late ServicesRepository services;
  late CollectionsRepository collections;
  late ServiceTypesRepository types;
  late int happy;
  late int noor;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    services = ServicesRepository(db);
    collections = CollectionsRepository(db);
    types = ServiceTypesRepository(db);
    final clients = ClientsRepository(db);
    happy = await clients.create(const ClientInput(name: 'مصنع هابي'));
    noor = await clients.create(const ClientInput(name: 'مؤسسة النور'));
  });
  tearDown(() => db.close());

  Money m(String s) => Money.tryParse(s)!;
  Percent p(String s) => Percent.tryParse(s)!;

  ServiceInput input({
    int? client,
    int type = 1,
    String title = 'تركيب 5 نقاط شبكة',
    String value = '1000',
    String percent = '20',
    DateTime? date,
  }) =>
      ServiceInput(
        clientId: client ?? happy,
        serviceTypeId: type,
        title: title,
        serviceDate: date ?? DateTime(2026, 10, 20),
        value: m(value),
        percent: p(percent),
      );

  Future<void> pay(int serviceId, String amount) => collections.create(CollectionInput(
        serviceId: serviceId,
        amount: m(amount),
        date: DateTime(2026, 10, 25),
        method: PaymentMethod.cash,
      ));

  Future<List<ServiceListItem>> list([ServiceFilter filter = const ServiceFilter()]) =>
      services.watchServices(filter).first;

  group('الحفظ والحساب (القسم 5.1)', () {
    test('المستحق يُحسب ويُخزَّن عند الحفظ', () async {
      final id = await services.create(input());
      final s = (await services.get(id))!;
      expect(s.commissionMinor, 20000);
      expect(s.serviceDate, '2026-10-20');
      expect(s.titleNormalized, 'تركيب 5 نقاط شبكه');

      final rounded = await services.create(input(value: '333.33', percent: '7.5'));
      expect((await services.get(rounded))!.commissionMinor, 2500);
    });

    test('التعديل يعيد حساب المستحق', () async {
      final id = await services.create(input());
      await services.update(id, input(percent: '5'));
      expect((await services.get(id))!.commissionMinor, 5000);
    });

    test('منع تخفيض المستحق إلى أقل من المحصّل (القسم 5.4)', () async {
      final id = await services.create(input());
      await pay(id, '200');
      expect(
        () => services.update(id, input(value: '750')), // 150 < 200
        throwsA(isA<CommissionBelowCollectedException>()),
      );
      expect((await services.get(id))!.commissionMinor, 20000);
      await services.update(id, input(value: '1500')); // 300 ≥ 200
      expect((await services.get(id))!.commissionMinor, 30000);
    });

    test('حذف الخدمة يحذف دفعاتها', () async {
      final id = await services.create(input());
      await pay(id, '50');
      await pay(id, '30');
      expect(await services.collectionCount(id), 2);
      await services.delete(id);
      expect(await services.get(id), isNull);
      expect(await db.select(db.collections).get(), isEmpty);
    });
  });

  group('الفلاتر والترتيب', () {
    late int uncollected, partial, collected, zero;

    setUp(() async {
      uncollected = await services.create(input(title: 'تركيب كاميرات', type: 2, date: DateTime(2026, 9, 5)));
      partial = await services.create(input(title: 'شبكة المصنع', value: '2000'));
      await pay(partial, '100');
      collected = await services.create(input(client: noor, title: 'تدريب الموظفين', type: 3, value: '500'));
      await pay(collected, '100');
      zero = await services.create(input(title: 'صيانة مجانية', value: '0'));
    });

    test('حالة التحصيل', () async {
      Future<List<int>> ids(CollectionStatus s) async =>
          (await list(ServiceFilter(status: s))).map((i) => i.service.id).toList();
      expect(await ids(CollectionStatus.uncollected), [uncollected]);
      expect(await ids(CollectionStatus.partial), [partial]);
      expect(await ids(CollectionStatus.collected), [collected]);
      expect(await ids(CollectionStatus.noCommission), [zero]);
    });

    test('البحث بعنوان الخدمة أو اسم العميل مع التطبيع', () async {
      expect((await list(const ServiceFilter(query: 'شبكه'))).single.service.id, partial);
      expect((await list(const ServiceFilter(query: 'موسسه'))).single.service.id, collected);
    });

    test('النوع والعميل والفترة', () async {
      expect((await list(const ServiceFilter(serviceTypeId: 2))).single.service.id, uncollected);
      expect((await list(ServiceFilter(clientId: noor))).single.service.id, collected);
      final october = DatePeriod.of(PeriodKind.thisMonth, today: DateTime(2026, 10, 25));
      expect((await list(ServiceFilter(period: october))).map((i) => i.service.id), isNot(contains(uncollected)));
      final september = DatePeriod.of(PeriodKind.lastMonth, today: DateTime(2026, 10, 25));
      expect((await list(ServiceFilter(period: september))).single.service.id, uncollected);
    });

    test('الترتيب بالأعلى متبقياً', () async {
      final items = await list(const ServiceFilter(sort: ServiceSort.highestRemaining));
      expect(items.first.service.id, partial); // 400 − 100 = 300
      expect(items.first.collection.remaining, m('300'));
      expect(items.first.clientName, 'مصنع هابي');
      expect(items.first.typeName, 'تركيب شبكة');
    });
  });

  group('الدفعات (القسم 5.5)', () {
    late int serviceId;
    setUp(() async => serviceId = await services.create(input())); // مستحق 200

    test('مستحق 200 وتحصيل 50 ← متبقٍ 150 ومحصّل جزئياً', () async {
      await pay(serviceId, '50');
      final item = (await services.watchService(serviceId).first)!;
      expect(item.collection.remaining, m('150'));
      expect(item.collection.status, CollectionStatus.partial);
    });

    test('منع التحصيل الزائد والمبلغ الصفري', () async {
      await pay(serviceId, '150');
      expect(() => pay(serviceId, '60'), throwsA(isA<CollectionExceedsRemainingException>()));
      expect(() => pay(serviceId, '0'), throwsA(isA<InvalidCollectionAmountException>()));
      await pay(serviceId, '50');
      expect((await services.watchService(serviceId).first)!.collection.status, CollectionStatus.collected);
    });

    test('تعديل الدفعة يستثني مبلغها القديم من الحساب', () async {
      await pay(serviceId, '150');
      final entry = (await collections.watchForService(serviceId).first).single;
      expect(await collections.available(serviceId, excludeCollectionId: entry.id), m('200'));
      await collections.update(
        entry.id,
        CollectionInput(serviceId: serviceId, amount: m('80'), date: DateTime(2026, 10, 26), method: PaymentMethod.transfer),
      );
      expect((await services.watchService(serviceId).first)!.collection.remaining, m('120'));
      expect(
        () => collections.update(
          entry.id,
          CollectionInput(serviceId: serviceId, amount: m('201'), date: DateTime(2026, 10, 26), method: PaymentMethod.cash),
        ),
        throwsA(isA<CollectionExceedsRemainingException>()),
      );
    });

    test('حذف الدفعة يعيد المتبقي، والسجل مرتب من الأحدث', () async {
      await collections.create(CollectionInput(
        serviceId: serviceId,
        amount: m('20'),
        date: DateTime(2026, 10, 21),
        method: PaymentMethod.cash,
      ));
      await pay(serviceId, '30'); // 25 أكتوبر
      final log = await collections.watchForService(serviceId).first;
      expect(log.map((e) => e.collectionDate), ['2026-10-25', '2026-10-21']);
      await collections.delete(log.first.id);
      expect((await services.watchService(serviceId).first)!.collection.remaining, m('180'));
    });
  });

  group('أنواع الخدمات (القسم 5.4)', () {
    test('الإضافة في آخر الترتيب، ورفض المكرر', () async {
      final id = await types.add('برمجة');
      expect((await types.all()).last.id, id);
      expect(() => types.add(' برمجة '), throwsA(isA<DuplicateServiceTypeException>()));
    });

    test('«أخرى» لا يُعطّل ولا يُحذف؛ المعطّل يختفي من النشطة', () async {
      final other = (await types.all()).firstWhere((t) => t.isSystem);
      await types.setActive(other.id, false);
      expect((await types.all()).firstWhere((t) => t.isSystem).isActive, isTrue);
      expect(() => types.delete(other.id), throwsA(isA<ServiceTypeInUseException>()));

      await types.setActive(2, false);
      expect((await types.active()).map((t) => t.id), isNot(contains(2)));
    });

    test('لا يُحذف نوع مستخدم في خدمات، ويُحذف غير المستخدم', () async {
      await services.create(input(type: 1));
      expect(() => types.delete(1), throwsA(isA<ServiceTypeInUseException>()));
      await types.delete(4);
      expect((await types.all()).map((t) => t.id), isNot(contains(4)));
    });

    test('إعادة الترتيب', () async {
      final ids = (await types.all()).map((t) => t.id).toList();
      await types.reorder(ids.reversed.toList());
      expect((await types.all()).map((t) => t.id), ids.reversed);
    });
  });

  group('DatePeriod', () {
    test('حدود الأشهر والسنة، والشهر السابق في يناير', () {
      final oct = DatePeriod.of(PeriodKind.thisMonth, today: DateTime(2026, 10, 25));
      expect((oct.startKey, oct.endKey), ('2026-10-01', '2026-10-31'));
      final feb = DatePeriod.of(PeriodKind.thisMonth, today: DateTime(2028, 2, 10));
      expect(feb.endKey, '2028-02-29');
      final lastOfJan = DatePeriod.of(PeriodKind.lastMonth, today: DateTime(2027, 1, 15));
      expect((lastOfJan.startKey, lastOfJan.endKey), ('2026-12-01', '2026-12-31'));
      final year = DatePeriod.of(PeriodKind.thisYear, today: DateTime(2026, 10, 25));
      expect((year.startKey, year.endKey), ('2026-01-01', '2026-12-31'));
    });

    test('الحدود شاملة لليوم الأول والأخير', () {
      final oct = DatePeriod.of(PeriodKind.thisMonth, today: DateTime(2026, 10, 25));
      expect(oct.contains(DateTime(2026, 10, 1)), isTrue);
      expect(oct.contains(DateTime(2026, 10, 31)), isTrue);
      expect(oct.contains(DateTime(2026, 11, 1)), isFalse);
      expect(DatePeriod.all.contains(DateTime(1999)), isTrue);
    });
  });
}
