// يولّد صور أيقونة التطبيق في assets/icon/ من رسم برمجي.
// التشغيل: flutter test tool/generate_app_icon_test.dart
// ثم: dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _blue = Color(0xFF1E6FF0);
const _blueDark = Color(0xFF1846B8);
const _green = Color(0xFF14B88A);
const _ink = Color(0xFF2457C5);

/// خلفية متدرجة من الأزرق (أعلى اليسار) إلى الأخضر (أسفل اليمين).
void _paintBackground(Canvas canvas) {
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_blue, _blueDark, _green],
        stops: [0, 0.55, 1],
      ).createShader(rect),
  );
}

/// الرمز: مستند أبيض بأسطر وأعمدة بيانية، تحته قوس أخضر صاعد.
/// [scale] يصغّر الرمز حول المركز (لمنطقة الأمان في أيقونة Android التكيفية).
void _paintGlyph(Canvas canvas, {double scale = 1}) {
  canvas.save();
  canvas.translate(_size / 2, _size / 2);
  canvas.scale(scale);
  canvas.translate(-_size / 2, -_size / 2);
  canvas.translate(0, 52);

  // المستند مائل قليلاً.
  canvas.save();
  canvas.translate(512, 420);
  canvas.rotate(-0.08);
  canvas.translate(-512, -420);
  const doc = Rect.fromLTRB(318, 190, 706, 650);
  canvas.drawShadow(Path()..addRRect(RRect.fromRectAndRadius(doc, const Radius.circular(56))),
      Colors.black, 18, false);
  canvas.drawRRect(RRect.fromRectAndRadius(doc, const Radius.circular(56)), Paint()..color = Colors.white);

  final line = Paint()
    ..color = _ink
    ..strokeWidth = 40
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(const Offset(390, 290), const Offset(600, 290), line);
  canvas.drawLine(const Offset(390, 370), const Offset(540, 370), line);
  canvas.drawLine(const Offset(390, 450), const Offset(480, 450), line);

  // الأعمدة البيانية المتصاعدة.
  final bars = [
    (const Rect.fromLTRB(470, 520, 520, 600), const Color(0xFF2BBF86)),
    (const Rect.fromLTRB(545, 470, 595, 600), const Color(0xFF3B8CF5)),
    (const Rect.fromLTRB(620, 410, 670, 600), _ink),
  ];
  for (final (rect, color) in bars) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), Paint()..color = color);
  }
  canvas.restore();

  // القوس: هلال يحتضن المستند من الأسفل ويصعد يميناً.
  final swoosh = Path()
    ..moveTo(230, 560)
    ..cubicTo(250, 790, 640, 820, 800, 470)
    ..cubicTo(830, 420, 840, 380, 830, 350)
    ..cubicTo(760, 560, 560, 760, 340, 650)
    ..cubicTo(290, 625, 255, 600, 230, 560)
    ..close();
  canvas.drawPath(
    swoosh,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, Color(0xFFB8F2DC), Color(0xFF2FD39C)],
        stops: [0, 0.6, 1],
      ).createShader(const Rect.fromLTRB(230, 350, 840, 800)),
  );

  canvas.restore();
}

Future<void> _save(String path, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).create(recursive: true);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate app icon images', (tester) async {
    await tester.runAsync(() async {
      // iOS ولـ Android القديم: مربع كامل بلا شفافية (النظام يقص الزوايا).
      await _save('assets/icon/app_icon.png', (c) {
        _paintBackground(c);
        _paintGlyph(c);
      });
      // Android التكيفية: الرمز داخل منطقة الأمان (66%) على خلفية شفافة.
      await _save('assets/icon/app_icon_foreground.png', (c) => _paintGlyph(c, scale: 0.62));
      await _save('assets/icon/app_icon_background.png', _paintBackground);
    });
  });
}
