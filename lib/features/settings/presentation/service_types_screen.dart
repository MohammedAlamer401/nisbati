import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../data/service_types_repository.dart';

/// أنواع الخدمات (الشاشة 23): إضافة، وتسمية، وتعطيل، وترتيب بالسحب.
class ServiceTypesScreen extends ConsumerWidget {
  const ServiceTypesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, {ServiceType? type}) async {
    final name = await showDialog<String>(context: context, builder: (_) => _NameDialog(initial: type?.name));
    if (name == null) return;
    final repo = ref.read(serviceTypesRepositoryProvider);
    try {
      if (type == null) {
        await repo.add(name);
      } else {
        await repo.rename(type.id, name);
      }
    } on DuplicateServiceTypeException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يوجد نوع بهذا الاسم')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ServiceType type) async {
    final repo = ref.read(serviceTypesRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (await repo.isInUse(type.id)) {
      messenger.showSnackBar(const SnackBar(content: Text('النوع مستخدم في خدمات؛ يمكنك تعطيله بدلاً من حذفه.')));
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف النوع',
      message: 'هل تريد حذف «${type.name}»؟',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (confirmed) await repo.delete(type.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(serviceTypesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('أنواع الخدمات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة نوع'),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: types.length,
        header: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'اسحب لإعادة الترتيب. النوع المعطّل يختفي من نموذج الخدمة ويبقى في الخدمات القديمة والتقارير.',
            style: AppTextStyles.caption,
          ),
        ),
        onReorderItem: (from, to) {
          final ids = types.map((t) => t.id).toList();
          ids.insert(to, ids.removeAt(from));
          ref.read(serviceTypesRepositoryProvider).reorder(ids);
        },
        itemBuilder: (context, i) {
          final type = types[i];
          return Card(
            key: ValueKey(type.id),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.drag_indicator_rounded, color: AppColors.textSecondary),
              title: Text(
                type.name,
                style: type.isActive ? AppTextStyles.body : AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              subtitle: type.isSystem ? const Text('نوع أساسي') : (type.isActive ? null : const Text('معطّل')),
              onTap: () => _edit(context, ref, type: type),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!type.isSystem)
                    Switch(
                      value: type.isActive,
                      onChanged: (on) => ref.read(serviceTypesRepositoryProvider).setActive(type.id, on),
                    ),
                  if (!type.isSystem)
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => _delete(context, ref, type),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({this.initial});

  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'أدخل اسماً من حرفين على الأقل');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'نوع خدمة جديد' : 'تعديل الاسم'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(hintText: 'مثال: برمجة', errorText: _error, counterText: ''),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        TextButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }
}
