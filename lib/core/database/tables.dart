// drift يعرّف القيود (check) بالإشارة إلى العمود نفسه داخل getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// جداول قاعدة البيانات — انظر القسم 7 في الوثيقة.
///
/// المبالغ بالقرش (`*Minor`) والنسب بنقاط الأساس (`*Bp`)،
/// والتواريخ «تاريخاً فقط» كنص `YYYY-MM-DD`.

/// الملف الشخصي: صف واحد دائماً (`id = 1`).
class UserProfiles extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get fullName => text().withLength(min: 2, max: 60)();
  TextColumn get businessName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'clients_name_normalized', columns: {#nameNormalized})
@TableIndex(name: 'clients_phone', columns: {#phone})
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 2, max: 100)();
  TextColumn get nameNormalized => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get contactName => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ServiceTypes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// النوع «أخرى»: لا يُحذف ولا يُعطّل.
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('ServiceRecord')
@TableIndex(name: 'services_service_date', columns: {#serviceDate})
@TableIndex(name: 'services_client_id', columns: {#clientId})
@TableIndex(name: 'services_service_type_id', columns: {#serviceTypeId})
class Services extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id, onDelete: KeyAction.restrict)();
  IntColumn get serviceTypeId =>
      integer().references(ServiceTypes, #id, onDelete: KeyAction.restrict)();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get titleNormalized => text()();
  TextColumn get description => text().nullable()();
  TextColumn get serviceDate => text().withLength(min: 10, max: 10)();
  IntColumn get serviceValueMinor =>
      integer().check(serviceValueMinor.isBiggerOrEqualValue(0))();
  IntColumn get commissionBp =>
      integer().check(commissionBp.isBetweenValues(0, 10000))();

  /// محسوب ومخزَّن عند الحفظ، ويُعاد حسابه عند كل تعديل (القسم 5.1).
  IntColumn get commissionMinor =>
      integer().check(commissionMinor.isBiggerOrEqualValue(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// طرق التحصيل.
enum PaymentMethod { cash, transfer, other }

@DataClassName('CollectionEntry')
@TableIndex(name: 'collections_service_id', columns: {#serviceId})
@TableIndex(name: 'collections_collection_date', columns: {#collectionDate})
class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serviceId => integer().references(Services, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerThanValue(0))();
  TextColumn get collectionDate => text().withLength(min: 10, max: 10)();
  TextColumn get paymentMethod => textEnum<PaymentMethod>()();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// إعدادات عامة بصيغة مفتاح/قيمة (القسم 7.6).
@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
