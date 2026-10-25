import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// شعار «نسبتي»: مستند أزرق، وقلم أخضر مائل، ودائرة نسبة مئوية.
/// مرسوم بالكود حتى يبقى حاداً بأي حجم دون ملفات صور.
class NisbatiLogo extends StatelessWidget {
  const NisbatiLogo({super.key, this.size = 140});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'شعار نسبتي',
      child: CustomPaint(size: Size.square(size), painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  static const _blueLight = Color(0xFF1E74F0);
  static const _greenLight = Color(0xFF2BBF86);

  @override
  void paint(Canvas canvas, Size size) {
    // الرسم بوحدات 120×120 ثم التكبير.
    canvas.scale(size.width / 120, size.height / 120);
    const bounds = Rect.fromLTWH(0, 0, 120, 120);

    // إطار المستند: مفتوح من الزاوية السفلى اليمنى حيث يمر القلم.
    final frame = Path()
      ..moveTo(74, 10)
      ..lineTo(26, 10)
      ..arcToPoint(const Offset(10, 26), radius: const Radius.circular(16), clockwise: false)
      ..lineTo(10, 84)
      ..arcToPoint(const Offset(26, 100), radius: const Radius.circular(16), clockwise: false)
      ..lineTo(36, 100);
    canvas.drawPath(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_blueLight, AppColors.primaryDark],
        ).createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // أسطر المستند.
    final lines = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(30, 32), const Offset(68, 32), lines);
    canvas.drawLine(const Offset(30, 46), const Offset(58, 46), lines);
    canvas.drawLine(const Offset(30, 60), const Offset(46, 60), lines);

    // القلم الأخضر المائل، بحافة بيضاء تفصله عن الإطار.
    final pen = Path()
      ..moveTo(36, 108)
      ..lineTo(90, 18)
      ..quadraticBezierTo(98, 8, 106, 14)
      ..quadraticBezierTo(110, 22, 102, 30)
      ..lineTo(54, 108)
      ..close();
    canvas.drawPath(
      pen,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      pen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_greenLight, AppColors.success],
        ).createShader(bounds),
    );

    // دائرة النسبة المئوية.
    const center = Offset(92, 90);
    canvas.drawCircle(center, 25, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      21,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_greenLight, AppColors.success],
        ).createShader(Rect.fromCircle(center: center, radius: 21)),
    );
    final percent = TextPainter(
      text: TextSpan(text: '%', style: AppTextStyles.style(26, FontWeight.w800, color: Colors.white, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    percent.paint(canvas, center - Offset(percent.width / 2, percent.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
