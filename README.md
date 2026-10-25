# نسبتي — حساب مستحقات الخدمات

تطبيق Flutter عربي (RTL) لتسجيل العملاء والخدمات، وحساب نسبة المستخدم من قيمة كل خدمة، ومتابعة التحصيلات. يعمل محلياً دون إنترنت على Android وiOS.

الوثيقة المرجعية: [docs/nisbati_unified_spec.md](docs/nisbati_unified_spec.md)

## الحالة

| المرحلة | الحالة |
|---|---|
| 1. التأسيس: الثيم، RTL، الخط، التنقل، شاشة الإقلاع، الأيقونات | ✅ |
| 2. القاعدة والمنطق: drift، الحساب المالي بأعداد صحيحة، التطبيع العربي | ✅ |
| 3. التشغيل الأول، الملف الشخصي، الرمز السري، رمز الاسترداد، البصمة، القفل التلقائي | ✅ |
| 4–8. العملاء، الخدمات، التحصيلات، التقارير، النسخ الاحتياطي | ⏳ |

## التشغيل محلياً

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs --force-jit
flutter test test/
flutter run
```

> `--force-jit` مطلوب فقط عند العمل من مسار فيه حروف عربية (مثل `D:\النسب`) على Windows.

## الأيقونات

- أيقونات الواجهة: `assets/icons/*.svg` عبر `AppSvgIcon` و`AppSvgIcons`.
- أيقونة التطبيق: تُرسم برمجياً ثم تُولَّد مقاساتها:

```bash
flutter test tool/generate_app_icon_test.dart
dart run flutter_launcher_icons
```

## البناء عبر Codemagic

الملف [codemagic.yaml](codemagic.yaml) يحتوي ثلاثة مسارات:

| المسار | التشغيل | الناتج |
|---|---|---|
| `ios-unsigned` | تلقائي مع كل push على `main` | تحليل واختبارات وتحقق من بناء iOS (غير موقّع) |
| `android-apk` | يدوي | APK للتجربة |
| `ios-testflight` | يدوي | IPA مرفوع إلى TestFlight |

**الإعداد:** في [codemagic.io](https://codemagic.io/apps) → Add application → GitHub → اختر المستودع → Codemagic يقرأ `codemagic.yaml` تلقائياً.

**TestFlight يحتاج:** حساب Apple Developer، ومفتاح App Store Connect API مضافاً في Codemagic باسم `Nisbati ASC`، وتسجيل معرّف الحزمة `ly.nisbati.nisbati` في App Store Connect.
