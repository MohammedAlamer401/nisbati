import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../auth/application/auth_controller.dart';

/// هيكل خطوات التشغيل الأول: مؤشر «1 من 5» ومحتوى قابل للتمرير (القسم 6.2).
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({super.key, required this.step, required this.child});

  final OnboardingStep step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: step.number / OnboardingStep.total,
                        minHeight: 6,
                        backgroundColor: AppColors.primarySoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${step.number} من ${OnboardingStep.total}', style: AppTextStyles.caption),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// عنوان الخطوة ووصفها.
class StepHeading extends StatelessWidget {
  const StepHeading({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTextStyles.screenTitle, textAlign: TextAlign.center),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
