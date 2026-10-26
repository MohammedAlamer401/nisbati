import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';

/// الإعدادات العامة من جدول `app_settings` (القسم 7.6).
class AppPreferences {
  const AppPreferences({
    required this.currencySymbol,
    required this.defaultCommission,
    required this.autoLock,
    this.lastBackupAt,
    this.backupReminderDays = 7,
  });

  factory AppPreferences.fromMap(Map<String, String> map) {
    String value(String key) => map[key] ?? SettingKeys.defaults[key]!;
    return AppPreferences(
      currencySymbol: value(SettingKeys.currencySymbol),
      defaultCommission: Percent(int.tryParse(value(SettingKeys.defaultCommissionBp)) ?? 2000),
      autoLock: Duration(seconds: int.tryParse(value(SettingKeys.autoLockSeconds)) ?? 60),
      lastBackupAt: DateTime.tryParse(map[SettingKeys.lastBackupAt] ?? ''),
      backupReminderDays: int.tryParse(value(SettingKeys.backupReminderDays)) ?? 7,
    );
  }

  final String currencySymbol;
  final Percent defaultCommission;
  final Duration autoLock;
  final DateTime? lastBackupAt;

  /// كل كم يوماً يُذكَّر المستخدم بالنسخ الاحتياطي؛ 0 = إيقاف.
  final int backupReminderDays;

  /// عدد الأيام منذ آخر نسخة إن حان التذكير (−1 إن لم تُنشأ نسخة قط)، وإلا `null` (القسم 14.4).
  int? backupReminderDue(DateTime now, {required bool hasData}) {
    if (backupReminderDays <= 0 || !hasData) return null;
    final last = lastBackupAt;
    if (last == null) return -1;
    final days = now.difference(last).inDays;
    return days >= backupReminderDays ? days : null;
  }
}

/// خيارات تذكير النسخ الاحتياطي.
const backupReminderOptions = [
  (0, 'إيقاف'),
  (7, 'أسبوع'),
  (14, 'أسبوعان'),
  (30, 'شهر'),
];

/// خيارات مهلة القفل التلقائي (القسم 6.4).
const autoLockOptions = [
  (Duration.zero, 'فوراً'),
  (Duration(minutes: 1), 'بعد دقيقة'),
  (Duration(minutes: 5), 'بعد 5 دقائق'),
  (Duration(minutes: 15), 'بعد 15 دقيقة'),
];

String autoLockLabel(Duration duration) =>
    autoLockOptions.firstWhere((o) => o.$1 == duration, orElse: () => autoLockOptions[1]).$2;

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<String?> read(String key) async {
    final row = await (_db.select(_db.appSettings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) =>
      _db.into(_db.appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));

  Stream<AppPreferences> watchPreferences() => _db.select(_db.appSettings).watch().map(
        (rows) => AppPreferences.fromMap({for (final r in rows) r.key: r.value}),
      );

  Future<AppPreferences> preferences() async {
    final rows = await _db.select(_db.appSettings).get();
    return AppPreferences.fromMap({for (final r in rows) r.key: r.value});
  }

  Future<void> setCurrencySymbol(String symbol) => write(SettingKeys.currencySymbol, symbol.trim());

  Future<void> setDefaultCommission(Percent percent) =>
      write(SettingKeys.defaultCommissionBp, '${percent.bp}');

  Future<void> setAutoLock(Duration duration) =>
      write(SettingKeys.autoLockSeconds, '${duration.inSeconds}');

  Future<void> setBackupReminderDays(int days) => write(SettingKeys.backupReminderDays, '$days');
}

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository(ref.watch(appDatabaseProvider)));

final preferencesProvider = StreamProvider<AppPreferences>(
  (ref) => ref.watch(settingsRepositoryProvider).watchPreferences(),
);

/// رمز العملة الحالي لعرض المبالغ.
final currencySymbolProvider = Provider<String>(
  (ref) => ref.watch(preferencesProvider).value?.currencySymbol ?? SettingKeys.defaults[SettingKeys.currencySymbol]!,
);
