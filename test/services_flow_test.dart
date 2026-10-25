import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/database/app_database.dart';
import 'package:nisbati/core/money/money.dart';
import 'package:nisbati/features/clients/data/clients_repository.dart';
import 'package:nisbati/features/clients/domain/client_models.dart';
import 'package:nisbati/features/collections/data/collections_repository.dart';
import 'package:nisbati/features/collections/domain/collection_models.dart';
import 'package:nisbati/features/services/data/services_repository.dart';
import 'package:nisbati/features/services/domain/service_models.dart';
import 'package:nisbati/features/services/presentation/service_details_screen.dart';

import 'helpers/test_app.dart';

Future<void> unlock(WidgetTester tester, TestApp app) async {
  await app.seedExistingUser();
  await app.pump(tester);
  await enterPin(tester, '482915');
}

/// يمرّر قائمة شاشة تفاصيل الخدمة حتى يظهر [finder].
Future<void> scrollDetailsTo(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.descendant(of: find.byType(ServiceDetailsScreen), matching: find.byType(Scrollable)).first,
    );

Future<int> seedService(TestApp app, {String value = '1000', String percent = '20'}) async {
  final client = await ClientsRepository(app.db).create(const ClientInput(name: 'مصنع هابي'));
  return ServicesRepository(app.db).create(ServiceInput(
    clientId: client,
    serviceTypeId: 1,
    title: 'تركيب 5 نقاط شبكة',
    serviceDate: DateTime(2026, 10, 20),
    value: Money.tryParse(value)!,
    percent: Percent.tryParse(percent)!,
  ));
}

void main() {
  appTest('إضافة خدمة: حساب فوري، ثم التفاصيل، ثم تحصيل جزئي', (tester, app) async {
    await ClientsRepository(app.db).create(const ClientInput(name: 'مصنع هابي'));
    await unlock(tester, app);
    await tapVisible(tester, find.text('الخدمات'));
    expect(find.text('لا توجد خدمات بعد'), findsOneWidget);

    await tapVisible(tester, find.byType(FloatingActionButton));
    expect(find.text('إضافة خدمة جديدة'), findsOneWidget);

    // الحقول الإلزامية.
    await tapVisible(tester, find.text('حفظ الخدمة'));
    expect(find.text('اختر العميل'), findsWidgets);
    expect(find.text('عنوان الخدمة مطلوب'), findsOneWidget);

    await tapVisible(tester, find.text('اختر العميل').first);
    await tapVisible(tester, find.text('مصنع هابي'));
    await tester.enterText(find.widgetWithText(TextFormField, 'مثال: تركيب 5 نقاط شبكة'), 'تركيب 5 نقاط شبكة');

    // النسبة الافتراضية 20% من الإعدادات، والمستحق يتحدث مع الكتابة.
    final value = find.byType(TextFormField).at(1);
    await tester.enterText(value, '1000');
    await tester.pump();
    expect(find.textContaining('200.00'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), '5');
    await tester.pump();
    expect(find.textContaining('50.00'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), '20');
    await tester.pump();

    await tapVisible(tester, find.text('حفظ الخدمة'));
    expect(find.text('تفاصيل الخدمة'), findsOneWidget);
    expect(find.text('تركيب 5 نقاط شبكة'), findsOneWidget);
    expect(find.text('غير محصّل'), findsOneWidget);
    // تختفي رسالة «تم حفظ الخدمة» العائمة حتى لا تغطي الأزرار السفلية.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);

    await scrollDetailsTo(tester, find.text('تسجيل تحصيل'));
    await tapVisible(tester, find.text('تسجيل تحصيل'));
    expect(find.text('المتبقي قبل الدفعة'), findsOneWidget);
    // يُقترح المتبقي كاملاً.
    expect(find.widgetWithText(TextFormField, '200.00'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '250');
    await tapVisible(tester, find.text('تسجيل التحصيل'));
    expect(find.textContaining('المبلغ أكبر من المتبقي'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '50');
    await tapVisible(tester, find.text('تسجيل التحصيل'));

    expect(find.text('تفاصيل الخدمة'), findsOneWidget);
    expect(find.text('محصّل جزئياً'), findsOneWidget);
    await scrollDetailsTo(tester, find.textContaining('150.00'));
    expect(find.textContaining('150.00'), findsOneWidget);
  });

  appTest('سجل التحصيلات وحذف دفعة', (tester, app) async {
    final serviceId = await seedService(app);
    await CollectionsRepository(app.db).create(CollectionInput(
      serviceId: serviceId,
      amount: Money.tryParse('50')!,
      date: DateTime(2026, 10, 22),
      method: PaymentMethod.transfer,
      reference: 'حوالة 123',
    ));
    await unlock(tester, app);
    await tapVisible(tester, find.text('الخدمات'));
    await tapVisible(tester, find.text('تركيب 5 نقاط شبكة'));
    await scrollDetailsTo(tester, find.text('سجل التحصيلات'));
    await tapVisible(tester, find.text('سجل التحصيلات'));

    expect(find.textContaining('تحويل'), findsOneWidget);
    expect(find.textContaining('حوالة 123'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('خيارات الدفعة'));
    await tapVisible(tester, find.text('حذف'));
    await tapVisible(tester, find.widgetWithText(TextButton, 'حذف'));
    expect(find.text('لا توجد دفعات بعد'), findsOneWidget);
  });

  appTest('تعديل يجعل المستحق أقل من المحصّل يُمنع مع شرح', (tester, app) async {
    final serviceId = await seedService(app);
    await CollectionsRepository(app.db).create(CollectionInput(
      serviceId: serviceId,
      amount: Money.tryParse('200')!,
      date: DateTime(2026, 10, 22),
      method: PaymentMethod.cash,
    ));
    await unlock(tester, app);
    await tapVisible(tester, find.text('الخدمات'));
    await tapVisible(tester, find.text('تركيب 5 نقاط شبكة'));
    expect(find.text('محصّل بالكامل'), findsOneWidget);
    await scrollDetailsTo(tester, find.text('تعديل الخدمة'));
    await tapVisible(tester, find.text('تعديل الخدمة'));

    await tester.enterText(find.byType(TextFormField).at(1), '500');
    await tester.pump();
    expect(find.textContaining('عدّل الدفعات أولاً'), findsOneWidget);
    await tapVisible(tester, find.text('حفظ الخدمة'));
    expect(find.text('تعديل الخدمة'), findsOneWidget); // لم يُحفظ ولم يُغلق.
    expect((await ServicesRepository(app.db).get(serviceId))!.commissionMinor, 20000);

    await tester.enterText(find.byType(TextFormField).at(1), '1500');
    await tester.pump();
    expect(find.textContaining('سيتغير المستحق والمتبقي'), findsOneWidget);
    await tapVisible(tester, find.text('حفظ الخدمة'));
    expect((await ServicesRepository(app.db).get(serviceId))!.commissionMinor, 30000);
  });

  appTest('إضافة خدمة من تفاصيل العميل بعميل محدد مسبقاً', (tester, app) async {
    final client = await ClientsRepository(app.db).create(const ClientInput(name: 'مؤسسة النور'));
    await unlock(tester, app);
    await tapVisible(tester, find.text('العملاء'));
    await tapVisible(tester, find.text('مؤسسة النور'));
    await tester.scrollUntilVisible(find.text('إضافة خدمة لهذا العميل'), 200, scrollable: find.byType(Scrollable).last);
    await tapVisible(tester, find.text('إضافة خدمة لهذا العميل'));

    expect(find.text('إضافة خدمة جديدة'), findsOneWidget);
    expect(find.text('مؤسسة النور'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'مثال: تركيب 5 نقاط شبكة'), 'تدريب');
    await tester.enterText(find.byType(TextFormField).at(1), '500');
    await tapVisible(tester, find.text('حفظ الخدمة'));
    final saved = await ServicesRepository(app.db).watchForClient(client).first;
    expect(saved.single.service.commissionMinor, 10000);
  });

  appTest('حذف خدمة لها دفعات يذكر عددها', (tester, app) async {
    final serviceId = await seedService(app);
    final repo = CollectionsRepository(app.db);
    for (final amount in ['20', '30']) {
      await repo.create(CollectionInput(
        serviceId: serviceId,
        amount: Money.tryParse(amount)!,
        date: DateTime(2026, 10, 22),
        method: PaymentMethod.cash,
      ));
    }
    await unlock(tester, app);
    await tapVisible(tester, find.text('الخدمات'));
    await tapVisible(tester, find.text('تركيب 5 نقاط شبكة'));
    await tapVisible(tester, find.byTooltip('خيارات'));
    await tapVisible(tester, find.text('حذف الخدمة'));
    expect(find.textContaining('و2 دفعات مرتبطة بها'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(TextButton, 'حذف'));
    expect(find.text('لا توجد خدمات بعد'), findsOneWidget);
    expect(await app.db.select(app.db.collections).get(), isEmpty);
  });
}
