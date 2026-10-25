import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// بطاقة ملخص: عنوان صغير، وقيمة واضحة، ووصف اختياري (القسم 11).
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accent = AppColors.primary,
    this.large = false,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color accent;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: (large ? AppTextStyles.amountLarge : AppTextStyles.amountMedium)
                    .copyWith(color: large ? AppColors.textPrimary : accent),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: AppTextStyles.caption),
            ],
          ],
        ),
      ),
    );
  }
}
