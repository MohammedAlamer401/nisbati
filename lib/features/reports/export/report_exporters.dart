import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/formatting/date_formatter.dart';
import 'report_document.dart';

/// CSV بترميز UTF-8 مع BOM ليفتح بالعربية في Excel.
abstract final class CsvExporter {
  static Uint8List build(ReportDocument doc) {
    String cell(String value) {
      final clean = _stripBidi(value);
      return RegExp(r'[",\n\r]').hasMatch(clean) ? '"${clean.replaceAll('"', '""')}"' : clean;
    }

    final lines = [
      doc.columns.map(cell).join(','),
      for (final row in doc.rows) row.map(cell).join(','),
      if (doc.totals != null) doc.totals!.map(cell).join(','),
    ];
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(lines.join('\r\n'))]);
  }
}

/// PDF عربي مرتب للطباعة والمشاركة، برأس من الملف الشخصي.
abstract final class PdfExporter {
  static Future<Uint8List> build(ReportDocument doc, {required ReportHeader header, required ByteData font}) {
    final arabic = pw.Font.ttf(font);
    final base = pw.TextStyle(font: arabic, fontSize: 10);
    final pdf = pw.Document(title: doc.title, author: header.name, creator: 'نسبتي');
    const primary = PdfColor.fromInt(0xFF2457C5);
    const border = PdfColor.fromInt(0xFFE3E8F0);
    const soft = PdfColor.fromInt(0xFFE6EDFA);
    const secondary = PdfColor.fromInt(0xFF697386);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabic, bold: arabic),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (header.photo != null)
                  pw.Container(
                    width: 44,
                    height: 44,
                    margin: const pw.EdgeInsets.only(left: 10),
                    child: pw.ClipOval(
                      child: pw.Image(pw.MemoryImage(Uint8List.fromList(header.photo!)), fit: pw.BoxFit.cover),
                    ),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(header.name, style: base.copyWith(fontSize: 14, color: primary)),
                      if (header.business != null) pw.Text(header.business!, style: base.copyWith(color: secondary)),
                      if (header.phone != null)
                        pw.Text(
                          header.phone!,
                          style: base.copyWith(color: secondary),
                          textDirection: pw.TextDirection.ltr,
                        ),
                    ],
                  ),
                ),
                pw.Text('نسبتي', style: base.copyWith(fontSize: 16, color: primary)),
              ],
            ),
            pw.Divider(color: border),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'أُنشئ في ${DateFormatter.short(doc.generatedAt)}',
              style: base.copyWith(fontSize: 8, color: secondary),
            ),
            pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: base.copyWith(fontSize: 8, color: secondary),
            ),
          ],
        ),
        build: (context) => [
          pw.Text(doc.title, style: base.copyWith(fontSize: 18)),
          pw.SizedBox(height: 4),
          pw.Text('الفترة: ${_pdfText(doc.periodLabel)}', style: base.copyWith(color: secondary)),
          if (doc.filtersLabel.isNotEmpty)
            pw.Text('الفلاتر: ${_pdfText(doc.filtersLabel)}', style: base.copyWith(color: secondary)),
          pw.SizedBox(height: 12),
          if (doc.summary.isNotEmpty)
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value) in doc.summary)
                  pw.Container(
                    width: 120,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(color: soft, borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(label, style: base.copyWith(fontSize: 8, color: secondary)),
                        pw.Text(_pdfText(value), style: base.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
          pw.SizedBox(height: 14),
          if (doc.rows.isEmpty)
            pw.Text('لا توجد بيانات في هذه الفترة', style: base.copyWith(color: secondary))
          else
            pw.TableHelper.fromTextArray(
              headers: doc.columns.map(_pdfHeader).toList(),
              data: [
                for (final row in doc.rows) row.map(_pdfText).toList(),
                if (doc.totals != null) doc.totals!.map(_pdfText).toList(),
              ],
              headerStyle: base.copyWith(color: PdfColors.white, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: primary),
              cellStyle: base.copyWith(fontSize: 9),
              columnWidths: {
              for (final (i, column) in doc.columns.indexed) i: _columnWidth(column, doc.numericColumns.contains(i)),
            },
            cellAlignment: pw.Alignment.centerRight,
              cellAlignments: {for (final i in doc.numericColumns) i: pw.Alignment.centerLeft},
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: border, width: 0.5),
                bottom: pw.BorderSide(color: border, width: 0.5),
              ),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F8FC)),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            ),
        ],
      ),
    );
    return pdf.save();
  }
}

/// عرض الأعمدة: التاريخ والنسبة بعرض ثابت حتى لا ينكسرا، والنصوص أعرض من الأرقام.
pw.TableColumnWidth _columnWidth(String column, bool numeric) => switch (column) {
      'التاريخ' => const pw.FixedColumnWidth(64),
      'النسبة' => const pw.FixedColumnWidth(46),
      'الطريقة' || 'الخدمات' => const pw.FixedColumnWidth(54),
      _ => pw.FlexColumnWidth(numeric ? 1.15 : 1.35),
    };

/// يحذف علامات عزل الاتجاه المستخدمة في واجهة التطبيق (لا تلزم في الملفات).
final _bidiMarks = RegExp('[${String.fromCharCode(0x2066)}-${String.fromCharCode(0x2069)}]');

String _stripBidi(String value) => value.replaceAll(_bidiMarks, '');

/// اسم الملف: `نسبتي_تقرير-العملاء_2026-10-25.pdf`.
String reportFileName(ReportDocument doc, String extension) =>
    'نسبتي_تقرير-${doc.slug}_${DateFormatter.toStorage(doc.generatedAt)}.$extension';

/// نص الخلية في PDF: بلا علامات اتجاه ولا تشكيل؛ مكتبة pdf تحذف المسافة
/// قبل كلمة فيها شدة (مثل «غير محصّل»).
final _diacritics = RegExp('[${String.fromCharCode(0x064B)}-${String.fromCharCode(0x065F)}${String.fromCharCode(0x0670)}]');

String _pdfText(String value) => _stripBidi(value).replaceAll(_diacritics, '');

/// رأس العمود: الوحدة «(د.ل)» في سطر مستقل حتى لا ينكسر الاسم العربي.
String _pdfHeader(String column) => _pdfText(column).replaceFirst(' (', '\n(');
