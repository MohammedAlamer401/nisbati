import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../reports/export/report_share.dart';
import '../../settings/data/settings_repository.dart';
import '../data/backup_service.dart';

/// النسخ الاحتياطي والاستعادة والتصدير الكامل (القسم 14).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  String? _busy;

  BackupService get _service => ref.read(backupServiceProvider);

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = label);
    try {
      await action();
    } on BackupFormatException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('تعذّر إكمال العملية. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _showError(String message) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تعذّر الإكمال'),
          content: Text(message),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );

  Future<void> _backup() => _run('backup', () async {
        final bytes = await _service.create();
        final shared = await shareFile(bytes, _service.fileName(), 'application/zip');
        if (!shared) return;
        await _service.markBackedUp();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية')));
        }
      });

  Future<void> _export() => _run('export', () async {
        await shareFile(await _service.exportCsv(), _service.exportFileName(), 'application/zip');
      });

  Future<void> _restore() async {
    final file = await FilePicker.pickFile(dialogTitle: 'اختر ملف النسخة الاحتياطية');
    if (file == null || !mounted) return;
    await _run('restore', () async {
      final bytes = await file.readAsBytes();
      final info = _service.inspect(bytes);
      if (!mounted) return;
      final confirmed = await showConfirmDialog(
        context,
        title: 'استعادة النسخة',
        message: 'نسخة ${DateFormatter.long(info.createdAt)}:\n'
            '${info.count('clients')} عميل، ${info.count('services')} خدمة، ${info.count('collections')} دفعة.\n\n'
            'ستُستبدل كل البيانات الحالية بهذه النسخة. ستُحفظ نسخة من بياناتك الحالية تلقائياً قبل الاستبدال.',
        confirmLabel: 'استعادة',
        destructive: true,
      );
      if (!confirmed) return;
      await _service.saveSafetyCopy();
      await _service.restore(bytes);
      ref.invalidate(profilePhotoProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الاستعادة. أدخل رمزك السري للمتابعة.')),
      );
      await ref.read(authControllerProvider.notifier).lockAfterRestore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider).value;
    final last = prefs?.lastBackupAt;
    final busy = _busy != null;

    Widget spinnerOr(String key, Widget icon) =>
        _busy == key ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : icon;

    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: last == null ? AppColors.warningSoft : AppColors.successSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  last == null ? Icons.warning_amber_rounded : Icons.verified_rounded,
                  color: last == null ? AppColors.warning : AppColors.success,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        last == null ? 'لم تُنشئ نسخة احتياطية بعد' : 'آخر نسخة احتياطية',
                        style: AppTextStyles.cardTitle,
                      ),
                      if (last != null) Text(DateFormatter.long(last), style: AppTextStyles.body),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'بياناتك محفوظة على هذا الجهاز فقط، وقد تضيع إذا حُذف التطبيق أو فُقد الجهاز. '
            'احفظ النسخة في مكان آخر (Google Drive أو iCloud أو واتساب). '
            'النسخة لا تحوي رمزك السري ولا رمز الاسترداد.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : _backup,
            icon: spinnerOr('backup', const Icon(Icons.cloud_upload_rounded)),
            label: const Text('إنشاء نسخة احتياطية'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : _restore,
            icon: spinnerOr('restore', const Icon(Icons.settings_backup_restore_rounded)),
            label: const Text('استعادة نسخة احتياطية'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : _export,
            icon: spinnerOr('export', const AppSvgIcon(AppSvgIcons.export, size: 20)),
            label: const Text('تصدير كل البيانات (CSV)'),
          ),
          const SizedBox(height: 28),
          Text('ذكّرني بالنسخ الاحتياطي كل', style: AppTextStyles.label),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (final (days, label) in backupReminderOptions) ButtonSegment(value: days, label: Text(label)),
            ],
            selected: {prefs?.backupReminderDays ?? 7},
            showSelectedIcon: false,
            onSelectionChanged: (s) => ref.read(settingsRepositoryProvider).setBackupReminderDays(s.first),
          ),
        ],
      ),
    );
  }
}
