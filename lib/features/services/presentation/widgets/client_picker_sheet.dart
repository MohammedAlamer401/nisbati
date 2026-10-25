import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/text/arabic_normalizer.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../clients/data/clients_repository.dart';

/// اختيار عميل نشط مع بحث، أو إضافة عميل جديد دون مغادرة نموذج الخدمة (القسم 9.3).
/// يعيد معرّف العميل المختار.
Future<int?> showClientPicker(BuildContext context) => showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _ClientPickerSheet(),
    );

class _ClientPickerSheet extends ConsumerStatefulWidget {
  const _ClientPickerSheet();

  @override
  ConsumerState<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends ConsumerState<_ClientPickerSheet> {
  late final Future<List<Client>> _clients = ref.read(clientsRepositoryProvider).activeClients();
  var _query = '';

  Future<void> _addNew() async {
    final id = await context.push<int>(AppRoutes.newClient);
    if (id != null && mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('اختر العميل', style: AppTextStyles.cardTitle),
                const SizedBox(height: 12),
                SearchField(
                  hint: 'ابحث باسم العميل',
                  onChanged: (v) => setState(() => _query = ArabicNormalizer.normalize(v)),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
            ),
            title: Text('إضافة عميل جديد', style: AppTextStyles.label.copyWith(color: AppColors.primary)),
            onTap: _addNew,
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder(
              future: _clients,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final clients = snapshot.data!
                    .where((c) => _query.isEmpty || c.nameNormalized.contains(_query) || (c.phone ?? '').contains(_query))
                    .toList();
                if (clients.isEmpty) {
                  return Center(
                    child: Text(
                      snapshot.data!.isEmpty ? 'لا يوجد عملاء بعد' : 'لم نعثر على عميل بهذا الاسم',
                      style: AppTextStyles.caption,
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: clients.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: UserAvatar(name: clients[i].name, radius: 20),
                    title: Text(clients[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: clients[i].phone == null ? null : Text(clients[i].phone!, textDirection: TextDirection.ltr),
                    onTap: () => Navigator.pop(context, clients[i].id),
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
