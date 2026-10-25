import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/formatting/date_formatter.dart';
import '../../../reports/data/reports_repository.dart';

/// المستحقات والمحصّل منها لآخر الأشهر (الرئيسية — الشاشة 10).
///
/// الأقدم في اليمين والأحدث في اليسار، باتجاه القراءة العربية.
class MonthlyChart extends StatelessWidget {
  const MonthlyChart({super.key, required this.months, required this.symbol});

  final List<GroupTotals> months;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final ordered = months.reversed.toList();
    final maxMinor = months.fold<int>(
      0,
      (max, m) => m.totals.collection.commission.minor > max ? m.totals.collection.commission.minor : max,
    );
    final top = maxMinor == 0 ? 100.0 : maxMinor / 100 * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Text('المستحقات حسب الشهر', style: AppTextStyles.cardTitle),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 4),
              child: Row(
                children: [
                  _Legend(color: AppColors.primary, label: 'مستحقاتي'),
                  SizedBox(width: 16),
                  _Legend(color: AppColors.success, label: 'المحصّل منها'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: Semantics(
                label: 'رسم بياني للمستحقات في آخر ${months.length} أشهر',
                child: BarChart(
                  BarChartData(
                    maxY: top,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: top / 4,
                      getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= ordered.length) return const SizedBox.shrink();
                            final month = DateFormatter.fromStorage('${ordered[i].key}-01');
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                DateFormatter.months[month.month - 1],
                                style: AppTextStyles.caption.copyWith(fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppColors.textPrimary,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final totals = ordered[group.x].totals.collection;
                          final amount = rodIndex == 0 ? totals.commission : totals.collected;
                          return BarTooltipItem(
                            CurrencyFormatter.format(amount, symbol: symbol),
                            AppTextStyles.style(12, FontWeight.w600, color: Colors.white),
                          );
                        },
                      ),
                    ),
                    barGroups: [
                      for (final (i, m) in ordered.indexed)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 3,
                          barRods: [
                            BarChartRodData(
                              toY: m.totals.collection.commission.minor / 100,
                              color: AppColors.primary,
                              width: 10,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            BarChartRodData(
                              toY: m.totals.collection.collected.minor / 100,
                              color: AppColors.success,
                              width: 10,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
