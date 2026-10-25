import 'package:flutter/material.dart';

import '../../core/widgets/empty_state.dart';

/// شاشة مؤقتة لأقسام لم تُنفَّذ بعد؛ تُستبدل في المراحل 4–8.
class SectionPlaceholderScreen extends StatelessWidget {
  const SectionPlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.emptyTitle,
    required this.phase,
  });

  final String title;
  final String icon;
  final String emptyTitle;
  final int phase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: EmptyState(
          icon: icon,
          title: emptyTitle,
          message: 'هذا القسم قيد التطوير (المرحلة $phase).',
        ),
      ),
    );
  }
}
