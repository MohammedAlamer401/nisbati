import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/formatting/arabic_plural.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/time/date_period.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/period_picker.dart';
import '../../../core/widgets/summary_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/profile_repository.dart';
import '../../reports/data/reports_repository.dart';
import '../../services/data/services_repository.dart';
import '../../services/domain/service_models.dart';
import '../../services/presentation/widgets/service_tile.dart';
import '../../settings/data/settings_repository.dart';
import 'widgets/monthly_chart.dart';

/// الرئيسية (الشاشة 10): كل المؤشرات تعتمد الفترة المختارة نفسها (القسم 5.2).
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  var _period = DatePeriod.of(PeriodKind.thisMonth);

  @override
  Widget build(BuildContext context) {
    final symbol = ref.watch(currencySymbolProvider);
    String money(Money m) => CurrencyFormatter.format(m, symbol: symbol);
    final totals = ref.watch(totalsProvider(ServiceFilter(period: _period))).value ?? Totals.empty;
    final outstanding = ref.watch(outstandingProvider).value ?? Money.zero;
    final months = ref.watch(recentMonthsProvider).value;
    final latest = ref.watch(latestServicesProvider);
    final hasAnyService = latest.value?.isNotEmpty ?? true;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
          children: [
            const _Header(),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PeriodButton(
                period: _period,
                allowAll: false,
                onChanged: (period) => setState(() => _period = period),
              ),
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'مستحقاتي خلال الفترة',
              value: money(totals.collection.commission),
              subtitle: totals.count == 0 ? 'لا خدمات في هذه الفترة' : '${ArabicPlural.services(totals.count)} في هذه الفترة',
              icon: AppIcons.collection,
              large: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'المحصّل منها',
                    value: money(totals.collection.collected),
                    icon: AppIcons.check,
                    accent: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'المتبقي منها',
                    value: money(totals.collection.remaining),
                    icon: Icons.schedule_rounded,
                    accent: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'قيمة الخدمات', value: money(totals.value)),
            const SizedBox(height: 12),
            _OutstandingStrip(
              amount: money(outstanding),
              hasOutstanding: !outstanding.isZero,
              onTap: () => context.go(AppRoutes.outstandingServices),
            ),
            if (hasAnyService && months != null) ...[
              const SizedBox(height: 12),
              MonthlyChart(months: months, symbol: symbol),
            ],
            const SizedBox(height: 20),
            if (!hasAnyService)
              EmptyState(
                icon: AppSvgIcons.services,
                title: 'لا توجد خدمات بعد',
                message: 'سجّل خدمتك الأولى وسيحسب التطبيق نسبتك فوراً.',
                actionLabel: 'أضف أول خدمة',
                onAction: () => context.push(AppRoutes.newService()),
              )
            else ...[
              Row(
                children: [
                  Expanded(child: Text('آخر الخدمات', style: AppTextStyles.cardTitle)),
                  TextButton(onPressed: () => context.go(AppRoutes.services), child: const Text('عرض الكل')),
                ],
              ),
              const SizedBox(height: 4),
              for (final item in latest.value ?? const <ServiceListItem>[]) ...[
                ServiceTile(
                  item: item,
                  showClient: item.clientName,
                  onTap: () => context.push(AppRoutes.serviceDetails(item.service.id)),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.newService()),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة خدمة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

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

/// إجمالي غير المحصّل حتى الآن، بلا فترة، ويفتح الخدمات غير المحصّلة.
class _OutstandingStrip extends StatelessWidget {
  const _OutstandingStrip({required this.amount, required this.hasOutstanding, required this.onTap});

  final String amount;
  final bool hasOutstanding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: hasOutstanding ? AppColors.warningSoft : AppColors.successSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasOutstanding ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                hasOutstanding ? Icons.pending_actions_rounded : Icons.verified_rounded,
                color: hasOutstanding ? AppColors.warning : AppColors.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasOutstanding ? 'غير محصّل حتى الآن' : 'لا مستحقات غير محصّلة',
                  style: AppTextStyles.label.copyWith(color: hasOutstanding ? AppColors.warning : AppColors.success),
                ),
              ),
              if (hasOutstanding) ...[
                Text(amount, style: AppTextStyles.money(AppTextStyles.cardTitle.copyWith(color: AppColors.warning))),
                const Icon(Icons.chevron_left_rounded, color: AppColors.warning),
              ],
            ],
          ),
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
              child: Text(label, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            ),
            Text(value, style: AppTextStyles.money(AppTextStyles.cardTitle)),
          ],
        ),
      ),
    );
  }
}
