import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/money.dart';
import '../../collections/domain/collection_models.dart';
import '../../profile/data/profile_repository.dart';
import '../../reports/export/report_document.dart';
import '../../reports/export/report_exporters.dart';

/// إصدار صيغة ملف النسخة؛ يُرفع عند تغيير بنية `data.json`.
const backupFormatVersion = 1;

/// ملخص نسخة احتياطية يُعرض قبل الاستعادة (القسم 14.2).
class BackupInfo {
  const BackupInfo({required this.createdAt, required this.appVersion, required this.schemaVersion, required this.counts});

  final DateTime createdAt;
  final String appVersion;
  final int schemaVersion;
  final Map<String, int> counts;

  int count(String table) => counts[table] ?? 0;
}

/// الملف ليس نسخة صالحة؛ [message] يُعرض للمستخدم.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

class _Parsed {
  const _Parsed(this.info, this.data, this.photo);

  final BackupInfo info;
  final Map<String, dynamic> data;
  final Uint8List? photo;
}

/// النسخ الاحتياطي والاستعادة والتصدير الكامل (القسم 14).
///
/// الملف `.nisbati` أرشيف ZIP فيه `manifest.json` و`data.json` وصورة الملف
/// الشخصي. لا يحوي أي شيء من التخزين الآمن (الرمز، رمز الاسترداد، البصمة).
class BackupService {
  BackupService(
    this._db,
    this._profiles, {
    DateTime Function()? clock,
    Future<Directory> Function()? documentsDirectory,
    this.appVersion = '1.0.0',
  })  : _clock = clock ?? DateTime.now,
        _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final AppDatabase _db;
  final ProfileRepository _profiles;
  final DateTime Function() _clock;
  final Future<Directory> Function() _documentsDirectory;
  final String appVersion;

  /// إعدادات خاصة بهذا الجهاز لا تُنقل مع النسخة.
  static const _deviceSettings = {SettingKeys.onboardingStep, SettingKeys.lastBackupAt};

  static const tables = ['user_profiles', 'clients', 'service_types', 'services', 'collections', 'app_settings'];

  /// يبني ملف النسخة الاحتياطية.
  Future<Uint8List> create() async {
    final settings = await _db.select(_db.appSettings).get();
    final data = <String, List<Map<String, dynamic>>>{
      'user_profiles': [for (final r in await _db.select(_db.userProfiles).get()) r.toJson()],
      'clients': [for (final r in await _db.select(_db.clients).get()) r.toJson()],
      'service_types': [for (final r in await _db.select(_db.serviceTypes).get()) r.toJson()],
      'services': [for (final r in await _db.select(_db.services).get()) r.toJson()],
      'collections': [for (final r in await _db.select(_db.collections).get()) r.toJson()],
      'app_settings': [
        for (final s in settings)
          if (!_deviceSettings.contains(s.key)) s.toJson(),
      ],
    };
    final dataBytes = utf8.encode(jsonEncode(data));
    final manifest = {
      'format': backupFormatVersion,
      'app': 'nisbati',
      'app_version': appVersion,
      'schema_version': _db.schemaVersion,
      'created_at': _clock().toIso8601String(),
      'counts': {for (final e in data.entries) e.key: e.value.length},
      'sha256': sha256.convert(dataBytes).toString(),
    };

    final archive = Archive()
      ..add(ArchiveFile.string('manifest.json', jsonEncode(manifest)))
      ..add(ArchiveFile.bytes('data.json', dataBytes));
    final photo = await _profiles.photoFile((await _profiles.get())?.photoPath);
    if (photo != null) archive.add(ArchiveFile.bytes('photo.jpg', await photo.readAsBytes()));
    return ZipEncoder().encodeBytes(archive);
  }

  /// اسم الملف: `نسبتي_نسخة_2026-10-25_1430.nisbati`.
  String fileName() {
    final now = _clock();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'نسبتي_نسخة_${DateFormatter.toStorage(now)}_${two(now.hour)}${two(now.minute)}.nisbati';
  }

  /// يتحقق من الملف ويعيد ملخصه، أو يرمي [BackupFormatException].
  BackupInfo inspect(Uint8List bytes) => _parse(bytes).info;

  /// يستبدل كل البيانات بمحتوى النسخة في معاملة واحدة (القسم 14.2).
  /// عند أي خطأ تبقى البيانات الحالية كما هي.
  Future<void> restore(Uint8List bytes) async {
    final parsed = _parse(bytes);
    List<Map<String, dynamic>> rows(String table) =>
        (parsed.data[table] as List? ?? const []).cast<Map<String, dynamic>>();

    await _db.transaction(() async {
      for (final TableInfo table in [
        _db.collections,
        _db.services,
        _db.clients,
        _db.serviceTypes,
        _db.userProfiles,
      ]) {
        await _db.delete(table).go();
      }
      await (_db.delete(_db.appSettings)..where((s) => s.key.isNotIn(_deviceSettings))).go();

      await _db.batch((b) {
        b.insertAll(_db.userProfiles, [for (final r in rows('user_profiles')) UserProfile.fromJson(r).copyWith(photoPath: const Value(null))]);
        b.insertAll(_db.clients, [for (final r in rows('clients')) Client.fromJson(r)]);
        b.insertAll(_db.serviceTypes, [for (final r in rows('service_types')) ServiceType.fromJson(r)]);
        b.insertAll(_db.services, [for (final r in rows('services')) ServiceRecord.fromJson(r)]);
        b.insertAll(_db.collections, [for (final r in rows('collections')) CollectionEntry.fromJson(r)]);
        b.insertAll(
          _db.appSettings,
          [
            for (final MapEntry(:key, :value) in SettingKeys.defaults.entries)
              AppSettingsCompanion.insert(key: key, value: value),
            for (final r in rows('app_settings'))
              if (!_deviceSettings.contains(r['key'])) AppSetting.fromJson(r).toCompanion(false),
          ],
          mode: InsertMode.insertOrReplace,
        );
      });
      await _db.into(_db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: SettingKeys.onboardingStep, value: 'done'),
          );
    });

    // الصورة بعد نجاح المعاملة.
    await _profiles.deleteAllPhotos();
    if (parsed.photo != null && rows('user_profiles').isNotEmpty) {
      final temp = File('${(await _documentsDirectory()).path}/restore_photo.jpg');
      await temp.writeAsBytes(parsed.photo!, flush: true);
      await _profiles.setPhoto(temp, touch: false);
      await temp.delete();
    }
  }

  /// نسخة تلقائية من البيانات الحالية قبل الاستعادة (للتراجع)؛ تُحفظ آخر 3 فقط.
  Future<File> saveSafetyCopy() async {
    final folder = Directory('${(await _documentsDirectory()).path}/backups');
    await folder.create(recursive: true);
    final file = File('${folder.path}/before_restore_${_clock().millisecondsSinceEpoch}.nisbati');
    await file.writeAsBytes(await create(), flush: true);
    final copies = folder.listSync().whereType<File>().where((f) => f.path.contains('before_restore_')).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in copies.skip(3)) {
      await old.delete();
    }
    return file;
  }

  Future<void> markBackedUp() => _db.into(_db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: SettingKeys.lastBackupAt, value: _clock().toIso8601String()),
      );

  /// تصدير كل البيانات: ملف CSV لكل جدول داخل ZIP، بمبالغ عشرية مقروءة (القسم 14.3).
  Future<Uint8List> exportCsv() async {
    final clients = {for (final c in await _db.select(_db.clients).get()) c.id: c};
    final types = {for (final t in await _db.select(_db.serviceTypes).get()) t.id: t};
    final services = await _db.select(_db.services).get();
    final byId = {for (final s in services) s.id: s};
    final collections = await _db.select(_db.collections).get();
    String n(int minor) => CurrencyFormatter.number(Money(minor));

    ReportDocument table(String title, List<String> columns, List<List<String>> rows) => ReportDocument(
          title: title,
          slug: title,
          periodLabel: '',
          filtersLabel: '',
          generatedAt: _clock(),
          summary: const [],
          columns: columns,
          rows: rows,
        );

    final files = {
      'clients.csv': table('العملاء', ['المعرف', 'الاسم', 'الهاتف', 'جهة الاتصال', 'العنوان', 'ملاحظات', 'مؤرشف'], [
        for (final c in clients.values)
          ['${c.id}', c.name, c.phone ?? '', c.contactName ?? '', c.address ?? '', c.notes ?? '', c.isArchived ? 'نعم' : 'لا'],
      ]),
      'services.csv': table('الخدمات', [
        'المعرف',
        'التاريخ',
        'العميل',
        'النوع',
        'العنوان',
        'قيمة الخدمة',
        'النسبة %',
        'مستحقاتي',
        'تفاصيل العمل',
      ], [
        for (final s in services)
          [
            '${s.id}',
            s.serviceDate,
            clients[s.clientId]?.name ?? '',
            types[s.serviceTypeId]?.name ?? '',
            s.title,
            n(s.serviceValueMinor),
            Percent(s.commissionBp).toPlainString(),
            n(s.commissionMinor),
            s.description ?? '',
          ],
      ]),
      'collections.csv': table('التحصيلات', ['المعرف', 'التاريخ', 'الخدمة', 'العميل', 'المبلغ', 'الطريقة', 'المرجع'], [
        for (final c in collections)
          [
            '${c.id}',
            c.collectionDate,
            byId[c.serviceId]?.title ?? '',
            clients[byId[c.serviceId]?.clientId]?.name ?? '',
            n(c.amountMinor),
            c.paymentMethod.label,
            c.reference ?? '',
          ],
      ]),
    };
    final archive = Archive();
    for (final MapEntry(:key, :value) in files.entries) {
      archive.add(ArchiveFile.bytes(key, CsvExporter.build(value)));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  String exportFileName() => 'نسبتي_بيانات_${DateFormatter.toStorage(_clock())}.zip';

  _Parsed _parse(Uint8List bytes) {
    const invalid = BackupFormatException('الملف ليس نسخة احتياطية من تطبيق نسبتي');
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw invalid;
    }
    final manifestFile = archive.findFile('manifest.json');
    final dataFile = archive.findFile('data.json');
    if (manifestFile == null || dataFile == null) throw invalid;

    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
    } catch (_) {
      throw invalid;
    }
    if (manifest['app'] != 'nisbati' || manifest['format'] is! int) throw invalid;
    if ((manifest['format'] as int) > backupFormatVersion ||
        (manifest['schema_version'] as int? ?? 0) > _db.schemaVersion) {
      throw const BackupFormatException('النسخة من إصدار أحدث من التطبيق. حدّث التطبيق ثم أعد المحاولة.');
    }

    final dataBytes = dataFile.content;
    if (sha256.convert(dataBytes).toString() != manifest['sha256']) {
      throw const BackupFormatException('الملف تالف أو معدّل، ولا يمكن استعادته.');
    }
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(dataBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupFormatException('الملف تالف أو معدّل، ولا يمكن استعادته.');
    }

    final counts = (manifest['counts'] as Map<String, dynamic>? ?? const {}).map((k, v) => MapEntry(k, v as int));
    for (final table in tables) {
      if ((data[table] as List?)?.length != counts[table]) {
        throw const BackupFormatException('الملف تالف أو ناقص، ولا يمكن استعادته.');
      }
    }
    final info = BackupInfo(
      createdAt: DateTime.tryParse(manifest['created_at'] as String? ?? '') ?? DateTime(2000),
      appVersion: manifest['app_version'] as String? ?? '',
      schemaVersion: manifest['schema_version'] as int? ?? 0,
      counts: counts,
    );
    return _Parsed(info, data, archive.findFile('photo.jpg')?.content);
  }
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(appDatabaseProvider), ref.watch(profileRepositoryProvider)),
);
