import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/database/app_database.dart';
import 'package:nisbati/core/money/money.dart';
import 'package:nisbati/features/backup/data/backup_service.dart';
import 'package:nisbati/features/clients/data/clients_repository.dart';
import 'package:nisbati/features/clients/domain/client_models.dart';
import 'package:nisbati/features/collections/data/collections_repository.dart';
import 'package:nisbati/features/collections/domain/collection_models.dart';
import 'package:nisbati/features/profile/data/profile_repository.dart';
import 'package:nisbati/features/services/data/services_repository.dart';
import 'package:nisbati/features/services/domain/service_models.dart';
import 'package:nisbati/features/settings/data/service_types_repository.dart';
import 'package:nisbati/features/settings/data/settings_repository.dart';

void main() {
  late Directory docs;
  late AppDatabase db;
  late ProfileRepository profiles;
  late BackupService backup;
  final now = DateTime(2026, 10, 26, 14, 30);

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('nisbati_backup_');
    db = AppDatabase(NativeDatabase.memory());
    profiles = ProfileRepository(db, documentsDirectory: () async => docs);
    backup = BackupService(db, profiles, clock: () => now, documentsDirectory: () async => docs);
  });
  tearDown(() async {
    await db.close();
    await docs.delete(recursive: true);
  });

  /// بيانات تغطي كل الجداول: ملف بصورة، عميل مؤرشف، نوع مضاف، خدمتان، دفعتان، إعدادات معدّلة.
  Future<void> seed() async {
    await profiles.save(const ProfileInput(fullName: 'أحمد محمد', businessName: 'فني شبكات', phone: '0912345678'));
    final photo = File('${docs.path}/source.jpg')..writeAsBytesSync(List.generate(300, (i) => i % 256));
    await profiles.setPhoto(photo);

    final clients = ClientsRepository(db);
    final happy = await clients.create(const ClientInput(name: 'مصنع هابي', phone: '0911111111', notes: 'عميل قديم'));
    final archived = await clients.create(const ClientInput(name: 'مؤسسة النور'));
    await clients.setArchived(archived, true);
    final custom = await ServiceTypesRepository(db).add('برمجة');

    final services = ServicesRepository(db);
    final first = await services.create(ServiceInput(
      clientId: happy,
      serviceTypeId: 1,
      title: 'تركيب 5 نقاط شبكة',
      serviceDate: DateTime(2026, 10, 20),
      value: Money.tryParse('1000')!,
      percent: Percent.tryParse('20')!,
      description: 'الطابق الأول',
    ));
    await services.create(ServiceInput(
      clientId: archived,
      serviceTypeId: custom,
      title: 'تطبيق مخازن',
      serviceDate: DateTime(2026, 9, 1),
      value: Money.tryParse('333.33')!,
      percent: Percent.tryParse('7.5')!,
    ));
    final collections = CollectionsRepository(db);
    for (final (amount, method) in [('50', PaymentMethod.cash), ('25.5', PaymentMethod.transfer)]) {
      await collections.create(CollectionInput(
        serviceId: first,
        amount: Money.tryParse(amount)!,
        date: DateTime(2026, 10, 22),
        method: method,
        reference: 'مرجع $amount',
      ));
    }
    final settings = SettingsRepository(db);
    await settings.setCurrencySymbol('\$');
    await settings.setDefaultCommission(Percent.tryParse('12.5')!);
    await settings.write(SettingKeys.onboardingStep, 'done');
  }

  Future<Map<String, List<Map<String, dynamic>>>> snapshot() async => {
        'profile': [for (final r in await db.select(db.userProfiles).get()) r.toJson()..remove('photoPath')],
        'clients': [for (final r in await db.select(db.clients).get()) r.toJson()],
        'types': [for (final r in await db.select(db.serviceTypes).get()) r.toJson()],
        'services': [for (final r in await db.select(db.services).get()) r.toJson()],
        'collections': [for (final r in await db.select(db.collections).get()) r.toJson()],
        'settings': [
          for (final r in await db.select(db.appSettings).get())
            if (r.key != SettingKeys.lastBackupAt) r.toJson(),
        ],
      };

  test('نسخ ثم استعادة يعيد كل البيانات والعلاقات والصورة كما هي (القسم 17.2)', () async {
    await seed();
    final before = await snapshot();
    final file = await backup.create();

    // تغييرات بعد النسخ ستُستبدل.
    await ClientsRepository(db).create(const ClientInput(name: 'عميل جديد بعد النسخة'));
    await profiles.removePhoto();
    await db.resetToDefaults();

    await backup.restore(file);
    expect(await snapshot(), before);

    final photo = await profiles.photoFile((await profiles.get())!.photoPath);
    expect(photo, isNotNull);
    expect(photo!.readAsBytesSync(), List.generate(300, (i) => i % 256));
  });

  test('الملخص والاسم، وإعدادات الجهاز لا تُنقل', () async {
    await seed();
    await backup.markBackedUp();
    final bytes = await backup.create();
    final info = backup.inspect(bytes);
    expect(info.createdAt, now);
    expect(info.count('clients'), 2);
    expect(info.count('services'), 2);
    expect(info.count('collections'), 2);
    expect(backup.fileName(), 'نسبتي_نسخة_2026-10-26_1430.nisbati');

    final data = jsonDecode(utf8.decode(ZipDecoder().decodeBytes(bytes).findFile('data.json')!.content));
    final keys = [for (final s in data['app_settings'] as List) s['key']];
    expect(keys, isNot(contains(SettingKeys.onboardingStep)));
    expect(keys, isNot(contains(SettingKeys.lastBackupAt)));
    // لا أسرار في الملف.
    expect(utf8.decode(ZipDecoder().decodeBytes(bytes).findFile('data.json')!.content), isNot(contains('pin')));
  });

  test('الاستعادة تبقي التطبيق مُعدّاً ولا تمسح تاريخ آخر نسخة على هذا الجهاز', () async {
    await seed();
    final file = await backup.create();
    await backup.markBackedUp();
    await db.resetToDefaults();
    await backup.restore(file);
    final settings = SettingsRepository(db);
    expect(await settings.read(SettingKeys.onboardingStep), 'done');
    expect((await settings.preferences()).currencySymbol, '\$');
  });

  group('رفض الملفات غير الصالحة (القسم 14.2)', () {
    late Uint8List valid;
    setUp(() async {
      await seed();
      valid = await backup.create();
    });

    Uint8List rebuild(void Function(Archive) change) {
      final archive = ZipDecoder().decodeBytes(valid);
      change(archive);
      return ZipEncoder().encodeBytes(archive);
    }

    Matcher rejects(String text) => throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', contains(text)));

    test('ليس ملف ZIP', () {
      expect(() => backup.inspect(Uint8List.fromList(utf8.encode('hello'))), rejects('ليس نسخة احتياطية'));
    });

    test('بيانات معدّلة لا تطابق البصمة', () {
      final tampered = rebuild((a) {
        final data = utf8.decode(a.findFile('data.json')!.content).replaceFirst('مصنع هابي', 'مصنع آخر');
        a.add(ArchiveFile.string('data.json', data));
      });
      expect(() => backup.inspect(tampered), rejects('تالف أو معدّل'));
    });

    test('نسخة من إصدار أحدث من التطبيق', () {
      final newer = rebuild((a) {
        final manifest = jsonDecode(utf8.decode(a.findFile('manifest.json')!.content)) as Map<String, dynamic>;
        manifest['schema_version'] = 99;
        a.add(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
      });
      expect(() => backup.inspect(newer), rejects('إصدار أحدث'));
    });

    test('الملف المرفوض لا يمس البيانات الحالية', () async {
      final before = await snapshot();
      await expectLater(backup.restore(Uint8List.fromList([1, 2, 3])), throwsA(isA<BackupFormatException>()));
      expect(await snapshot(), before);
    });
  });

  test('نسخة الأمان قبل الاستعادة تُحفظ، ويبقى آخر 3 فقط', () async {
    await seed();
    for (var i = 0; i < 5; i++) {
      final service = BackupService(db, profiles, clock: () => now.add(Duration(minutes: i)), documentsDirectory: () async => docs);
      await service.saveSafetyCopy();
    }
    final copies = Directory('${docs.path}/backups').listSync();
    expect(copies, hasLength(3));
  });

  test('التصدير الكامل: ثلاثة ملفات CSV بقيم مقروءة', () async {
    await seed();
    final zip = ZipDecoder().decodeBytes(await backup.exportCsv());
    expect(zip.files.map((f) => f.name), ['clients.csv', 'services.csv', 'collections.csv']);
    final services = utf8.decode(zip.findFile('services.csv')!.content.sublist(3));
    expect(services, contains('1,000.00'));
    expect(services, contains('7.5'));
    expect(services, contains('مصنع هابي'));
    final collections = utf8.decode(zip.findFile('collections.csv')!.content.sublist(3));
    expect(collections, contains('تحويل'));
    expect(backup.exportFileName(), 'نسبتي_بيانات_2026-10-26.zip');
  });

  group('تذكير النسخ الاحتياطي (القسم 14.4)', () {
    AppPreferences prefs({DateTime? last, int days = 7}) => AppPreferences.fromMap({
          if (last != null) SettingKeys.lastBackupAt: last.toIso8601String(),
          SettingKeys.backupReminderDays: '$days',
        });

    test('لا تذكير بلا بيانات أو عند الإيقاف', () {
      expect(prefs().backupReminderDue(now, hasData: false), isNull);
      expect(prefs(days: 0).backupReminderDue(now, hasData: true), isNull);
    });

    test('لم تُنشأ نسخة قط ← −1', () => expect(prefs().backupReminderDue(now, hasData: true), -1));

    test('بعد مرور المدة فقط', () {
      expect(prefs(last: now.subtract(const Duration(days: 6))).backupReminderDue(now, hasData: true), isNull);
      expect(prefs(last: now.subtract(const Duration(days: 12))).backupReminderDue(now, hasData: true), 12);
      expect(prefs(last: now.subtract(const Duration(days: 12)), days: 14).backupReminderDue(now, hasData: true), isNull);
    });
  });
}
