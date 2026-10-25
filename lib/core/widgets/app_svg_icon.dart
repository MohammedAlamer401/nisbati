import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// مسارات أيقونات SVG الخاصة بالتطبيق (assets/icons، شبكة 64×64).
abstract final class AppSvgIcons {
  static const _base = 'assets/icons';

  static const home = '$_base/home.svg';
  static const clients = '$_base/clients.svg';
  static const services = '$_base/services.svg';
  static const reports = '$_base/reports.svg';
  static const settings = '$_base/settings.svg';
  static const add = '$_base/add.svg';
  static const search = '$_base/search.svg';
  static const collections = '$_base/collections.svg';
  static const calendar = '$_base/calendar.svg';
  static const check = '$_base/check.svg';
  static const edit = '$_base/edit.svg';
  static const delete = '$_base/delete.svg';
  static const export = '$_base/export.svg';
  static const backup = '$_base/backup.svg';
  static const profile = '$_base/profile.svg';
  static const lock = '$_base/lock.svg';
  static const fingerprint = '$_base/fingerprint.svg';
  static const logout = '$_base/logout.svg';

  static const all = [
    home, clients, services, reports, settings, add, search, collections, calendar,
    check, edit, delete, export, backup, profile, lock, fingerprint, logout,
  ];
}

/// أيقونة SVG بألوانها الأصلية.
///
/// الأيقونات متعددة الألوان (تفاصيل بيضاء داخل شكل أزرق)، لذا لا تُلوَّن
/// بلون واحد؛ الحالة غير النشطة تُعرض رمادية ([muted]) مع الحفاظ على التفاصيل.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon(this.asset, {super.key, this.size = 24, this.muted = false, this.semanticLabel});

  final String asset;
  final double size;
  final bool muted;
  final String? semanticLabel;

  // تدرج رمادي بمعاملات الإضاءة القياسية مع شفافية خفيفة.
  static const _grayscale = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 0.55, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      asset,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
    return muted ? ColorFiltered(colorFilter: _grayscale, child: icon) : icon;
  }
}
