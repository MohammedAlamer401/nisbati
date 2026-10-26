import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/database/app_database.dart';
import 'package:nisbati/core/formatting/date_formatter.dart';
import 'package:nisbati/core/money/money.dart';
import 'package:nisbati/features/clients/data/clients_repository.dart';
import 'package:nisbati/features/clients/domain/client_models.dart';
import 'package:nisbati/features/collections/data/collections_repository.dart';
import 'package:nisbati/features/collections/domain/collection_models.dart';
import 'package:nisbati/features/services/data/services_repository.dart';
import 'package:nisbati/features/services/domain/service_models.dart';

import 'helpers/test_app.dart';

/// خدمة هذا الشهر بقيمة 1,000 ونسبة 20% (مستحق 200) وتحصيل 50.
Future<void> seedThisMonth(TestApp app) async {
  final client = await ClientsRepository(app.db).create(const ClientInput(name: 'مصنع هابي'));
  final today = DateFormatter.today();
  final id = await ServicesRepository(app.db).create(ServiceInput(
    clientId: client,
    serviceTypeId: 1,
    title: 'تركيب 5 نقاط شبكة',
    serviceDate: today,
    value: Money.tryParse('1000')!,
    percent: Percent.tryParse('20')!,
  ));
  await CollectionsRepository(app.db).create(CollectionInput(
    serviceId: id,
    amount: Money.tryParse('50')!,
    date: today,
    method: PaymentMethod.cash,
  ));
}

Future<void> unlock(WidgetTester tester, TestApp app) async {
  await app.seedExistingUser();
  await app.pump(tester);
  await enterPin(tester, '482915');
}

void main() {
  appTest('الرئيسية: مؤشرات الفترة، وغير المحصّل، وآخر الخدمات', (tester, app) async {
    await seedThisMonth(app);
    await unlock(tester, app);

    expect(find.textContaining('200.00'), findsWidgets);
    expect(find.text('خدمة واحدة في هذه الفترة'), findsOneWidget);
    expect(find.text('غير محصّل حتى الآن'), findsOneWidget);
    expect(find.textContaining('150.00'), findsWidgets);
    await tester.scrollUntilVisible(find.text('المستحقات حسب الشهر'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('المستحقات حسب الشهر'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('آخر الخدمات'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('تركيب 5 نقاط شبكة'), findsOneWidget);
  });

  appTest('«غير محصّل حتى الآن» يفتح الخدمات مفلترة', (tester, app) async {
    await seedThisMonth(app);
    await unlock(tester, app);
    await tapVisible(tester, find.text('غير محصّل حتى الآن'));
    expect(find.textContaining('غير المحصّل فقط'), findsOneWidget);
    expect(find.text('تركيب 5 نقاط شبكة'), findsOneWidget);
  });

  appTest('التقارير: الملخص، والتبديل بين الأنواع، وتأكيد التصدير', (tester, app) async {
    await seedThisMonth(app);
    await unlock(tester, app);
    await tapVisible(tester, find.text('التقارير'));

    expect(find.text('المحصّل منها'), findsOneWidget);
    expect(find.textContaining('1,000.00'), findsWidgets);
    expect(find.text(DateFormatter.monthYear(DateFormatter.today())), findsOneWidget);

    await tapVisible(tester, find.text('حسب العميل'));
    expect(find.text('مصنع هابي'), findsOneWidget);

    await tapVisible(tester, find.text('التحصيلات'));
    expect(find.text('المقبوضات خلال الفترة'), findsOneWidget);
    expect(find.textContaining('50.00'), findsWidgets);

    await tapVisible(tester, find.byTooltip('تصدير'));
    expect(find.text('تصدير التقرير'), findsOneWidget);
    expect(find.text('PDF للطباعة والمشاركة'), findsOneWidget);
    expect(find.text('بلا فلاتر'), findsOneWidget);
  });

  appTest('الرئيسية الفارغة تعرض «أضف أول خدمة» دون رسم بياني', (tester, app) async {
    await unlock(tester, app);
    expect(find.text('لا توجد خدمات بعد'), findsOneWidget);
    expect(find.text('المستحقات حسب الشهر'), findsNothing);
    expect(find.text('لا مستحقات غير محصّلة'), findsOneWidget);
  });
}
