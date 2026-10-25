import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/database/app_database.dart';
import 'package:nisbati/features/profile/data/profile_repository.dart';
import 'package:nisbati/features/profile/domain/profile_validators.dart';

void main() {
  group('ProfileValidators', () {
    test('الاسم', () {
      expect(ProfileValidators.fullName(''), isNotNull);
      expect(ProfileValidators.fullName('  أ '), isNotNull);
      expect(ProfileValidators.fullName('أحمد محمد'), isNull);
      expect(ProfileValidators.fullName('أ' * 61), isNotNull);
    });

    test('الهاتف اختياري ويقبل الأرقام الهندية والمسافات', () {
      expect(ProfileValidators.phone(''), isNull);
      expect(ProfileValidators.phone('091 234 5678'), isNull);
      expect(ProfileValidators.phone('+218912345678'), isNull);
      expect(ProfileValidators.phone('٠٩١٢٣٤٥٦٧٨'), isNull);
      expect(ProfileValidators.phone('12ab'), isNotNull);
      expect(ProfileValidators.normalizePhone('٠٩١-٢٣٤ ٥٦٧٨'), '0912345678');
    });

    test('البريد اختياري', () {
      expect(ProfileValidators.email(''), isNull);
      expect(ProfileValidators.email('a@b.ly'), isNull);
      expect(ProfileValidators.email('not-an-email'), isNotNull);
    });
  });

  group('ProfileRepository', () {
    late AppDatabase db;
    late ProfileRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = ProfileRepository(db);
    });
    tearDown(() => db.close());

    test('الحفظ يُنشئ صفاً واحداً ويحدّثه، والحقول الفارغة تصبح null', () async {
      await repo.save(const ProfileInput(fullName: ' أحمد محمد ', businessName: '', phone: '٠٩١ ٢٣٤ ٥٦٧٨'));
      var profile = await repo.get();
      expect(profile!.fullName, 'أحمد محمد');
      expect(profile.businessName, isNull);
      expect(profile.phone, '0912345678');

      await repo.save(const ProfileInput(fullName: 'أحمد علي', city: 'طرابلس'));
      profile = await repo.get();
      expect(profile!.fullName, 'أحمد علي');
      expect(profile.city, 'طرابلس');
      expect(await db.select(db.userProfiles).get(), hasLength(1));
    });

    test('المسح الكامل يعيد البذور ويحذف الملف', () async {
      await repo.save(const ProfileInput(fullName: 'أحمد محمد'));
      await db.resetToDefaults();
      expect(await repo.get(), isNull);
      expect(await db.select(db.serviceTypes).get(), hasLength(defaultServiceTypes.length));
      expect(await db.select(db.appSettings).get(), hasLength(SettingKeys.defaults.length));
    });
  });
}
