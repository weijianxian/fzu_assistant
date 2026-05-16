import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/masonry_sliver_grid.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/toolbox/credit/credit_page.dart';
import 'package:fzu_assistant/screen/toolbox/exam_room/exam_room_page.dart';
import 'package:fzu_assistant/screen/toolbox/gpa/gpa_page.dart';
import 'package:fzu_assistant/screen/toolbox/marks/marks_page.dart';
import 'package:fzu_assistant/screen/toolbox/unified_exam/unified_exam_page.dart';

class ToolboxPage extends HookWidget {
  const ToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final tileConfigs = [
      (Icons.school_outlined, l10n.gpaInfo, l10n.gpaInfoSubtitle, () => const GpaPage()),
      (Icons.assignment_outlined, l10n.marksQuery, l10n.marksQuerySubtitle, () => const MarksPage()),
      (Icons.quiz_outlined, l10n.unifiedExam, l10n.unifiedExamSubtitle, () => const UnifiedExamPage()),
      (Icons.room_outlined, l10n.examRoom, l10n.examRoomSubtitle, () => const ExamRoomPage()),
      (Icons.pie_chart_outline, l10n.creditStats, l10n.creditStatsSubtitle, () => const CreditPage()),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navToolbox)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _sectionHeader(l10n.academics)),
          MasonrySliverGrid(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            childCount: tileConfigs.length,
            itemBuilder: (context, index) {
              final cfg = tileConfigs[index];
              return _ToolTile(
                icon: cfg.$1,
                title: cfg.$2,
                subtitle: cfg.$3,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => cfg.$4()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
