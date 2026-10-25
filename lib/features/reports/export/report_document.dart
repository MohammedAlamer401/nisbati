/// محتوى تقرير قابل للتصدير بصيغ مختلفة (القسم 10 — الشاشة 19).
class ReportDocument {
  const ReportDocument({
    required this.title,
    required this.slug,
    required this.periodLabel,
    required this.filtersLabel,
    required this.generatedAt,
    required this.summary,
    required this.columns,
    required this.rows,
    this.totals,
    this.numericColumns = const {},
  });

  final String title;

  /// جزء من اسم الملف، مثل «العملاء».
  final String slug;
  final String periodLabel;
  final String filtersLabel;
  final DateTime generatedAt;

  /// بطاقات الملخص (عنوان، قيمة).
  final List<(String, String)> summary;
  final List<String> columns;
  final List<List<String>> rows;
  final List<String>? totals;

  /// فهارس الأعمدة الرقمية (تُحاذى كالأرقام).
  final Set<int> numericColumns;
}

/// رأس التقارير من الملف الشخصي (القسم 6.7).
class ReportHeader {
  const ReportHeader({required this.name, this.business, this.phone, this.photo});

  final String name;
  final String? business;
  final String? phone;
  final List<int>? photo;
}
