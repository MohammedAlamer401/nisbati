import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/database/app_database.dart';
import 'package:nisbati/core/money/money.dart';
import 'package:nisbati/core/time/date_period.dart';
import 'package:nisbati/features/clients/data/clients_repository.dart';
import 'package:nisbati/features/clients/domain/client_models.dart';
import 'package:nisbati/features/collections/data/collections_repository.dart';
import 'package:nisbati/features/collections/domain/collection_models.dart';
import 'package:nisbati/features/reports/application/report_builder.dart';
import 'package:nisbati/features/reports/data/reports_repository.dart';
import 'package:nisbati/features/reports/export/report_document.dart';
import 'package:nisbati/features/reports/export/report_exporters.dart';
import 'package:nisbati/features/services/data/services_repository.dart';
import 'package:nisbati/features/services/domain/service_models.dart';

void main() {
  late AppDatabase db;
  late ReportsRepository reports;
  late ServicesRepository services;
  late CollectionsRepository collections;
  late int happy, noor;

  final october = DatePeriod.of(PeriodKind.thisMonth, today: DateTime(2026, 10, 25));
  final november = DatePeriod.of(PeriodKind.thisMonth, today: DateTime(2026, 11, 5));

  Money m(String s) => Money.tryParse(s)!;

  Future<int> service(int client, String value, String percent, DateTime date, {int type = 1}) =>
      services.create(ServiceInput(
        clientId: client,
        serviceTypeId: type,
        title: 'خدمة $value',
        serviceDate: date,
        value: m(value),
        percent: Percent.tryParse(percent)!,
      ));

  Future<void> pay(int serviceId, String amount, DateTime date, {String? reference}) => collections.create(
        CollectionInput(
          serviceId: serviceId,
          amount: m(amount),
          date: date,
          method: PaymentMethod.transfer,
          reference: reference,
        ),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    reports = ReportsRepository(db);
    services = ServicesRepository(db);
    collections = CollectionsRepository(db);
    final clients = ClientsRepository(db);
    happy = await clients.create(const ClientInput(name: 'مصنع هابي'));
    noor = await clients.create(const ClientInput(name: 'مؤسسة النور'));

    // أكتوبر: خدمتان لهابي (200 + 50) وواحدة للنور (100).
    final a = await service(happy, '1000', '20', DateTime(2026, 10, 31));
    await service(happy, '500', '10', DateTime(2026, 10, 3), type: 2);
    final c = await service(noor, '1000', '10', DateTime(2026, 10, 10));
    // تحصيل خدمة 31 أكتوبر يوم 1 نوفمبر (القسم 17.1 — حدود الفترة).
    await pay(a, '200', DateTime(2026, 11, 1), reference: 'حوالة, رقم "7"');
    await pay(c, '40', DateTime(2026, 10, 12));
    // سبتمبر: خدمة غير محصّلة.
    await service(noor, '300', '10', DateTime(2026, 9, 15));
  });
  tearDown(() => db.close());

  group('الإجماليات (القسم 5.2)', () {
    test('الفترة بتاريخ الخدمة، والمحصّل منها يشمل دفعات الشهر التالي', () async {
      final totals = await reports.watchTotals(ServiceFilter(period: october)).first;
      expect(totals.count, 3);
      expect(totals.value, m('2500'));
      expect(totals.collection.commission, m('350'));
      expect(totals.collection.collected, m('240'));
      expect(totals.collection.remaining, m('110'));
    });

    test('نوفمبر: لا خدمات، فالمتبقي ليس سالباً', () async {
      final totals = await reports.watchTotals(ServiceFilter(period: november)).first;
      expect(totals.count, 0);
      expect(totals.collection.remaining, Money.zero);
    });

    test('غير المحصّل حتى الآن بلا فترة', () async {
      // 50 (أكتوبر) + 60 (النور أكتوبر) + 30 (سبتمبر)
      expect(await reports.watchOutstanding().first, m('140'));
    });

    test('فلتر العميل والنوع على الإجماليات', () async {
      final happyOnly = await reports.watchTotals(ServiceFilter(period: october, clientId: happy)).first;
      expect(happyOnly.collection.commission, m('250'));
      final type2 = await reports.watchTotals(const ServiceFilter(serviceTypeId: 2)).first;
      expect(type2.count, 1);
    });
  });

  group('التجميع', () {
    test('حسب الشهر مرتباً من الأقدم، وآخر 6 أشهر بأصفار للأشهر الفارغة', () async {
      final byMonth = await reports.watchByMonth(const ServiceFilter()).first;
      expect(byMonth.map((g) => g.key), ['2026-09', '2026-10']);
      expect(byMonth.last.label, 'أكتوبر 2026');

      final recent = await reports.watchRecentMonths(today: DateTime(2026, 11, 5)).first;
      expect(recent.map((g) => g.key), ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11']);
      expect(recent[4].totals.collection.commission, m('350'));
      expect(recent[5].totals.count, 0);
    });

    test('حسب العميل مرتباً بالأعلى مستحقاً، وحسب النوع', () async {
      final byClient = await reports.watchByClient(ServiceFilter(period: october)).first;
      expect(byClient.map((g) => g.label), ['مصنع هابي', 'مؤسسة النور']);
      expect(byClient.first.key, happy);
      expect(byClient.first.totals.count, 2);

      final byType = await reports.watchByType(const ServiceFilter()).first;
      expect(byType.first.label, 'تركيب شبكة');
      expect(byType.first.totals.collection.commission, m('330'));
    });

    test('التحصيلات بتاريخ التحصيل لا تاريخ الخدمة', () async {
      final oct = await reports.watchCollections(ServiceFilter(period: october)).first;
      expect(oct.single.entry.amountMinor, 4000);
      expect(oct.single.clientName, 'مؤسسة النور');
      final nov = await reports.watchCollections(ServiceFilter(period: november)).first;
      expect(nov.single.entry.amountMinor, 20000);
      final noorOnly = await reports.watchCollections(ServiceFilter(clientId: noor)).first;
      expect(noorOnly, hasLength(1));
    });
  });

  group('بناء التقارير والتصدير', () {
    late ReportBuilder builder;
    setUp(() => builder = ReportBuilder(reports, services));

    test('تقرير العملاء: صف لكل عميل وسطر إجمالي', () async {
      final doc = await builder.build(
        ReportKind.clients,
        ServiceFilter(period: october),
        symbol: 'د.ل',
        filtersLabel: '',
        now: DateTime(2026, 10, 25),
      );
      expect(doc.title, 'حسب العميل');
      expect(doc.columns.first, 'العميل');
      expect(doc.rows.map((r) => r.first), ['مصنع هابي', 'مؤسسة النور']);
      expect(doc.rows.first[3], '250.00');
      expect(doc.totals, ['الإجمالي', '3', '2,500.00', '350.00', '240.00', '110.00']);
      expect(reportFileName(doc, 'pdf'), 'نسبتي_تقرير-العملاء_2026-10-25.pdf');
    });

    test('غير المحصّلة تشمل كل الفترات مهما كانت الفترة المختارة', () async {
      final doc = await builder.build(
        ReportKind.outstanding,
        ServiceFilter(period: november),
        symbol: 'د.ل',
        filtersLabel: '',
      );
      expect(doc.periodLabel, 'كل الفترات');
      expect(doc.rows, hasLength(3));
      expect(doc.totals!.last, '140.00');
    });

    test('CSV: BOM، وعلامات الاتجاه محذوفة، والفواصل وعلامات التنصيص محمية', () async {
      final doc = await builder.build(
        ReportKind.collections,
        ServiceFilter(period: november),
        symbol: 'د.ل',
        filtersLabel: '',
      );
      final bytes = CsvExporter.build(doc);
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final text = utf8.decode(bytes.sublist(3));
      expect(text, contains('"حوالة, رقم ""7"""'));
      expect(text, isNot(contains(String.fromCharCode(0x2066))));
      expect(text.split('\r\n'), hasLength(3)); // رأس + دفعة + إجمالي
    });

    test('PDF عربي يُبنى بخط Cairo', () async {
      final doc = await builder.build(
        ReportKind.services,
        ServiceFilter(period: october),
        symbol: 'د.ل',
        filtersLabel: 'العميل: مصنع هابي',
      );
      final font = await File('assets/fonts/Cairo-Variable.ttf').readAsBytes();
      final bytes = await PdfExporter.build(
        doc,
        header: const ReportHeader(name: 'أحمد محمد', business: 'فني شبكات', phone: '0912345678'),
        font: ByteData.sublistView(Uint8List.fromList(font)),
      );
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(5000));
    });
  });
}
