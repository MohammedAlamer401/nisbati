import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/nisbati_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../../splash/presentation/splash_illustration.dart';

/// شاشة الترحيب (الشاشة 2): أول ما يراه المستخدم بعد التثبيت.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  var _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    await ref.read(authControllerProvider.notifier).completeStep(OnboardingStep.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = const Color(0xFF4A5670);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _WavePainter())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        const NisbatiLogo(size: 112),
                        Text(
                          'نسبتي',
                          style: AppTextStyles.style(52, FontWeight.w800, color: AppColors.primaryDark, height: 1.6),
                        ),
                        Text(
                          'حساب مستحقات الخدمات',
                          style: AppTextStyles.style(18, FontWeight.w500, color: secondary),
                        ),
                        const SizedBox(height: 28),
                        const SplashIllustration(),
                        const SizedBox(height: 28),
                        Text(
                          'كل خدمة ... لها حقك',
                          style: AppTextStyles.style(20, FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'سجّل - تابع - احصل على مستحقاتك',
                          style: AppTextStyles.style(15, FontWeight.w500, color: secondary),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 24,
            end: 24,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 24),
              child: FilledButton(
                onPressed: _starting ? null : _start,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.white70,
                ),
                child: const Text('ابدأ'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// موجة متدرجة من الأزرق إلى الأخضر أسفل الشاشة كما في التصميم.
class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final top = size.height - 150;
    final soft = Path()
      ..moveTo(0, top - 30)
      ..quadraticBezierTo(size.width * 0.45, top + 60, size.width, top - 40)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(soft, Paint()..color = AppColors.primarySoft);

    final wave = Path()
      ..moveTo(0, top + 10)
      ..quadraticBezierTo(size.width * 0.5, top + 100, size.width, top + 10)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary, Color(0xFF1E74F0), Color(0xFF14B88A)],
        ).createShader(Rect.fromLTWH(0, top, size.width, size.height - top)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
