import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/masonry_sliver_grid.dart';
import 'package:fzu_assistant/common/widget/section.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/credit/credit_page.dart';
import 'package:fzu_assistant/screen/toolbox/empty_room/empty_room_page.dart';
import 'package:fzu_assistant/screen/toolbox/evaluation/evaluation_page.dart';
import 'package:fzu_assistant/screen/toolbox/exam_room/exam_room_page.dart';
import 'package:fzu_assistant/screen/toolbox/gpa/gpa_page.dart';
import 'package:fzu_assistant/screen/toolbox/marks/marks_page.dart';
import 'package:fzu_assistant/screen/toolbox/notice/notice_page.dart';
import 'package:fzu_assistant/screen/toolbox/unified_exam/unified_exam_page.dart';

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
            () => const GpaPage(),
          ),
          (
            Icons.assignment_outlined,
            l10n.marksQuery,
            l10n.marksQuerySubtitle,
            () => const MarksPage(),
          ),
          (
            Icons.pie_chart_outline,
            l10n.creditStats,
            l10n.creditStatsSubtitle,
            () => const CreditPage(),
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
            () => const UnifiedExamPage(),
          ),
          (
            Icons.room_outlined,
            l10n.examRoom,
            l10n.examRoomSubtitle,
            () => const ExamRoomPage(),
          ),
          (
            Icons.class_outlined,
            l10n.emptyClassroom,
            l10n.emptyClassroomSubtitle,
            () => const EmptyRoomPage(),
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
            () => const NoticePage(),
          ),
          (
            Icons.rate_review_outlined,
            l10n.evaluation,
            l10n.evaluationSubtitle,
            () => const EvaluationPage(),
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
                      onTap: () => context.push(tile.$4()),
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
