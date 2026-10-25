import 'package:flutter/material.dart';

import 'app_colors.dart';

/// أنماط النص — انظر القسم 8.3 في الوثيقة.
///
/// خط Cairo مضمَّن كخط متغيّر (Variable Font)، لذا يجب تمرير محور الوزن
/// `wght` صراحةً مع كل [FontWeight] وإلا يُرسم بالوزن الافتراضي.
abstract final class AppTextStyles {
  static const fontFamily = 'Cairo';

  static TextStyle style(
    double size,
    FontWeight weight, {
    Color color = AppColors.textPrimary,
    double height = 1.5,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: color,
      height: height,
    );
  }

  /// يضيف الأرقام الجدولية حتى تصطف المبالغ في القوائم.
  static TextStyle money(TextStyle base) =>
      base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static final screenTitle = style(22, FontWeight.w600);
  static final cardTitle = style(15, FontWeight.w600);
  static final amountLarge = money(style(28, FontWeight.w700, height: 1.3));
  static final amountMedium = money(style(18, FontWeight.w700, height: 1.3));
  static final body = style(15, FontWeight.w400);
  static final label = style(14, FontWeight.w500);
  static final caption = style(12.5, FontWeight.w400, color: AppColors.textSecondary);

  static TextTheme textTheme() {
    return TextTheme(
      displayLarge: style(48, FontWeight.w700),
      displayMedium: style(40, FontWeight.w700),
      displaySmall: style(32, FontWeight.w700),
      headlineLarge: style(28, FontWeight.w600),
      headlineMedium: style(24, FontWeight.w600),
      headlineSmall: style(22, FontWeight.w600),
      titleLarge: style(20, FontWeight.w600),
      titleMedium: style(16, FontWeight.w600),
      titleSmall: style(14, FontWeight.w600),
      bodyLarge: style(16, FontWeight.w400),
      bodyMedium: style(15, FontWeight.w400),
      bodySmall: style(13, FontWeight.w400, color: AppColors.textSecondary),
      labelLarge: style(15, FontWeight.w600),
      labelMedium: style(13, FontWeight.w500),
      labelSmall: style(12, FontWeight.w500),
    );
  }
}
