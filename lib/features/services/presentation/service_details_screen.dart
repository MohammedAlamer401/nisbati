import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../settings/data/settings_repository.dart';
import '../data/services_repository.dart';

enum _MenuAction { edit, share, delete }

/// تفاصيل الخدمة (الشاشة 16).
class ServiceDetailsScreen extends ConsumerWidget {
  const ServiceDetailsScreen({super.key, required this.serviceId});

  final int serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(serviceProvider(serviceId));
    return item.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: EmptyState(icon: AppSvgIcons.services, title: 'تعذّر تحميل الخدمة')),
      ),
      data: (item) => item == null
          ? Scaffold(
              appBar: AppBar(),
              body: const Center(child: EmptyState(icon: AppSvgIcons.services, title: 'الخدمة غير موجودة')),
            )
          : _Details(item: item),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.item});

  final ServiceListItem item;

  String _summaryText(String symbol) {
    final s = item.service;
    String money(Money m) => CurrencyFormatter.format(m, symbol: symbol);
    return [
      'خدمة: ${s.title}',
      'العميل: ${item.clientName}',
      'النوع: ${item.typeName} — ${DateFormatter.long(DateFormatter.fromStorage(s.serviceDate))}',
      'قيمة الخدمة: ${money(Money(s.serviceValueMinor))}',
      'نسبتي: ${Percent(s.commissionBp).toPlainString()}%',
      'مستحقاتي: ${money(item.collection.commission)}',
      'المحصّل: ${money(item.collection.collected)} — المتبقي: ${money(item.collection.remaining)}',
      'الحالة: ${StatusChip.label(item.collection.status)}',
    ].join('\n');
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, _MenuAction action, String symbol) async {
    final service = item.service;
    switch (action) {
      case _MenuAction.edit:
        context.push(AppRoutes.editService(service.id));
      case _MenuAction.share:
        await SharePlus.instance.share(ShareParams(text: _summaryText(symbol)));
      case _MenuAction.delete:
        final repo = ref.read(servicesRepositoryProvider);
        final count = await repo.collectionCount(service.id);
        if (!context.mounted) return;
        final confirmed = await showConfirmDialog(
          context,
          title: 'حذف الخدمة',
          message: count == 0
              ? 'هل تريد حذف هذه الخدمة؟ لا يمكن التراجع عن هذا الإجراء.'
              : 'سيتم حذف الخدمة و$count ${count == 1 ? 'دفعة مرتبطة بها' : 'دفعات مرتبطة بها'}. لا يمكن التراجع.',
          confirmLabel: 'حذف',
          destructive: true,
        );
        if (!confirmed || !context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        context.pop();
        await repo.delete(service.id);
        messenger.showSnackBar(const SnackBar(content: Text('تم حذف الخدمة')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(currencySymbolProvider);
    final service = item.service;
    final collection = item.collection;
    String money(Money m) => CurrencyFormatter.format(m, symbol: symbol);
    final progress = collection.commission.isZero ? 0.0 : collection.collected.minor / collection.commission.minor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الخدمة'),
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: 'خيارات',
            onSelected: (action) => _onMenu(context, ref, action, symbol),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _MenuAction.edit, child: Text('تعديل الخدمة')),
              PopupMenuItem(value: _MenuAction.share, child: Text('مشاركة الملخص')),
              PopupMenuItem(
                value: _MenuAction.delete,
                child: Text('حذف الخدمة', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(service.title, style: AppTextStyles.screenTitle.copyWith(fontSize: 20))),
                      const SizedBox(width: 8),
                      StatusChip(collection.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => context.push(AppRoutes.clientDetails(service.clientId)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.clientName,
                              style: AppTextStyles.label.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '${item.typeName} · ${DateFormatter.long(DateFormatter.fromStorage(service.serviceDate))}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FigureRow(label: 'قيمة الخدمة', value: money(Money(service.serviceValueMinor))),
                  _FigureRow(label: 'نسبتي', value: CurrencyFormatter.percent(Percent(service.commissionBp))),
                  const Divider(height: 24),
                  Text('مستحقاتي', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(money(collection.commission), style: AppTextStyles.amountLarge),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 10,
                      color: AppColors.success,
                      backgroundColor: AppColors.warningSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    collection.commission.isZero
                        ? 'لا مستحق لهذه الخدمة'
                        : 'محصّل ${CurrencyFormatter.lri}${(progress * 100).round()}%${CurrencyFormatter.pdi}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 12),
                  _FigureRow(label: 'المحصّل', value: money(collection.collected), color: AppColors.success),
                  _FigureRow(label: 'المتبقي', value: money(collection.remaining), color: AppColors.warning),
                ],
              ),
            ),
          ),
          if (service.description != null || service.notes != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تفاصيل العمل', style: AppTextStyles.cardTitle),
                    const SizedBox(height: 6),
                    if (service.description != null) Text(service.description!, style: AppTextStyles.body),
                    if (service.notes != null) Text(service.notes!, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (!collection.remaining.isZero)
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.newCollection(service.id)),
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('تسجيل تحصيل'),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.editService(service.id)),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('تعديل الخدمة'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.collections(service.id)),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('سجل التحصيلات'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.label, required this.value, this.color = AppColors.textPrimary});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary))),
          Text(value, style: AppTextStyles.money(AppTextStyles.cardTitle.copyWith(color: color))),
        ],
      ),
    );
  }
}
