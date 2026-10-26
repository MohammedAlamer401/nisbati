import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/database/app_database.dart';
import 'package:nisbati/features/settings/data/settings_repository.dart';

import 'helpers/test_app.dart';
import 'reports_flow_test.dart' show seedThisMonth, unlock;

void main() {
  appTest('تذكير النسخ في الرئيسية يفتح شاشة النسخ، وإيقافه يخفيه', (tester, app) async {
    await seedThisMonth(app);
    await unlock(tester, app);

    expect(find.text('لم تُنشئ نسخة احتياطية بعد'), findsOneWidget);
    await tapVisible(tester, find.text('إنشاء نسخة'));

    expect(find.text('النسخ الاحتياطي'), findsOneWidget);
    expect(find.text('إنشاء نسخة احتياطية'), findsOneWidget);
    expect(find.text('استعادة نسخة احتياطية'), findsOneWidget);
    expect(find.text('تصدير كل البيانات (CSV)'), findsOneWidget);

    await tapVisible(tester, find.text('إيقاف'));
    expect(await SettingsRepository(app.db).read(SettingKeys.backupReminderDays), '0');
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('لم تُنشئ نسخة احتياطية بعد'), findsNothing);
  });

  appTest('بلا خدمات لا يظهر التذكير، وتاريخ آخر نسخة يظهر في الإعدادات', (tester, app) async {
    await SettingsRepository(app.db).write(SettingKeys.lastBackupAt, DateTime(2026, 10, 20).toIso8601String());
    await unlock(tester, app);
    expect(find.text('لم تُنشئ نسخة احتياطية بعد'), findsNothing);

    await tapVisible(tester, find.text('الإعدادات'));
    await tester.scrollUntilVisible(find.text('النسخ الاحتياطي والاستعادة'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('آخر نسخة: 20/10/2026'), findsOneWidget);
  });
}
