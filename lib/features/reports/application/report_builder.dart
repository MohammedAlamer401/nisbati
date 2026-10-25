import '../../../core/formatting/currency_formatter.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/time/date_period.dart';
import '../../../core/widgets/status_chip.dart';
import '../../collections/domain/collection_models.dart';
import '../../services/data/services_repository.dart';
import '../../services/domain/service_models.dart';
import '../data/reports_repository.dart';
import '../export/report_document.dart';

/// أنواع التقارير (الشاشة 19).
enum ReportKind {
  period('المستحقات حسب الفترة', 'المستحقات'),
  clients('حسب العميل', 'العملاء'),
  types('حسب نوع الخدمة', 'الأنواع'),
  services('الخدمات التفصيلي', 'الخدمات'),
  collections('التحصيلات', 'التحصيلات'),
  outstanding('المستحقات غير المحصّلة', 'غير-المحصلة');

  const ReportKind(this.label, this.slug);
  final String label;
  final String slug;

  /// تقرير غير المحصّلة يشمل كل الفترات (القسم 10 — الشاشة 19).
  ServiceFilter effectiveFilter(ServiceFilter filter) => switch (this) {
    ReportKind.outstanding => filter.copyWith(period: DatePeriod.all, outstandingOnly: true, status: () => null),
    ReportKind.services => filter.copyWith(sort: ServiceSort.newest),
    _ => filter,
  };
}

/// يبني محتوى تقرير للتصدير من البيانات الحالية.
class ReportBuilder {
  ReportBuilder(this._reports, this._services);

  final ReportsRepository _reports;
  final ServicesRepository _services;

  Future<ReportDocument> build(
    ReportKind kind,
    ServiceFilter filter, {
    required String symbol,
    required String filtersLabel,
    DateTime? now,
  }) async {
    final effective = kind.effectiveFilter(filter);
    String n(Money m) => CurrencyFormatter.number(m);
    String money(Money m) => CurrencyFormatter.format(m, symbol: symbol);
    final unit = ' ($symbol)';
    final totals = await _reports.watchTotals(effective).first;
    final summary = kind == ReportKind.collections
        ? <(String, String)>[]
        : [
            ('قيمة الخدمات', money(totals.value)),
            ('مستحقاتي', money(totals.collection.commission)),
            ('المحصّل منها', money(totals.collection.collected)),
            ('المتبقي منها', money(totals.collection.remaining)),
          ];

    List<String> totalsRow(String label) => [
      label,
      '${totals.count}',
      n(totals.value),
      n(totals.collection.commission),
      n(totals.collection.collected),
      n(totals.collection.remaining),
    ];
    List<String> groupRow(GroupTotals g) => [
      g.label,
      '${g.totals.count}',
      n(g.totals.value),
      n(g.totals.collection.commission),
      n(g.totals.collection.collected),
      n(g.totals.collection.remaining),
    ];
    final groupColumns = ['الخدمات', 'قيمة الخدمات$unit', 'مستحقاتي$unit', 'المحصّل$unit', 'المتبقي$unit'];

    ReportDocument doc({
      required List<String> columns,
      required List<List<String>> rows,
      List<String>? totalsLine,
      required Set<int> numeric,
      List<(String, String)>? summaryOverride,
    }) => ReportDocument(
      title: kind.label,
      slug: kind.slug,
      periodLabel: effective.period.label,
      filtersLabel: filtersLabel,
      generatedAt: now ?? DateTime.now(),
      summary: summaryOverride ?? summary,
      columns: columns,
      rows: rows,
      totals: totalsLine,
      numericColumns: numeric,
    );

    switch (kind) {
      case ReportKind.period:
        final months = await _reports.watchByMonth(effective).first;
        return doc(
          columns: ['الشهر', ...groupColumns],
          rows: months.map(groupRow).toList(),
          totalsLine: totalsRow('الإجمالي'),
          numeric: {1, 2, 3, 4, 5},
        );
      case ReportKind.clients:
        final clients = await _reports.watchByClient(effective).first;
        return doc(
          columns: ['العميل', ...groupColumns],
          rows: clients.map(groupRow).toList(),
          totalsLine: totalsRow('الإجمالي'),
          numeric: {1, 2, 3, 4, 5},
        );
      case ReportKind.types:
        final types = await _reports.watchByType(effective).first;
        return doc(
          columns: ['النوع', ...groupColumns],
          rows: types.map(groupRow).toList(),
          totalsLine: totalsRow('الإجمالي'),
          numeric: {1, 2, 3, 4, 5},
        );
      case ReportKind.services || ReportKind.outstanding:
        final items = await _services.watchServices(effective).first;
        final outstanding = kind == ReportKind.outstanding;
        return doc(
          columns: [
            'التاريخ',
            'العميل',
            'الخدمة',
            if (!outstanding) 'القيمة$unit',
            if (!outstanding) 'النسبة',
            'مستحقاتي$unit',
            'المحصّل$unit',
            'المتبقي$unit',
            if (!outstanding) 'الحالة',
          ],
          rows: [
            for (final item in items)
              [
                DateFormatter.short(DateFormatter.fromStorage(item.service.serviceDate)),
                item.clientName,
                item.service.title,
                if (!outstanding) n(Money(item.service.serviceValueMinor)),
                if (!outstanding) '${Percent(item.service.commissionBp).toPlainString()}%',
                n(item.collection.commission),
                n(item.collection.collected),
                n(item.collection.remaining),
                if (!outstanding) StatusChip.label(item.collection.status),
              ],
          ],
          totalsLine: [
            'الإجمالي',
            '',
            '${totals.count}',
            if (!outstanding) n(totals.value),
            if (!outstanding) '',
            n(totals.collection.commission),
            n(totals.collection.collected),
            n(totals.collection.remaining),
            if (!outstanding) '',
          ],
          numeric: outstanding ? {3, 4, 5} : {3, 4, 5, 6, 7},
        );
      case ReportKind.collections:
        final rows = await _reports.watchCollections(effective).first;
        final total = rows.fold(Money.zero, (sum, r) => sum + Money(r.entry.amountMinor));
        return doc(
          columns: ['التاريخ', 'العميل', 'الخدمة', 'الطريقة', 'المرجع', 'المبلغ$unit'],
          rows: [
            for (final r in rows)
              [
                DateFormatter.short(DateFormatter.fromStorage(r.entry.collectionDate)),
                r.clientName,
                r.serviceTitle,
                r.entry.paymentMethod.label,
                r.entry.reference ?? '',
                n(Money(r.entry.amountMinor)),
              ],
          ],
          totalsLine: ['الإجمالي', '', '', '', '${rows.length} دفعة', n(total)],
          numeric: {5},
          summaryOverride: [('عدد الدفعات', '${rows.length}'), ('المقبوضات خلال الفترة', money(total))],
        );
    }
  }
}
