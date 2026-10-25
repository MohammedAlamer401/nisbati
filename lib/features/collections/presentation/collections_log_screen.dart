import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../services/data/services_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../data/collections_repository.dart';
import '../domain/collection_models.dart';

enum _Action { edit, delete }

/// سجل التحصيلات لخدمة (الشاشة 18): تعديل كل دفعة وحذفها.
class CollectionsLogScreen extends ConsumerWidget {
  const CollectionsLogScreen({super.key, required this.serviceId});

  final int serviceId;

  Future<void> _onAction(BuildContext context, WidgetRef ref, _Action action, CollectionEntry entry) async {
    switch (action) {
      case _Action.edit:
        context.push(AppRoutes.editCollection(serviceId, entry.id));
      case _Action.delete:
        final confirmed = await showConfirmDialog(
          context,
          title: 'حذف الدفعة',
          message: 'هل تريد حذف هذه الدفعة؟ سيزيد المتبقي بمقدارها.',
          confirmLabel: 'حذف',
          destructive: true,
        );
        if (!confirmed) return;
        await ref.read(collectionsRepositoryProvider).delete(entry.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الدفعة')));
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(currencySymbolProvider);
    final service = ref.watch(serviceProvider(serviceId)).value;
    final entries = ref.watch(serviceCollectionsProvider(serviceId));
    String money(Money m) => CurrencyFormatter.format(m, symbol: symbol);
    final canAdd = service != null && !service.collection.remaining.isZero;

    return Scaffold(
      appBar: AppBar(title: const Text('سجل التحصيلات')),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.newCollection(serviceId)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('تسجيل تحصيل'),
            )
          : null,
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: EmptyState(icon: AppSvgIcons.collections, title: 'تعذّر تحميل الدفعات')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: AppSvgIcons.collections,
                title: 'لا توجد دفعات بعد',
                message: 'سجّل أول دفعة تستلمها من مستحقات هذه الخدمة.',
              ),
            );
          }
          final total = list.fold(Money.zero, (sum, e) => sum + Money(e.amountMinor));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (service != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(service.service.title, style: AppTextStyles.cardTitle),
                ),
              for (final entry in list) ...[
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.successSoft,
                      child: Icon(Icons.payments_rounded, color: AppColors.success),
                    ),
                    title: Text(
                      money(Money(entry.amountMinor)),
                      style: AppTextStyles.money(AppTextStyles.cardTitle),
                    ),
                    subtitle: Text(
                      [
                        DateFormatter.short(DateFormatter.fromStorage(entry.collectionDate)),
                        entry.paymentMethod.label,
                        ?entry.reference,
                      ].join(' · '),
                    ),
                    trailing: PopupMenuButton<_Action>(
                      tooltip: 'خيارات الدفعة',
                      onSelected: (action) => _onAction(context, ref, action, entry),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: _Action.edit, child: Text('تعديل')),
                        PopupMenuItem(value: _Action.delete, child: Text('حذف', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(child: Text('المجموع', style: AppTextStyles.cardTitle)),
                  Text(money(total), style: AppTextStyles.money(AppTextStyles.cardTitle.copyWith(color: AppColors.success))),
                ],
              ),
              if (service != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: Text('المتبقي', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary))),
                    Text(
                      money(service.collection.remaining),
                      style: AppTextStyles.money(AppTextStyles.label.copyWith(color: AppColors.warning)),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
