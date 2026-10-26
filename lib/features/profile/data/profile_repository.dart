import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../domain/profile_validators.dart';

/// بيانات نموذج الملف الشخصي قبل الحفظ.
class ProfileInput {
  const ProfileInput({
    required this.fullName,
    this.businessName,
    this.phone,
    this.email,
    this.city,
  });

  final String fullName;
  final String? businessName;
  final String? phone;
  final String? email;
  final String? city;
}

/// الملف الشخصي (صف واحد) وصورته المحفوظة داخل مجلد التطبيق — القسم 6.7.
class ProfileRepository {
  ProfileRepository(this._db, {Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final AppDatabase _db;
  final Future<Directory> Function() _documentsDirectory;

  static const _photoFolder = 'profile';

  SimpleSelectStatement<$UserProfilesTable, UserProfile> get _row =>
      _db.select(_db.userProfiles)..where((p) => p.id.equals(1));

  Future<UserProfile?> get() => _row.getSingleOrNull();

  Stream<UserProfile?> watch() => _row.watchSingleOrNull();

  Future<void> save(ProfileInput input) async {
    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    await _db.into(_db.userProfiles).insertOnConflictUpdate(UserProfilesCompanion(
          id: const Value(1),
          fullName: Value(input.fullName.trim()),
          businessName: Value(clean(input.businessName)),
          phone: Value(ProfileValidators.normalizePhone(input.phone)),
          email: Value(clean(input.email)),
          city: Value(clean(input.city)),
          updatedAt: Value(DateTime.now()),
        ));
  }

  /// ينسخ الصورة المختارة إلى مجلد التطبيق ويحذف السابقة.
  /// [touch] يحدّث تاريخ التعديل؛ الاستعادة تمرّر `false` لتبقى البيانات كما في النسخة.
  Future<void> setPhoto(File source, {bool touch = true}) async {
    final docs = await _documentsDirectory();
    final folder = Directory('${docs.path}/$_photoFolder');
    await folder.create(recursive: true);
    final relative = '$_photoFolder/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await source.copy('${docs.path}/$relative');
    final previous = (await get())?.photoPath;
    await (_db.update(_db.userProfiles)..where((p) => p.id.equals(1))).write(UserProfilesCompanion(
      photoPath: Value(relative),
      updatedAt: touch ? Value(DateTime.now()) : const Value.absent(),
    ));
    await _deleteFile(previous);
  }

  Future<void> removePhoto() async {
    final previous = (await get())?.photoPath;
    await (_db.update(_db.userProfiles)..where((p) => p.id.equals(1)))
        .write(UserProfilesCompanion(photoPath: const Value(null), updatedAt: Value(DateTime.now())));
    await _deleteFile(previous);
  }

  Future<File?> photoFile(String? relative) async {
    if (relative == null) return null;
    final file = File('${(await _documentsDirectory()).path}/$relative');
    return await file.exists() ? file : null;
  }

  /// يحذف مجلد الصور كاملاً (عند المسح الكامل).
  Future<void> deleteAllPhotos() async {
    final folder = Directory('${(await _documentsDirectory()).path}/$_photoFolder');
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  Future<void> _deleteFile(String? relative) async {
    final file = await photoFile(relative);
    if (file != null) await file.delete();
  }
}

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(appDatabaseProvider)));

final profileProvider = StreamProvider<UserProfile?>((ref) => ref.watch(profileRepositoryProvider).watch());

/// ملف الصورة الحالية للملف الشخصي، إن وُجدت.
final profilePhotoProvider = FutureProvider<File?>((ref) async {
  final path = ref.watch(profileProvider).value?.photoPath;
  return ref.watch(profileRepositoryProvider).photoFile(path);
});
