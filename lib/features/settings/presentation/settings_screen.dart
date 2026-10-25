import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/money/money.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/settings_repository.dart';
import 'widgets/preference_fields.dart';

/// حالة خيار البصمة في الإعدادات.
final biometricSettingProvider = FutureProvider.autoDispose<(bool enabled, BiometricAvailability)>((ref) async {
  final enabled = await ref.watch(authRepositoryProvider).isBiometricEnabled();
  final availability = await ref.watch(biometricServiceProvider).availability();
  return (enabled, availability);
});

/// الإعدادات (الشاشة 20).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final prefs = ref.watch(preferencesProvider).value;
    final biometric = ref.watch(biometricSettingProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
              leading: const CurrentUserAvatar(radius: 26),
              title: Text(profile?.fullName ?? '', style: AppTextStyles.cardTitle),
              subtitle: profile?.businessName == null ? null : Text(profile!.businessName!),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => context.push(AppRoutes.profile),
            ),
          ),
          const _SectionTitle('الأمان'),
          _Group(children: [
            SwitchListTile(
              secondary: const AppSvgIcon(AppSvgIcons.fingerprint),
              title: const Text('الدخول بالبصمة'),
              subtitle: biometric == null || biometric.$2 == BiometricAvailability.available
                  ? null
                  : Text(biometric.$2 == BiometricAvailability.notEnrolled
                      ? 'أضف بصمة من إعدادات الجهاز أولاً'
                      : 'البصمة غير متاحة على هذا الجهاز'),
              value: biometric?.$1 ?? false,
              onChanged: biometric == null || biometric.$2 != BiometricAvailability.available
                  ? null
                  : (on) => _toggleBiometric(context, ref, on),
            ),
            ListTile(
              leading: const AppSvgIcon(AppSvgIcons.lock),
              title: const Text('القفل التلقائي'),
              trailing: _Value(prefs == null ? '' : autoLockLabel(prefs.autoLock)),
              onTap: prefs == null ? null : () => _pickAutoLock(context, ref, prefs.autoLock),
            ),
            ListTile(
              leading: const Icon(Icons.password_rounded, color: AppColors.primary),
              title: const Text('تغيير الرمز السري'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => context.push(AppRoutes.changePin),
            ),
            ListTile(
              leading: const Icon(Icons.key_rounded, color: AppColors.primary),
              title: const Text('رمز استرداد جديد'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => context.push(AppRoutes.newRecoveryCode),
            ),
          ]),
          const _SectionTitle('الحسابات'),
          _Group(children: [
            ListTile(
              leading: const AppSvgIcon(AppSvgIcons.collections),
              title: const Text('العملة'),
              trailing: _Value(prefs?.currencySymbol ?? ''),
              onTap: prefs == null ? null : () => _editCurrency(context, ref, prefs.currencySymbol),
            ),
            ListTile(
              leading: const AppSvgIcon(AppSvgIcons.reports),
              title: const Text('النسبة الافتراضية'),
              trailing: _Value(prefs == null ? '' : '${prefs.defaultCommission.toPlainString()}%'),
              onTap: prefs == null ? null : () => _editPercent(context, ref, prefs.defaultCommission),
            ),
            const ListTile(
              enabled: false,
              leading: AppSvgIcon(AppSvgIcons.services, muted: true),
              title: Text('أنواع الخدمات'),
              subtitle: Text('قريباً (المرحلة 5)'),
            ),
          ]),
          const _SectionTitle('البيانات'),
          const _Group(children: [
            ListTile(
              enabled: false,
              leading: AppSvgIcon(AppSvgIcons.backup, muted: true),
              title: Text('النسخ الاحتياطي والاستعادة'),
              subtitle: Text('قريباً (المرحلة 8)'),
            ),
          ]),
          const SizedBox(height: 16),
          _Group(children: [
            ListTile(
              leading: const AppSvgIcon(AppSvgIcons.logout),
              title: const Text('قفل التطبيق الآن'),
              onTap: () => ref.read(authControllerProvider.notifier).lock(),
            ),
          ]),
          const SizedBox(height: 16),
          Text('نسبتي — الإصدار 1.0.0', style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  /// التفعيل يتطلب الرمز السري ثم البصمة؛ التعطيل لا يحتاج تحققاً (الشاشة 20).
  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, bool on) async {
    final repo = ref.read(authRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      final verified = await context.push<bool>(AppRoutes.verifyPin);
      if (verified != true) return;
      final result = await ref.read(biometricServiceProvider).authenticate('أكّد بصمتك لتفعيل الدخول بها');
      if (result != BiometricResult.success) {
        if (result != BiometricResult.canceled) {
          messenger.showSnackBar(const SnackBar(content: Text('لم نتعرف على البصمة، لم يُفعَّل الخيار')));
        }
        return;
      }
    }
    await repo.setBiometricEnabled(on);
    ref.invalidate(biometricSettingProvider);
  }

  Future<void> _pickAutoLock(BuildContext context, WidgetRef ref, Duration current) async {
    final picked = await showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<Duration>(
          groupValue: current,
          onChanged: (value) => Navigator.pop(context, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('القفل التلقائي', style: AppTextStyles.cardTitle),
              ),
              for (final (duration, label) in autoLockOptions)
                RadioListTile<Duration>(value: duration, title: Text(label)),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await ref.read(settingsRepositoryProvider).setAutoLock(picked);
  }

  Future<void> _editCurrency(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final saved = await _editSheet(
      context,
      title: 'العملة',
      note: 'يتغير رمز العملة المعروض فقط، دون أي تحويل للمبالغ المسجلة.',
      field: CurrencyField(controller: controller),
    );
    if (saved) await ref.read(settingsRepositoryProvider).setCurrencySymbol(controller.text);
    controller.dispose();
  }

  Future<void> _editPercent(BuildContext context, WidgetRef ref, Percent current) async {
    final controller = TextEditingController(text: current.toPlainString());
    final saved = await _editSheet(
      context,
      title: 'النسبة الافتراضية',
      note: 'تُستخدم للخدمات الجديدة فقط، ولا تغيّر نسب الخدمات المسجلة.',
      field: PercentField(controller: controller),
    );
    if (saved) {
      await ref.read(settingsRepositoryProvider).setDefaultCommission(Percent.tryParse(controller.text)!);
    }
    controller.dispose();
  }

  Future<bool> _editSheet(
    BuildContext context, {
    required String title,
    required String note,
    required Widget field,
  }) async {
    final formKey = GlobalKey<FormState>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTextStyles.cardTitle),
              const SizedBox(height: 16),
              field,
              const SizedBox(height: 8),
              Text(note, style: AppTextStyles.caption),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) Navigator.pop(context, true);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    return saved == true;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 20, 8, 8),
      child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(indent: 56),
            child,
          ],
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
      ],
    );
  }
}
