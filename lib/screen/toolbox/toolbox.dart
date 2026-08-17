import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';

class ToolboxPage extends HookWidget {
  const ToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final sections = [
      (
        l10n.gradesAndCredits,
        [
          (
            Icons.school_outlined,
            l10n.gpaInfo,
            l10n.gpaInfoSubtitle,
            AppRoutes.gpa,
          ),
          (
            Icons.assignment_outlined,
            l10n.marksQuery,
            l10n.marksQuerySubtitle,
            AppRoutes.marks,
          ),
          (
            Icons.pie_chart_outline,
            l10n.creditStats,
            l10n.creditStatsSubtitle,
            AppRoutes.credit,
          ),
        ],
      ),
      (
        l10n.examsAndRooms,
        [
          (
            Icons.quiz_outlined,
            l10n.unifiedExam,
            l10n.unifiedExamSubtitle,
            AppRoutes.unifiedExam,
          ),
          (
            Icons.room_outlined,
            l10n.examRoom,
            l10n.examRoomSubtitle,
            AppRoutes.examRoom,
          ),
          (
            Icons.class_outlined,
            l10n.emptyClassroom,
            l10n.emptyClassroomSubtitle,
            AppRoutes.emptyRoom,
          ),
        ],
      ),
      (
        l10n.campusInfo,
        [
          (
            Icons.notifications_outlined,
            l10n.officeNotice,
            l10n.officeNoticeSubtitle,
            AppRoutes.notice,
          ),
          (
            Icons.rate_review_outlined,
            l10n.evaluation,
            l10n.evaluationSubtitle,
            AppRoutes.evaluation,
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navToolbox)),
      body: CustomScrollView(
        slivers: [
          for (final section in sections)
            Section.sliver(
              title: section.$1,
              child: MasonrySliverGrid(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                childCount: section.$2.length,
                itemBuilder: (context, i) {
                  final tile = section.$2[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(tile.$1, size: 28),
                      title: Text(
                        tile.$2,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(tile.$3),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.pushNamed(tile.$4),
                    ),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}
