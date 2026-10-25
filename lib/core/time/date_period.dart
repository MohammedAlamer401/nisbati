import 'package:flutter/foundation.dart';

import '../formatting/date_formatter.dart';

/// نوع الفترة الزمنية (القسم 5.2).
enum PeriodKind {
  all('كل الفترات'),
  thisMonth('هذا الشهر'),
  lastMonth('الشهر السابق'),
  thisYear('هذه السنة'),
  custom('فترة مخصصة');

  const PeriodKind(this.label);
  final String label;
}

/// فترة بتاريخين شاملين (بلا وقت). [all] بلا حدود.
@immutable
class DatePeriod {
  const DatePeriod._(this.kind, this.start, this.end);

  factory DatePeriod.of(PeriodKind kind, {DateTime? today, DateTime? start, DateTime? end}) {
    final now = today ?? DateFormatter.today();
    return switch (kind) {
      PeriodKind.all => const DatePeriod._(PeriodKind.all, null, null),
      PeriodKind.thisMonth => DatePeriod._(kind, DateTime(now.year, now.month), DateTime(now.year, now.month + 1, 0)),
      PeriodKind.lastMonth => DatePeriod._(kind, DateTime(now.year, now.month - 1), DateTime(now.year, now.month, 0)),
      PeriodKind.thisYear => DatePeriod._(kind, DateTime(now.year), DateTime(now.year, 12, 31)),
      PeriodKind.custom => DatePeriod._(kind, start!, end!),
    };
  }

  static const all = DatePeriod._(PeriodKind.all, null, null);

  final PeriodKind kind;
  final DateTime? start;
  final DateTime? end;

  /// حدود التخزين `YYYY-MM-DD` للمقارنة النصية في SQL.
  String? get startKey => start == null ? null : DateFormatter.toStorage(start!);
  String? get endKey => end == null ? null : DateFormatter.toStorage(end!);

  bool contains(DateTime date) =>
      (start == null || !date.isBefore(start!)) && (end == null || !date.isAfter(end!));

  /// نص العرض: اسم الفترة، أو تاريخاها للمخصصة.
  String get label => kind == PeriodKind.custom
      ? '${DateFormatter.short(start!)} – ${DateFormatter.short(end!)}'
      : kind.label;

  @override
  bool operator ==(Object other) =>
      other is DatePeriod && other.kind == kind && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(kind, start, end);
}
