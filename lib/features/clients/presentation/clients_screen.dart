import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/formatting/arabic_plural.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../settings/data/settings_repository.dart';
import '../data/clients_repository.dart';
import '../domain/client_models.dart';

/// قائمة العملاء (الشاشة 11): بحث بالاسم أو الهاتف، وتبويبا النشطين والمؤرشفين.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('العملاء'),
          bottom: const TabBar(tabs: [Tab(text: 'النشطون'), Tab(text: 'المؤرشفون')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.newClient),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('إضافة عميل'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SearchField(
                hint: 'ابحث باسم العميل أو رقم الهاتف',
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ClientList(query: _query, archived: false),
                  _ClientList(query: _query, archived: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientList extends ConsumerWidget {
  const _ClientList({required this.query, required this.archived});

  final String query;
  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientListProvider((query: query, archived: archived)));
    return clients.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
        child: EmptyState(icon: AppSvgIcons.clients, title: 'تعذّر تحميل العملاء'),
      ),
      data: (list) {
        if (list.isEmpty) {
          return SingleChildScrollView(
            child: query.isNotEmpty
                ? const EmptyState(
                    icon: AppSvgIcons.search,
                    title: 'لم نعثر على عميل بهذا الاسم',
                    message: 'جرّب جزءاً من الاسم أو رقم الهاتف',
                  )
                : archived
                    ? const EmptyState(
                        icon: AppSvgIcons.clients,
                        title: 'لا يوجد عملاء مؤرشفون',
                        message: 'العملاء المؤرشفون يختفون من نموذج الخدمة ويبقون في التقارير',
                      )
                    : EmptyState(
                        icon: AppSvgIcons.clients,
                        title: 'لا يوجد عملاء بعد',
                        message: 'أضف عملاءك مرة واحدة واستخدمهم في كل خدماتك',
                        actionLabel: 'إضافة عميل',
                        onAction: () => context.push(AppRoutes.newClient),
                      ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => ClientTile(
            summary: list[i],
            onTap: () => context.push(AppRoutes.clientDetails(list[i].client.id)),
          ),
        );
      },
    );
  }
}

/// عنصر عميل: الاسم، والهاتف، وعدد الخدمات، والمستحقات، والمتبقي إن وُجد.
class ClientTile extends ConsumerWidget {
  const ClientTile({super.key, required this.summary, this.onTap});

  final ClientSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(currencySymbolProvider);
    final client = summary.client;
    final remaining = summary.collection.remaining;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              UserAvatar(name: client.name, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: AppTextStyles.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        if (client.phone != null) ...[
                          TextSpan(text: '${CurrencyFormatter.lri}${client.phone}${CurrencyFormatter.pdi}'),
                          const TextSpan(text: ' · '),
                        ],
                        TextSpan(text: ArabicPlural.services(summary.serviceCount)),
                      ]),
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(summary.collection.commission, symbol: symbol),
                    style: AppTextStyles.money(AppTextStyles.label.copyWith(color: AppColors.primary)),
                  ),
                  if (!remaining.isZero) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'متبقٍ ${CurrencyFormatter.format(remaining, symbol: symbol)}',
                        style: AppTextStyles.money(
                          AppTextStyles.style(11.5, FontWeight.w600, color: AppColors.warning),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
