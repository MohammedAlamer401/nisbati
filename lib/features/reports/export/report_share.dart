import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// يحفظ الملف في المجلد المؤقت ثم يفتح قائمة المشاركة في النظام.
///
/// يعيد `false` إذا أغلق المستخدم القائمة دون مشاركة.
Future<bool> shareFile(Uint8List bytes, String fileName, String mimeType) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: fileName,
    ),
  );
  return result.status != ShareResultStatus.dismissed;
}
