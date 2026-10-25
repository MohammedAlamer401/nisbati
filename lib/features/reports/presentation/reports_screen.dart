import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/arabic_plural.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/commission.dart';
import '../../../core/money/money.dart';
import '../../../core/time/date_period.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/period_picker.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/summary_card.dart';
import '../../collections/domain/collection_models.dart';
import '../../profile/data/profile_repository.dart';
import '../../services/data/services_repository.dart';
import '../../services/domain/service_models.dart';
import '../../services/presentation/widgets/service_tile.dart';
import '../../settings/data/service_types_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../application/report_builder.dart';
import '../data/reports_repository.dart';
import '../export/report_document.dart';
import '../export/report_exporters.dart';
import '../export/report_share.dart';

/// العملاء كلهم (مع المؤرشفين) لفلتر التقارير.
final _allClientsProvider = StreamProvider.autoDispose<List<Client>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.clients)..orderBy([(c) => OrderingTerm(expression: c.nameNormalized)])).watch();
});

/// التقارير (الشاشة 19): الفترة والفلاتر، وبطاقات الملخص، وستة أنواع، والتصدير.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  var _filter = ServiceFilter(period: DatePeriod.of(PeriodKind.thisMonth));
  var _kind = ReportKind.period;
  var _exporting = false;

  ServiceFilter get _effective => _kind.effectiveFilter(_filter);

  bool get _hasFilters => _filter.clientId != null || _filter.serviceTypeId != null || _filter.status != null;

  /// وصف الفلاتر المطبقة نصاً (للعرض والتصدير).
  String _filtersLabel() {
    final clients = ref.read(_allClientsProvider).value ?? const [];
    final types = ref.read(serviceTypesProvider).value ?? const [];
    return [
      ?clients.where((c) => c.id == _filter.clientId).map((c) => 'العميل: ${c.name}').firstOrNull,
      ?types.where((t) => t.id == _filter.serviceTypeId).map((t) => 'النوع: ${t.name}').firstOrNull,
      if (_filter.status != null && _kind != ReportKind.outstanding && _kind != ReportKind.collections)
        'الحالة: ${StatusChip.label(_filter.status!)}',
    ].join(' · ');
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<ServiceFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FiltersSheet(initial: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  Future<void> _export() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _ExportSheet(kind: _kind, periodLabel: _effective.period.label, filtersLabel: _filtersLabel()),
    );
    if (format == null || !mounted) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = await ReportBuilder(
        ref.read(reportsRepositoryProvider),
        ref.read(servicesRepositoryProvider),
      ).build(_kind, _filter, symbol: ref.read(currencySymbolProvider), filtersLabel: _filtersLabel());
      if (format == 'csv') {
        await shareFile(CsvExporter.build(doc), reportFileName(doc, 'csv'), 'text/csv');
      } else {
        final profiles = ref.read(profileRepositoryProvider);
        final profile = await profiles.get();
        final photo = await profiles.photoFile(profile?.photoPath);
        final font = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');
        final bytes = await PdfExporter.build(
          doc,
          header: ReportHeader(
            name: profile?.fullName ?? 'نسبتي',
            business: profile?.businessName,
            phone: profile?.phone,
            photo: await photo?.readAsBytes(),
          ),
          font: font,
        );
        await shareFile(bytes, reportFileName(doc, 'pdf'), 'application/pdf');
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('تعذّر تصدير التقرير'),
          action: SnackBarAction(label: 'إعادة المحاولة', onPressed: _export),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = ref.watch(currencySymbolProvider);
    String money(Money m) => CurrencyFormatter.format(m, symbol: symbol);
    final filtersLabel = _filtersLabel();

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(
            tooltip: 'تصدير',
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const AppSvgIcon(AppSvgIcons.export),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              if (_kind == ReportKind.outstanding)
                Chip(label: Text(PeriodKind.all.label))
              else
                PeriodButton(
                  period: _filter.period,
                  onChanged: (period) => setState(() => _filter = _filter.copyWith(period: period)),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: _openFilters,
                icon: Badge(isLabelVisible: _hasFilters, child: const Icon(Icons.filter_list_rounded)),
                label: const Text('الفلاتر'),
              ),
            ],
          ),
          if (filtersLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(child: Text(filtersLabel, style: AppTextStyles.caption)),
                  TextButton(
                    onPressed: () => setState(() => _filter = ServiceFilter(period: _filter.period)),
                    child: const Text('مسح'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (_kind != ReportKind.collections) _summary(money) else _collectionsSummary(money),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final kind in ReportKind.values) ...[
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _content(money),
        ],
      ),
    );
  }

  Widget _summary(String Function(Money) money) {
    final totals = ref.watch(totalsProvider(_effective)).value ?? Totals.empty;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SummaryCard(title: 'قيمة الخدمات', value: money(totals.value), accent: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: 'مستحقاتي',
                value: money(totals.collection.commission),
                accent: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'المحصّل منها',
                value: money(totals.collection.collected),
                accent: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: 'المتبقي منها',
                value: money(totals.collection.remaining),
                accent: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _collectionsSummary(String Function(Money) money) {
    final rows = ref.watch(collectionRowsProvider(_effective)).value ?? const [];
    final total = rows.fold(Money.zero, (sum, r) => sum + Money(r.entry.amountMinor));
    return Row(
      children: [
        Expanded(
          child: SummaryCard(title: 'المقبوضات خلال الفترة', value: money(total), accent: AppColors.success),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SummaryCard(title: 'عدد الدفعات', value: '${rows.length}', accent: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _content(String Function(Money) money) {
    final filter = _effective;
    switch (_kind) {
      case ReportKind.period || ReportKind.clients || ReportKind.types:
        final provider = switch (_kind) {
          ReportKind.period => byMonthProvider(filter),
          ReportKind.clients => byClientProvider(filter),
          _ => byTypeProvider(filter),
        };
        final groups = ref.watch(provider).value ?? const [];
        if (groups.isEmpty) return _empty();
        return Column(
          children: [
            for (final g in groups)
              _GroupTile(
                group: g,
                money: money,
                onTap: _kind == ReportKind.clients ? () => context.push(AppRoutes.clientDetails(g.key as int)) : null,
              ),
          ],
        );
      case ReportKind.services || ReportKind.outstanding:
        final items = ref.watch(serviceListProvider(filter)).value ?? const [];
        if (items.isEmpty) {
          return _kind == ReportKind.outstanding
              ? const EmptyState(icon: AppSvgIcons.check, title: 'لا توجد مستحقات غير محصّلة')
              : _empty();
        }
        return Column(
          children: [
            for (final item in items) ...[
              ServiceTile(
                item: item,
                showClient: item.clientName,
                onTap: () => context.push(AppRoutes.serviceDetails(item.service.id)),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      case ReportKind.collections:
        final rows = ref.watch(collectionRowsProvider(filter)).value ?? const [];
        if (rows.isEmpty) return _empty();
        return Column(
          children: [
            for (final r in rows)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => context.push(AppRoutes.serviceDetails(r.entry.serviceId)),
                  title: Text(money(Money(r.entry.amountMinor)), style: AppTextStyles.money(AppTextStyles.cardTitle)),
                  subtitle: Text(
                    '${r.clientName} · ${r.serviceTitle}\n'
                    '${DateFormatter.short(DateFormatter.fromStorage(r.entry.collectionDate))} · ${r.entry.paymentMethod.label}',
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        );
    }
  }

  Widget _empty() => const EmptyState(
    icon: AppSvgIcons.reports,
    title: 'لا توجد بيانات في هذه الفترة',
    message: 'غيّر الفترة أو الفلاتر',
  );
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.money, this.onTap});

  final GroupTotals group;
  final String Function(Money) money;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = group.totals.collection;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.label,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(ArabicPlural.services(group.totals.count), style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _Figure('مستحقاتي', money(c.commission), AppColors.primary)),
                  Expanded(child: _Figure('المحصّل', money(c.collected), AppColors.success)),
                  Expanded(child: _Figure('المتبقي', money(c.remaining), AppColors.warning)),
                ],
              ),
              const SizedBox(height: 4),
              Text('قيمة الخدمات ${money(group.totals.value)}', style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, style: AppTextStyles.money(AppTextStyles.label.copyWith(color: color))),
        ),
      ],
    );
  }
}

/// فلاتر العميل والنوع والحالة.
class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({required this.initial});

  final ServiceFilter initial;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late int? _clientId = widget.initial.clientId;
  late int? _typeId = widget.initial.serviceTypeId;
  late CollectionStatus? _status = widget.initial.status;

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(_allClientsProvider).value ?? const [];
    final types = ref.watch(serviceTypesProvider).value ?? const [];
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(text, style: AppTextStyles.label),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('فلاتر التقرير', style: AppTextStyles.cardTitle),
            label('العميل'),
            DropdownButtonFormField<int?>(
              initialValue: _clientId,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('كل العملاء')),
                for (final c in clients)
                  DropdownMenuItem(value: c.id, child: Text(c.isArchived ? '${c.name} (مؤرشف)' : c.name)),
              ],
              onChanged: (id) => setState(() => _clientId = id),
              decoration: const InputDecoration(),
            ),
            label('نوع الخدمة'),
            DropdownButtonFormField<int?>(
              initialValue: _typeId,
              items: [
                const DropdownMenuItem(value: null, child: Text('كل الأنواع')),
                for (final t in types) DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (id) => setState(() => _typeId = id),
              decoration: const InputDecoration(),
            ),
            label('حالة التحصيل'),
            DropdownButtonFormField<CollectionStatus?>(
              initialValue: _status,
              items: [
                const DropdownMenuItem(value: null, child: Text('كل الحالات')),
                for (final s in CollectionStatus.values) DropdownMenuItem(value: s, child: Text(StatusChip.label(s))),
              ],
              onChanged: (s) => setState(() => _status = s),
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                widget.initial.copyWith(clientId: () => _clientId, serviceTypeId: () => _typeId, status: () => _status),
              ),
              child: const Text('تطبيق الفلاتر'),
            ),
          ],
        ),
      ),
    );
  }
}

/// تأكيد الفترة والفلاتر قبل التصدير، واختيار الصيغة (الشاشة 19).
class _ExportSheet extends StatelessWidget {
  const _ExportSheet({required this.kind, required this.periodLabel, required this.filtersLabel});

  final ReportKind kind;
  final String periodLabel;
  final String filtersLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تصدير التقرير', style: AppTextStyles.cardTitle),
            const SizedBox(height: 12),
            _Line('التقرير', kind.label),
            _Line('الفترة', periodLabel),
            _Line('الفلاتر', filtersLabel.isEmpty ? 'بلا فلاتر' : filtersLabel),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'pdf'),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF للطباعة والمشاركة'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'csv'),
              icon: const Icon(Icons.table_chart_rounded),
              label: const Text('CSV للفتح في Excel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: AppTextStyles.caption)),
          Expanded(child: Text(value, style: AppTextStyles.label)),
        ],
      ),
    );
  }
}
