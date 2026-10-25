import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/features/clients/data/clients_repository.dart';
import 'package:nisbati/features/clients/domain/client_models.dart';
import 'package:nisbati/features/clients/presentation/client_details_screen.dart';

import 'helpers/test_app.dart';

Future<void> openClients(WidgetTester tester, TestApp app) async {
  await app.seedExistingUser();
  await app.pump(tester);
  await enterPin(tester, '482915');
  await tapVisible(tester, find.text('العملاء'));
}

Future<void> fillAndSave(WidgetTester tester, {required String name, String? phone}) async {
  await tester.enterText(find.byType(TextFormField).at(0), name);
  if (phone != null) await tester.enterText(find.byType(TextFormField).at(1), phone);
  await tapVisible(tester, find.text('حفظ العميل'));
}

void main() {
  appTest('القائمة الفارغة ثم إضافة عميل وفتح تفاصيله', (tester, app) async {
    await openClients(tester, app);
    expect(find.text('لا يوجد عملاء بعد'), findsOneWidget);

    await tapVisible(tester, find.byType(FloatingActionButton));
    expect(find.text('إضافة عميل'), findsWidgets);

    // الاسم مطلوب والهاتف يُتحقق منه.
    await tapVisible(tester, find.text('حفظ العميل'));
    expect(find.text('الاسم مطلوب'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), '12ab');
    await tapVisible(tester, find.text('حفظ العميل'));
    expect(find.text('رقم هاتف غير صالح'), findsOneWidget);

    await fillAndSave(tester, name: 'مصنع هابي', phone: '٠٩١٢٣٤٥٦٧٨');
    expect(find.text('مصنع هابي'), findsOneWidget);
    expect(find.textContaining('لا خدمات', findRichText: true), findsOneWidget);

    await tapVisible(tester, find.text('مصنع هابي'));
    expect(find.text('تفاصيل العميل'), findsOneWidget);
    expect(find.text('اتصال'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('لا توجد خدمات لهذا العميل'),
      200,
      scrollable: find.descendant(of: find.byType(ClientDetailsScreen), matching: find.byType(Scrollable)).first,
    );
    expect(find.text('لا توجد خدمات لهذا العميل'), findsOneWidget);
  });

  appTest('تنبيه الاسم المكرر غير مانع', (tester, app) async {
    await ClientsRepository(app.db).create(const ClientInput(name: 'مؤسسة أحمد'));
    await openClients(tester, app);
    await tapVisible(tester, find.byType(FloatingActionButton));
    await fillAndSave(tester, name: 'موسسه احمد');

    expect(find.text('يوجد عميل بهذا الاسم. هل تريد المتابعة؟'), findsOneWidget);
    await tapVisible(tester, find.text('متابعة الحفظ'));
    expect(await ClientsRepository(app.db).watchClients((query: 'احمد', archived: false)).first, hasLength(2));
  });

  appTest('البحث يصفّي القائمة، ورسالة عند عدم وجود نتائج', (tester, app) async {
    final repo = ClientsRepository(app.db);
    await repo.create(const ClientInput(name: 'أحمد للتقنية'));
    await repo.create(const ClientInput(name: 'مصنع هابي'));
    await openClients(tester, app);
    expect(find.text('أحمد للتقنية'), findsOneWidget);
    expect(find.text('مصنع هابي'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'احمد');
    await settle(tester);
    expect(find.text('أحمد للتقنية'), findsOneWidget);
    expect(find.text('مصنع هابي'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'غير موجود');
    await settle(tester);
    expect(find.text('لم نعثر على عميل بهذا الاسم'), findsOneWidget);
  });

  appTest('الأرشفة من التفاصيل تنقل العميل إلى المؤرشفين، والحذف متاح بلا خدمات', (tester, app) async {
    await ClientsRepository(app.db).create(const ClientInput(name: 'مصنع هابي'));
    await openClients(tester, app);

    await tapVisible(tester, find.text('مصنع هابي'));
    await tapVisible(tester, find.byTooltip('خيارات'));
    await tapVisible(tester, find.text('أرشفة العميل'));
    expect(find.text('مؤرشف'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('لا يوجد عملاء بعد'), findsOneWidget);
    await tapVisible(tester, find.text('المؤرشفون'));
    expect(find.text('مصنع هابي'), findsOneWidget);

    await tapVisible(tester, find.text('مصنع هابي'));
    await tapVisible(tester, find.byTooltip('خيارات'));
    await tapVisible(tester, find.text('حذف العميل'));
    await tapVisible(tester, find.widgetWithText(TextButton, 'حذف'));
    expect(find.text('لا يوجد عملاء مؤرشفون'), findsOneWidget);
  });

  appTest('تعديل العميل يحدّث التفاصيل والقائمة', (tester, app) async {
    await ClientsRepository(app.db).create(const ClientInput(name: 'مصنع هابي'));
    await openClients(tester, app);

    await tapVisible(tester, find.text('مصنع هابي'));
    await tapVisible(tester, find.text('تعديل'));
    expect(find.text('تعديل العميل'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'مصنع إشراق');
    await tester.enterText(find.byType(TextFormField).at(3), 'طرابلس');
    await tapVisible(tester, find.text('حفظ العميل'));

    expect(find.text('مصنع إشراق'), findsOneWidget);
    expect(find.text('طرابلس'), findsOneWidget);
  });
}
