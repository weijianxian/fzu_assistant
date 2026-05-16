import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.navToolbox)),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _sectionHeader(AppLocalizations.of(context)!.academics),
          _ToolTile(
            icon: Icons.school_outlined,
            title: AppLocalizations.of(context)!.gpaInfo,
            subtitle: AppLocalizations.of(context)!.gpaInfoSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GpaPage()),
            ),
          ),
          _ToolTile(
            icon: Icons.assignment_outlined,
            title: AppLocalizations.of(context)!.marksQuery,
            subtitle: AppLocalizations.of(context)!.marksQuerySubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MarksPage()),
            ),
          ),
          _ToolTile(
            icon: Icons.quiz_outlined,
            title: AppLocalizations.of(context)!.unifiedExam,
            subtitle: AppLocalizations.of(context)!.unifiedExamSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UnifiedExamPage()),
            ),
          ),
          _ToolTile(
            icon: Icons.room_outlined,
            title: AppLocalizations.of(context)!.examRoom,
            subtitle: AppLocalizations.of(context)!.examRoomSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExamRoomPage()),
            ),
          ),
          _ToolTile(
            icon: Icons.pie_chart_outline,
            title: AppLocalizations.of(context)!.creditStats,
            subtitle: AppLocalizations.of(context)!.creditStatsSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreditPage()),
            ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
