import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_icons.dart';
import '../../app/theme/app_text_styles.dart';
import 'app_svg_icon.dart';

/// حالة فارغة: رسالة توضيحية مع إجراء مناسب (القسم 13).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  /// مسار أيقونة SVG من [AppSvgIcons].
  final String icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Center(child: AppSvgIcon(icon, size: 38)),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.cardTitle, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(AppIcons.add),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
            ),
          ],
        ],
      ),
    );
  }
}
