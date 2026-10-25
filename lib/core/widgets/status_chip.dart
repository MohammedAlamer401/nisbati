import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../money/commission.dart';

/// شارة حالة التحصيل — النص ظاهر دائماً ولا يُكتفى باللون (القسم 11).
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final CollectionStatus status;

  static String label(CollectionStatus status) => switch (status) {
        CollectionStatus.noCommission => 'لا مستحق',
        CollectionStatus.uncollected => 'غير محصّل',
        CollectionStatus.partial => 'محصّل جزئياً',
        CollectionStatus.collected => 'محصّل بالكامل',
      };

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (status) {
      CollectionStatus.noCommission => (AppColors.neutralSoft, AppColors.textSecondary, Icons.remove_rounded),
      CollectionStatus.uncollected => (AppColors.neutralSoft, AppColors.textPrimary, Icons.schedule_rounded),
      CollectionStatus.partial => (AppColors.warningSoft, AppColors.warning, Icons.timelapse_rounded),
      CollectionStatus.collected => (AppColors.successSoft, AppColors.success, Icons.check_circle_rounded),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(label(status), style: AppTextStyles.style(12, FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }
}
