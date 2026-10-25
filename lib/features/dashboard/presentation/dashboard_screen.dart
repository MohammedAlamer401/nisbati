import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/summary_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/profile_repository.dart';

/// الفترات المتاحة في الرئيسية (القسم 5.2).
enum DashboardPeriod {
  thisMonth('هذا الشهر'),
  lastMonth('الشهر السابق'),
  thisYear('هذه السنة'),
  custom('فترة مخصصة');

  const DashboardPeriod(this.label);
  final String label;
}

/// الرئيسية (الشاشة 10). الأرقام تُربط بقاعدة البيانات في المرحلة 7.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.thisMonth;

  @override
  Widget build(BuildContext context) {
    final zero = CurrencyFormatter.format(Money.zero);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
          children: [
            _Header(),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _PeriodSelector(
                value: _period,
                onChanged: (period) => setState(() => _period = period),
              ),
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'مستحقاتي خلال الفترة',
              value: zero,
              subtitle: 'من 0 خدمات',
              icon: AppIcons.collection,
              large: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'المحصّل منها',
                    value: zero,
                    icon: AppIcons.check,
                    accent: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'المتبقي منها',
                    value: zero,
                    icon: Icons.schedule_rounded,
                    accent: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'قيمة الخدمات', value: zero),
            const SizedBox(height: 24),
            EmptyState(
              icon: AppSvgIcons.services,
              title: 'لا توجد خدمات خلال هذه الفترة',
              message: 'سجّل خدمتك الأولى وسيحسب التطبيق نسبتك فوراً.',
              actionLabel: 'أضف أول خدمة',
              onAction: () => context.push(AppRoutes.newService()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(profileProvider).value?.fullName.trim().split(RegExp(r'\s+')).first;
    return Row(
      children: [
        InkWell(
          onTap: () => context.push(AppRoutes.profile),
          customBorder: const CircleBorder(),
          child: const CurrentUserAvatar(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(firstName == null ? 'مرحباً' : 'مرحباً، $firstName', style: AppTextStyles.caption),
              Text('ملخص أعمالي', style: AppTextStyles.screenTitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final DashboardPeriod value;
  final ValueChanged<DashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DashboardPeriod>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final period in DashboardPeriod.values)
          PopupMenuItem(value: period, child: Text(period.label)),
      ],
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
            Text(value.label, style: AppTextStyles.label),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
              ),
            ),
            Text(value, style: AppTextStyles.money(AppTextStyles.cardTitle)),
          ],
        ),
      ),
    );
  }
}
