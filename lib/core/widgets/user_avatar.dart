import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../features/profile/data/profile_repository.dart';
import 'app_svg_icon.dart';

/// صورة المستخدم، أو الحرف الأول من اسمه عند غيابها (القسم 11).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.name, this.photo, this.radius = 22});

  final String? name;
  final File? photo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name?.trim().isNotEmpty == true ? name!.trim().characters.first : null;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      foregroundImage: photo == null ? null : FileImage(photo!),
      child: initial != null
          ? Text(
              initial,
              style: AppTextStyles.style(radius * 0.85, FontWeight.w700, color: AppColors.primary, height: 1),
            )
          : AppSvgIcon(AppSvgIcons.profile, size: radius),
    );
  }
}

/// صورة المستخدم الحالي من الملف الشخصي.
class CurrentUserAvatar extends ConsumerWidget {
  const CurrentUserAvatar({super.key, this.radius = 22});

  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final photo = ref.watch(profilePhotoProvider).value;
    return Semantics(
      label: 'صورة الملف الشخصي',
      child: UserAvatar(name: profile?.fullName, photo: photo, radius: radius),
    );
  }
}
