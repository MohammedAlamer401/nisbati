import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nisbati/core/widgets/app_svg_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('كل أيقونات SVG موجودة في الأصول وتُحلَّل دون أخطاء', () async {
    for (final asset in AppSvgIcons.all) {
      final source = await rootBundle.loadString(asset);
      expect(source, contains('<svg'), reason: asset);
      final info = await vg.loadPicture(SvgStringLoader(source), null);
      expect(info.size.width, 64, reason: asset);
      info.picture.dispose();
    }
  });
}
