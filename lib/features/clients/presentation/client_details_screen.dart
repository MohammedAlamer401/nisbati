import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/formatting/arabic_plural.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/money/commission.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/summary_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../services/data/services_repository.dart';
import '../../services/presentation/widgets/service_tile.dart';
import '../../settings/data/settings_repository.dart';
import '../data/clients_repository.dart';
import '../domain/client_models.dart';

enum _MenuAction { edit, archive, delete }

/// تفاصيل العميل (الشاشة 13): الاتصال، والإجماليات، وخدماته مع فلتر الحالة.
class ClientDetailsScreen extends ConsumerStatefulWidget {
  const ClientDetailsScreen({super.key, required this.clientId});

  final int clientId;

  @override
  ConsumerState<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends ConsumerState<ClientDetailsScreen> {
  CollectionStatus? _statusFilter;

  ClientsRepository get _repo => ref.read(clientsRepositoryProvider);

  Future<void> _call(String phone) async {
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح تطبيق الاتصال')));
    }
  }

  Future<void> _onMenu(_MenuAction action, ClientSummary summary) async {
    final messenger = ScaffoldMessenger.of(context);
    final client = summary.client;
    switch (action) {
      case _MenuAction.edit:
        context.push(AppRoutes.editClient(client.id));
      case _MenuAction.archive:
        final archive = !client.isArchived;
        await _repo.setArchived(client.id, archive);
        messenger.showSnackBar(SnackBar(
          content: Text(archive ? 'نُقل العميل إلى المؤرشفين' : 'أُعيد العميل إلى النشطين'),
          action: SnackBarAction(label: 'تراجع', onPressed: () => _repo.setArchived(client.id, !archive)),
        ));
      case _MenuAction.delete:
        final confirmed = await showConfirmDialog(
          context,
          title: 'حذف العميل',
          message: 'هل تريد حذف «${client.name}»؟ لا يمكن التراجع عن هذا الإجراء.',
          confirmLabel: 'حذف',
          destructive: true,
        );
        if (!confirmed) return;
        try {
          await _repo.delete(client.id);
          if (!mounted) return;
          context.pop();
          messenger.showSnackBar(const SnackBar(content: Text('تم حذف العميل')));
        } on ClientHasServicesException {
          messenger.showSnackBar(
            const SnackBar(content: Text('لا يمكن حذف عميل له خدمات. يمكنك أرشفته بدلاً من ذلك.')),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(clientProvider(widget.clientId));
    return client.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: EmptyState(icon: AppSvgIcons.clients, title: 'تعذّر تحميل العميل')),
      ),
      data: (summary) {
        if (summary == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: EmptyState(icon: AppSvgIcons.clients, title: 'العميل غير موجود')),
          );
        }
        return _details(summary);
      },
    );
  }

  Widget _details(ClientSummary summary) {
    final client = summary.client;
    final symbol = ref.watch(currencySymbolProvider);
    String money(Money m) => CurrencyFormatter.format(m, symbol: symbol);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العميل'),
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: 'خيارات',
            onSelected: (action) => _onMenu(action, summary),
            itemBuilder: (context) => [
              const PopupMenuItem(value: _MenuAction.edit, child: Text('تعديل البيانات')),
              PopupMenuItem(
                value: _MenuAction.archive,
                child: Text(client.isArchived ? 'إلغاء الأرشفة' : 'أرشفة العميل'),
              ),
              if (summary.serviceCount == 0)
                const PopupMenuItem(
                  value: _MenuAction.delete,
                  child: Text('حذف العميل', style: TextStyle(color: AppColors.error)),
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
                    children: [
                      UserAvatar(name: client.name, radius: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(client.name, style: AppTextStyles.screenTitle.copyWith(fontSize: 20)),
                            if (client.isArchived)
                              Text('مؤرشف', style: AppTextStyles.label.copyWith(color: AppColors.warning)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (client.phone != null || client.contactName != null || client.address != null)
                    const Divider(height: 24),
                  if (client.phone != null)
                    _InfoLine(
                      icon: Icons.phone_rounded,
                      text: '${CurrencyFormatter.lri}${client.phone}${CurrencyFormatter.pdi}',
                    ),
                  if (client.contactName != null) _InfoLine(icon: Icons.badge_outlined, text: client.contactName!),
                  if (client.address != null) _InfoLine(icon: Icons.place_outlined, text: client.address!),
                  if (client.notes != null) ...[
                    const SizedBox(height: 8),
                    Text(client.notes!, style: AppTextStyles.caption),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (client.phone != null) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _call(client.phone!),
                            icon: const Icon(Icons.call_rounded),
                            label: const Text('اتصال'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.editClient(client.id)),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('تعديل'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SummaryCard(
            title: 'مستحقاتي من هذا العميل',
            value: money(summary.collection.commission),
            subtitle: '${ArabicPlural.services(summary.serviceCount)} · قيمة الخدمات ${money(summary.totalValue)}',
            icon: Icons.account_balance_wallet_rounded,
            large: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: 'المحصّل',
                  value: money(summary.collection.collected),
                  icon: Icons.check_circle_outline_rounded,
                  accent: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'المتبقي',
                  value: money(summary.collection.remaining),
                  icon: Icons.schedule_rounded,
                  accent: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('خدمات العميل', style: AppTextStyles.cardTitle),
          const SizedBox(height: 8),
          _ServicesSection(
            clientId: client.id,
            filter: _statusFilter,
            onFilterChanged: (status) => setState(() => _statusFilter = status),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _ServicesSection extends ConsumerWidget {
  const _ServicesSection({required this.clientId, required this.filter, required this.onFilterChanged});

  final int clientId;
  final CollectionStatus? filter;
  final ValueChanged<CollectionStatus?> onFilterChanged;

  static const _filters = [
    CollectionStatus.uncollected,
    CollectionStatus.partial,
    CollectionStatus.collected,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(clientServicesProvider(clientId)).value ?? const [];
    if (services.isEmpty) {
      return EmptyState(
        icon: AppSvgIcons.services,
        title: 'لا توجد خدمات لهذا العميل',
        message: 'سجّل خدمة وستظهر هنا مع إجمالياتها.',
        actionLabel: 'إضافة خدمة لهذا العميل',
        onAction: () => context.push(AppRoutes.newService(clientId: clientId)),
      );
    }
    final shown = filter == null ? services : services.where((s) => s.collection.status == filter).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.newService(clientId: clientId)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة خدمة لهذا العميل'),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(label: const Text('الكل'), selected: filter == null, onSelected: (_) => onFilterChanged(null)),
              for (final status in _filters) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(StatusChip.label(status)),
                  selected: filter == status,
                  onSelected: (_) => onFilterChanged(status),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('لا توجد خدمات بهذه الحالة', style: AppTextStyles.caption, textAlign: TextAlign.center),
          ),
        for (final item in shown) ...[
          ServiceTile(item: item, onTap: () => context.push(AppRoutes.serviceDetails(item.service.id))),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
