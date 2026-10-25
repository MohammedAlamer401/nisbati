import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/labeled_field.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile_validators.dart';

/// نموذج الملف الشخصي: الصورة والحقول، ويحفظ عبر [ProfileRepository] (القسم 6.7).
///
/// يُستخدم في التشغيل الأول (حقول مختصرة) وفي شاشة الملف الشخصي (كل الحقول).
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({
    super.key,
    this.initial,
    this.initialPhoto,
    required this.submitLabel,
    required this.onSaved,
    this.compact = false,
    this.onDirtyChanged,
  });

  final UserProfile? initial;
  final File? initialPhoto;
  final String submitLabel;
  final VoidCallback onSaved;

  /// التشغيل الأول: الاسم والمهنة والهاتف فقط.
  final bool compact;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.fullName);
  late final _business = TextEditingController(text: widget.initial?.businessName);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _email = TextEditingController(text: widget.initial?.email);
  late final _city = TextEditingController(text: widget.initial?.city);

  File? _newPhoto;
  var _removePhoto = false;
  var _saving = false;
  var _dirty = false;

  @override
  void dispose() {
    for (final c in [_name, _business, _phone, _email, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
    widget.onDirtyChanged?.call(true);
  }

  File? get _shownPhoto => _newPhoto ?? (_removePhoto ? null : widget.initialPhoto);

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (_shownPhoto != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('حذف الصورة', style: TextStyle(color: AppColors.error)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      setState(() {
        _newPhoto = null;
        _removePhoto = true;
      });
      _markDirty();
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return;
    setState(() {
      _newPhoto = File(picked.path);
      _removePhoto = false;
    });
    _markDirty();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(profileRepositoryProvider);
    try {
      await repo.save(ProfileInput(
        fullName: _name.text,
        businessName: _business.text,
        phone: _phone.text,
        email: _email.text,
        city: _city.text,
      ));
      if (_newPhoto != null) {
        await repo.setPhoto(_newPhoto!);
      } else if (_removePhoto) {
        await repo.removePhoto();
      }
      ref.invalidate(profilePhotoProvider);
      widget.onDirtyChanged?.call(false);
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر حفظ الملف الشخصي. حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Form(
      key: _formKey,
      onChanged: _markDirty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Semantics(
              button: true,
              label: 'تغيير الصورة الشخصية',
              child: InkWell(
                onTap: _pickPhoto,
                customBorder: const CircleBorder(),
                child: Stack(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: _name,
                      builder: (context, value, _) => UserAvatar(name: value.text, photo: _shownPhoto, radius: 48),
                    ),
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.photo_camera_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _pickPhoto,
              child: Text(_shownPhoto == null ? 'إضافة صورة' : 'تغيير الصورة'),
            ),
          ),
          gap,
          LabeledField(
            label: 'الاسم الكامل',
            required: true,
            controller: _name,
            validator: ProfileValidators.fullName,
            maxLength: 60,
          ),
          gap,
          LabeledField(
            label: 'المهنة أو الاسم التجاري',
            controller: _business,
            hint: 'مثال: فني شبكات وكاميرات',
            maxLength: 80,
          ),
          gap,
          LabeledField(
            label: 'رقم الهاتف',
            controller: _phone,
            validator: ProfileValidators.phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textInputAction: widget.compact ? TextInputAction.done : TextInputAction.next,
          ),
          if (!widget.compact) ...[
            gap,
            LabeledField(
              label: 'البريد الإلكتروني',
              controller: _email,
              validator: ProfileValidators.email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
            ),
            gap,
            LabeledField(
              label: 'المدينة',
              controller: _city,
              textInputAction: TextInputAction.done,
              maxLength: 40,
            ),
          ],
          const SizedBox(height: 8),
          Text('تظهر بياناتك في رأس التقارير المصدّرة', style: AppTextStyles.caption),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving || (!widget.compact && !_dirty) ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
