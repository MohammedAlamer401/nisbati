// يلتقط صوراً للشاشات بالخط الحقيقي للمراجعة البصرية (لا يعمل في CI).
// التشغيل: flutter test tool/screenshots_test.dart --update-goldens
// الصور تُحفظ في build/screenshots/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/database/app_database.dart';
import 'package:nisbati/core/formatting/date_formatter.dart';
import 'package:nisbati/core/money/money.dart';
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

import '../test/helpers/test_app.dart';

Future<void> _loadFonts() async {
  final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
  await cairo.load();
  // خط أيقونات Material من نسخة Flutter المثبتة.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (flutterRoot != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}

Future<void> _shot(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/screenshots/$name.png'));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(_loadFonts);

  appTest('welcome + onboarding', (tester, app) async {
    _phone(tester);
    await app.pump(tester);
    await _shot('01_welcome');
    await tapVisible(tester, find.text('ابدأ'));
    await tester.enterText(find.byType(TextFormField).first, 'أحمد محمد');
    await tester.enterText(find.byType(TextFormField).at(1), 'فني شبكات وكاميرات');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await _shot('02_profile_step');
    await tapVisible(tester, find.text('التالي'));
    await enterPin(tester, '482');
    await _shot('03_pin_step');
    await enterPin(tester, '915');
    await enterPin(tester, '482915');
    await tapVisible(tester, find.byType(CheckboxListTile));
    await tester.scrollUntilVisible(find.text('احفظ رمز الاسترداد'), -200);
    await settle(tester);
    await _shot('04_recovery_step');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'التالي'));
    await _shot('05_biometric_step');
  });

  appTest('clients', (tester, app) async {
    _phone(tester);
    await app.seedExistingUser();
    final clients = ClientsRepository(app.db);
    final happy = await clients.create(const ClientInput(name: 'مصنع هابي', phone: '0912345678', address: 'طرابلس'));
    await clients.create(const ClientInput(name: 'مؤسسة النور للتقنية', phone: '0923334444'));
    final serviceId = await app.db.into(app.db.services).insert(ServicesCompanion.insert(
          clientId: happy,
          serviceTypeId: 1,
          title: 'تركيب 5 نقاط شبكة',
          titleNormalized: 'تركيب 5 نقاط شبكه',
          serviceDate: '2026-10-20',
          serviceValueMinor: 100000,
          commissionBp: 2000,
          commissionMinor: 20000,
        ));
    await app.db.into(app.db.collections).insert(CollectionsCompanion.insert(
          serviceId: serviceId,
          amountMinor: 5000,
          collectionDate: '2026-10-22',
          paymentMethod: PaymentMethod.cash,
        ));
    await app.pump(tester);
    await enterPin(tester, '482915');
    await tapVisible(tester, find.text('العملاء'));
    await _shot('09_clients');
    await tapVisible(tester, find.text('مصنع هابي'));
    await _shot('10_client_details');
  });

  appTest('services', (tester, app) async {
    _phone(tester);
    await app.seedExistingUser();
    await ClientsRepository(app.db).create(const ClientInput(name: 'مصنع هابي'));
    await app.pump(tester);
    await enterPin(tester, '482915');
    await tapVisible(tester, find.text('الخدمات'));
    await tapVisible(tester, find.byType(FloatingActionButton));
    await tapVisible(tester, find.text('اختر العميل').first);
    await tapVisible(tester, find.text('مصنع هابي'));
    await tester.enterText(find.byType(TextFormField).at(0), 'تركيب 5 نقاط شبكة');
    await tester.enterText(find.byType(TextFormField).at(1), '1000');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.scrollUntilVisible(find.text('مستحقاتي من الخدمة'), 200, scrollable: find.byType(Scrollable).last);
    await settle(tester);
    await _shot('11_service_form');
    await tapVisible(tester, find.text('حفظ الخدمة'));
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await _shot('12_service_details');
    await tester.scrollUntilVisible(find.text('تسجيل تحصيل'), 200, scrollable: find.byType(Scrollable).last);
    await tapVisible(tester, find.text('تسجيل تحصيل'));
    await _shot('13_collection_form');
  });

  appTest('dashboard + reports', (tester, app) async {
    _phone(tester);
    await app.seedExistingUser();
    final clients = ClientsRepository(app.db);
    final services = ServicesRepository(app.db);
    final collections = CollectionsRepository(app.db);
    final today = DateFormatter.today();
    final happy = await clients.create(const ClientInput(name: 'مصنع هابي'));
    final noor = await clients.create(const ClientInput(name: 'مؤسسة النور للتقنية'));
    for (final (client, title, value, percent, monthsAgo, paid) in [
      (happy, 'تركيب 5 نقاط شبكة', '1000', '20', 0, '50'),
      (noor, 'تركيب 8 كاميرات', '2400', '15', 0, '360'),
      (happy, 'صيانة الشبكة', '600', '20', 1, '120'),
      (noor, 'تدريب الموظفين', '1500', '10', 2, '100'),
      (happy, 'عرض تطبيق المخازن', '800', '25', 4, '0'),
    ]) {
      final id = await services.create(ServiceInput(
        clientId: client,
        serviceTypeId: 1,
        title: title,
        serviceDate: DateTime(today.year, today.month - monthsAgo, monthsAgo == 0 ? today.day : 10),
        value: Money.tryParse(value)!,
        percent: Percent.tryParse(percent)!,
      ));
      if (paid != '0') {
        await collections.create(CollectionInput(
          serviceId: id,
          amount: Money.tryParse(paid)!,
          date: today,
          method: PaymentMethod.cash,
        ));
      }
    }
    await app.pump(tester);
    await enterPin(tester, '482915');
    await _shot('14_dashboard_data');
    await tapVisible(tester, find.text('التقارير'));
    await tapVisible(tester, find.text('حسب العميل'));
    await _shot('15_reports');

    // ملف PDF نموذجي للمراجعة.
    await tester.runAsync(() async {
      final doc = await ReportBuilder(ReportsRepository(app.db), services).build(
        ReportKind.services,
        const ServiceFilter(),
        symbol: 'د.ل',
        filtersLabel: '',
      );
      final font = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');
      final bytes = await PdfExporter.build(
        doc,
        header: const ReportHeader(name: 'أحمد محمد', business: 'فني شبكات وكاميرات', phone: '0912345678'),
        font: font,
      );
      await File('build/screenshots/sample_report.pdf').writeAsBytes(bytes);
    });
  });

  appTest('lock + settings', (tester, app) async {
    _phone(tester);
    await app.seedExistingUser();
    await app.pump(tester);
    await enterPin(tester, '11');
    await _shot('06_lock');
    await enterPin(tester, '1111');
    await enterPin(tester, '482915');
    await _shot('07_dashboard');
    await tapVisible(tester, find.text('الإعدادات'));
    await _shot('08_settings');
  });
}
