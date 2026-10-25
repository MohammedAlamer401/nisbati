import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../data/profile_repository.dart';
import 'widgets/profile_form.dart';

/// الملف الشخصي (الشاشة 21): تعديل البيانات والصورة، وتغيير الرمز.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _dirty = false;

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغييرات غير محفوظة'),
        content: const Text('هل تريد الخروج دون حفظ التعديلات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('متابعة التعديل')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('خروج دون حفظ')),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _dirty = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final photo = ref.watch(profilePhotoProvider);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('الملف الشخصي')),
        body: profile.isLoading || photo.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProfileForm(
                      initial: profile.value,
                      initialPhoto: photo.value,
                      submitLabel: 'حفظ التعديلات',
                      onDirtyChanged: (dirty) => setState(() => _dirty = dirty),
                      onSaved: () {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('تم تحديث الملف الشخصي')));
                        context.pop();
                      },
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: ListTile(
                        leading: const AppSvgIcon(AppSvgIcons.lock),
                        title: const Text('تغيير الرمز السري'),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => context.push(AppRoutes.changePin),
                      ),
                    ),
                    if (profile.value != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'عضو منذ ${DateFormatter.short(profile.value!.createdAt)}',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
