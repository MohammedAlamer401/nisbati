import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/commission.dart';
import '../../../core/time/date_period.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_chip.dart';
import '../../settings/data/service_types_repository.dart';
import '../data/services_repository.dart';
import '../domain/service_models.dart';
import 'widgets/service_tile.dart';

/// قائمة الخدمات (الشاشة 14): بحث، وفلاتر الحالة، والنوع والفترة، والترتيب.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key, this.initialOutstanding = false});

  /// تُفتح من «غير محصّل حتى الآن» في الرئيسية.
  final bool initialOutstanding;

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  late var _filter = ServiceFilter(
    outstandingOnly: widget.initialOutstanding,
    sort: widget.initialOutstanding ? ServiceSort.highestRemaining : ServiceSort.newest,
  );

  static const _statuses = [CollectionStatus.uncollected, CollectionStatus.partial, CollectionStatus.collected];

  bool get _hasExtraFilters =>
      _filter.serviceTypeId != null || _filter.period.kind != PeriodKind.all || _filter.outstandingOnly;

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<ServiceFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FilterSheet(initial: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(serviceListProvider(_filter));
    return Scaffold(
      appBar: AppBar(
        title: const Text('الخدمات'),
        actions: [
          IconButton(
            tooltip: 'الفلاتر',
            onPressed: _openFilters,
            icon: Badge(isLabelVisible: _hasExtraFilters, child: const Icon(Icons.filter_list_rounded)),
          ),
          PopupMenuButton<ServiceSort>(
            tooltip: 'الترتيب',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _filter.sort,
            onSelected: (sort) => setState(() => _filter = _filter.copyWith(sort: sort)),
            itemBuilder: (context) => [
              for (final sort in ServiceSort.values) PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newService()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة خدمة'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(
              hint: 'ابحث باسم الخدمة أو العميل',
              onChanged: (v) => setState(() => _filter = _filter.copyWith(query: v.trim())),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('الكل'),
                  selected: _filter.status == null,
                  onSelected: (_) => setState(() => _filter = _filter.copyWith(status: () => null)),
                ),
                for (final status in _statuses) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(StatusChip.label(status)),
                    selected: _filter.status == status,
                    onSelected: (_) => setState(() => _filter = _filter.copyWith(status: () => status)),
                  ),
                ],
              ],
            ),
          ),
          if (_hasExtraFilters)
            _ActiveFilters(
              filter: _filter,
              onClear: () => setState(
                () => _filter = _filter.copyWith(
                  serviceTypeId: () => null,
                  period: DatePeriod.all,
                  outstandingOnly: false,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: services.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: EmptyState(icon: AppSvgIcons.services, title: 'تعذّر تحميل الخدمات'),
              ),
              data: (list) {
                if (list.isEmpty) {
                  final filtered = _filter.query.isNotEmpty || _filter.status != null || _hasExtraFilters;
                  return SingleChildScrollView(
                    child: filtered
                        ? const EmptyState(
                            icon: AppSvgIcons.search,
                            title: 'لا توجد خدمات مطابقة',
                            message: 'غيّر البحث أو الفلاتر',
                          )
                        : EmptyState(
                            icon: AppSvgIcons.services,
                            title: 'لا توجد خدمات بعد',
                            message: 'سجّل خدمتك الأولى وسيحسب التطبيق نسبتك فوراً.',
                            actionLabel: 'أضف أول خدمة',
                            onAction: () => context.push(AppRoutes.newService()),
                          ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => ServiceTile(
                    item: list[i],
                    showClient: list[i].clientName,
                    onTap: () => context.push(AppRoutes.serviceDetails(list[i].service.id)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.filter, required this.onClear});

  final ServiceFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(serviceTypesProvider).value ?? const [];
    final typeName = types.where((t) => t.id == filter.serviceTypeId).map((t) => t.name).firstOrNull;
    final parts = [
      if (filter.outstandingOnly) 'غير المحصّل فقط',
      ?typeName,
      if (filter.period.kind != PeriodKind.all) filter.period.label,
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 0),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(parts.join(' · '), style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          TextButton(onPressed: onClear, child: const Text('مسح الفلاتر')),
        ],
      ),
    );
  }
}

/// فلاتر النوع والفترة.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final ServiceFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late int? _typeId = widget.initial.serviceTypeId;
  late DatePeriod _period = widget.initial.period;

  Future<void> _pickRange() async {
    final today = DateFormatter.today();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: _period.kind == PeriodKind.custom
          ? DateTimeRange(start: _period.start!, end: _period.end!)
          : DateTimeRange(start: DateTime(today.year, today.month), end: today),
    );
    if (range != null) {
      setState(() => _period = DatePeriod.of(PeriodKind.custom, start: range.start, end: range.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(serviceTypesProvider).value ?? const [];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('نوع الخدمة', style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _typeId,
              items: [
                const DropdownMenuItem(value: null, child: Text('كل الأنواع')),
                for (final type in types) DropdownMenuItem(value: type.id, child: Text(type.name)),
              ],
              onChanged: (id) => setState(() => _typeId = id),
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 20),
            Text('الفترة', style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in PeriodKind.values.where((k) => k != PeriodKind.custom))
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: _period.kind == kind,
                    onSelected: (_) => setState(() => _period = DatePeriod.of(kind)),
                  ),
                ChoiceChip(
                  label: Text(_period.kind == PeriodKind.custom ? _period.label : PeriodKind.custom.label),
                  selected: _period.kind == PeriodKind.custom,
                  onSelected: (_) => _pickRange(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, widget.initial.copyWith(serviceTypeId: () => _typeId, period: _period)),
              child: const Text('تطبيق الفلاتر'),
            ),
          ],
        ),
      ),
    );
  }
}
