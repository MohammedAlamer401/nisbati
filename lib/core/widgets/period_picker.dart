import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../formatting/date_formatter.dart';
import '../time/date_period.dart';

/// اختيار فترة: هذا الشهر، الشهر السابق، هذه السنة، كل الفترات، أو مخصصة (القسم 5.2).
Future<DatePeriod?> showPeriodPicker(BuildContext context, DatePeriod current, {bool allowAll = true}) =>
    showModalBottomSheet<DatePeriod>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PeriodSheet(current: current, allowAll: allowAll),
    );

class _PeriodSheet extends StatelessWidget {
  const _PeriodSheet({required this.current, required this.allowAll});

  final DatePeriod current;
  final bool allowAll;

  Future<void> _custom(BuildContext context) async {
    final today = DateFormatter.today();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: current.kind == PeriodKind.custom
          ? DateTimeRange(start: current.start!, end: current.end!)
          : DateTimeRange(start: DateTime(today.year, today.month), end: today),
    );
    if (range != null && context.mounted) {
      Navigator.pop(context, DatePeriod.of(PeriodKind.custom, start: range.start, end: range.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kinds = [PeriodKind.thisMonth, PeriodKind.lastMonth, PeriodKind.thisYear, if (allowAll) PeriodKind.all];
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الفترة', style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            for (final kind in kinds)
              ListTile(
                title: Text(kind.label),
                trailing: current.kind == kind ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(context, DatePeriod.of(kind)),
              ),
            ListTile(
              title: const Text('فترة مخصصة'),
              subtitle: current.kind == PeriodKind.custom ? Text(current.label) : null,
              trailing: current.kind == PeriodKind.custom
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : const Icon(Icons.date_range_rounded),
              onTap: () => _custom(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر يعرض الفترة الحالية ويفتح [showPeriodPicker].
class PeriodButton extends StatelessWidget {
  const PeriodButton({super.key, required this.period, required this.onChanged, this.allowAll = true});

  final DatePeriod period;
  final ValueChanged<DatePeriod> onChanged;
  final bool allowAll;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'الفترة: ${period.label}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final picked = await showPeriodPicker(context, period, allowAll: allowAll);
          if (picked != null) onChanged(picked);
        },
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(period.label, style: AppTextStyles.label),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
