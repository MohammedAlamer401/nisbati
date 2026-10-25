import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// مفاتيح جدول الإعدادات وقيمها الافتراضية (القسم 7.6).
abstract final class SettingKeys {
  static const currencySymbol = 'currency_symbol';
  static const defaultCommissionBp = 'default_commission_bp';
  static const autoLockSeconds = 'auto_lock_seconds';
  static const secureScreen = 'secure_screen';
  static const lastBackupAt = 'last_backup_at';
  static const backupReminderDays = 'backup_reminder_days';
  static const onboardingStep = 'onboarding_step';

  static const defaults = {
    currencySymbol: 'د.ل',
    defaultCommissionBp: '2000',
    autoLockSeconds: '60',
    secureScreen: 'false',
    backupReminderDays: '7',
  };
}

/// أنواع الخدمات الافتراضية؛ الأخير «أخرى» نوع نظامي.
const defaultServiceTypes = [
  'تركيب شبكة',
  'تركيب كاميرات',
  'تدريب',
  'عرض تطبيق',
  'صيانة',
  'أخرى',
];

@DriftDatabase(
  tables: [UserProfiles, Clients, ServiceTypes, Services, Collections, AppSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'nisbati'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// يمسح كل البيانات ويعيد البذور الافتراضية (المسح الكامل — القسم 6.6).
  Future<void> resetToDefaults() => transaction(() async {
        for (final TableInfo table in [collections, services, clients, serviceTypes, userProfiles, appSettings]) {
          await delete(table).go();
        }
        await _seed();
      });

  Future<void> _seed() async {
    await batch((b) {
      b.insertAll(serviceTypes, [
        for (final (i, name) in defaultServiceTypes.indexed)
          ServiceTypesCompanion.insert(
            name: name,
            sortOrder: Value(i),
            isSystem: Value(name == defaultServiceTypes.last),
          ),
      ]);
      b.insertAll(appSettings, [
        for (final MapEntry(:key, :value) in SettingKeys.defaults.entries)
          AppSettingsCompanion.insert(key: key, value: value),
      ]);
    });
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
