import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/nisbati_logo.dart';
import 'splash_illustration.dart';

/// تهيئة التطبيق: فتح قاعدة البيانات وتنفيذ البذور عند أول تشغيل.
final appInitProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  await db.customSelect('SELECT 1').get();
});

/// شاشة الإقلاع (الشاشة 1). تبقى ظاهرة حتى تكتمل التهيئة،
/// وبحد أدنى قصير حتى لا تومض الشاشة.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const minimumDuration = Duration(milliseconds: 1200);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _failed = false);
    final minimum = Future<void>.delayed(SplashScreen.minimumDuration);
    try {
      await ref.read(appInitProvider.future);
      await minimum;
      // توجيه حالات الدخول (onboarding / lock) يُضاف في المرحلة 3.
      if (mounted) context.go(AppRoutes.dashboard);
    } catch (_) {
      ref.invalidate(appInitProvider);
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // دوائر زخرفية في الزاويتين.
          PositionedDirectional(
            top: -170,
            end: -150,
            child: _blob(320, AppColors.primarySoft),
          ),
          PositionedDirectional(
            bottom: -170,
            start: -150,
            child: _blob(320, AppColors.successSoft),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    const NisbatiLogo(size: 136),
                    const SizedBox(height: 4),
                    Text(
                      'نسبتي',
                      style: AppTextStyles.style(64, FontWeight.w800, color: AppColors.primaryDark, height: 1.6),
                    ),
                    Text(
                      'حساب مستحقات الخدمات',
                      style: AppTextStyles.style(20, FontWeight.w500, color: const Color(0xFF4A5670)),
                    ),
                    const SizedBox(height: 36),
                    const SplashIllustration(),
                    const SizedBox(height: 32),
                    Text(
                      'كل خدمة .. مستحقك محسوب',
                      style: AppTextStyles.style(17, FontWeight.w500, color: const Color(0xFF4A5670)),
                    ),
                    const SizedBox(height: 40),
                    if (_failed) _errorState() else _loadingState(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingState() {
    return Column(
      children: [
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3.5,
            color: AppColors.primary,
            backgroundColor: AppColors.primarySoft,
          ),
        ),
        const SizedBox(height: 12),
        Text('جاري التحميل...', style: AppTextStyles.caption.copyWith(fontSize: 14)),
      ],
    );
  }

  Widget _errorState() {
    return Column(
      children: [
        Text(
          'تعذّر تحميل البيانات',
          style: AppTextStyles.label.copyWith(color: AppColors.error),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(180, 48)),
        ),
      ],
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.7), shape: BoxShape.circle),
      );
}
