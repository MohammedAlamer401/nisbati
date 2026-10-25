import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// رسم شاشة الإقلاع: حافظة مستندات، ونقود بالدينار، ودائرة نسبة، وأوراق نبات.
class SplashIllustration extends StatelessWidget {
  const SplashIllustration({super.key});

  static const _gold = Color(0xFFF6BC2F);
  static const _goldDark = Color(0xFFE09A12);
  static const _leaf = Color(0xFFA8E0C8);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 240,
        height: 170,
        // الرسم ثابت الاتجاه بغض النظر عن RTL.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // هالة خلفية وظل أرضي.
              Positioned(
                left: 20,
                top: 20,
                child: Container(
                  width: 200,
                  height: 130,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 0,
                child: Container(
                  width: 220,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              // أوراق النبات.
              Positioned(left: 4, top: 52, child: _leafShape(-0.5)),
              Positioned(right: 4, top: 58, child: _leafShape(0.5)),
              // الحافظة.
              Positioned(
                left: 72,
                top: 6,
                child: _Clipboard(),
              ),
              // النقود.
              Positioned(left: 38, bottom: 12, child: _coinStack()),
              Positioned(left: 82, bottom: 8, child: _frontCoin()),
              // دائرة النسبة.
              Positioned(
                right: 40,
                bottom: 12,
                child: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2BBF86), AppColors.success],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '%',
                    style: AppTextStyles.style(30, FontWeight.w800, color: Colors.white, height: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leafShape(double angle) => Transform.rotate(
        angle: angle,
        child: Container(
          width: 38,
          height: 72,
          decoration: BoxDecoration(
            color: _leaf.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.all(Radius.elliptical(19, 36)),
          ),
        ),
      );

  Widget _coinStack() => Column(
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 58,
              height: 16,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _goldDark, width: 1.2),
              ),
            ),
        ],
      );

  Widget _frontCoin() => Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _gold,
          shape: BoxShape.circle,
          border: Border.all(color: _goldDark, width: 2.5),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            'د.ل',
            style: AppTextStyles.style(16, FontWeight.w800, color: _goldDark, height: 1),
          ),
        ),
      );
}

class _Clipboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 132,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 10,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 26, 14, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFD3F6), width: 3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final width in [70.0, 60.0, 50.0]) ...[
                    Container(
                      width: width,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA9C3F2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 27,
            top: 0,
            child: Container(
              width: 50,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
