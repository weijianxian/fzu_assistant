import 'package:flutter/material.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/widgets/toolbox_menu.dart';

class ToolboxPage extends HookWidget {
  const ToolboxPage({super.key, this.isActive = true});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final paperAccess = useValueListenable(
      AppSettingsProvider.of(context).papersAccess,
    );

    final sections = [
      (
        l10n.gradesAndCredits,
        [
          (
            Icons.notifications_active_outlined,
            l10n.academicChanges,
            l10n.academicChangesSubtitle,
            AppRoutes.academicChanges,
          ),
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
          (
            Icons.menu_book_outlined,
            l10n.cultivatePlan,
            l10n.cultivatePlanDescription,
            AppRoutes.cultivatePlan,
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
          if (paperAccess != FeatureAccess.hide)
            (
              Icons.folder_copy_outlined,
              l10n.pastPapers,
              paperAccess == FeatureAccess.allow
                  ? l10n.pastPapersDescription
                  : l10n.thirdPartyDisabled,
              AppRoutes.papers,
            ),
          (
            Icons.class_outlined,
            l10n.emptyClassroom,
            l10n.emptyClassroomSubtitle,
            AppRoutes.emptyRoom,
          ),
          (
            Icons.view_timeline_outlined,
            l10n.classroomUsage,
            l10n.classroomUsageSubtitle,
            AppRoutes.classroomUsage,
          ),
        ],
      ),
      (
        l10n.campusInfo,
        [
          (
            Icons.local_library_outlined,
            l10n.learningCenter,
            l10n.learningReserveSubtitle,
            AppRoutes.learningCenter,
          ),
          (
            Icons.notifications_outlined,
            l10n.officeNotice,
            l10n.officeNoticeSubtitle,
            AppRoutes.notice,
          ),
          (
            Icons.work_outline,
            l10n.jobFairTitle,
            l10n.jobFairDescription,
            AppRoutes.jobFair,
          ),
          (
            Icons.record_voice_over_outlined,
            l10n.jiaxiLectures,
            l10n.lecturesDescription,
            AppRoutes.lectures,
          ),
          (
            Icons.rate_review_outlined,
            l10n.evaluation,
            l10n.evaluationSubtitle,
            AppRoutes.evaluation,
          ),
          (
            Icons.open_in_browser_outlined,
            l10n.academicShortcuts,
            l10n.academicShortcutsSubtitle,
            AppRoutes.academicShortcuts,
          ),
          (
            Icons.apartment_outlined,
            l10n.campusServices,
            l10n.campusServicesDescription,
            AppRoutes.campusServices,
          ),
          (
            Icons.water_drop_outlined,
            l10n.utilityPayment,
            l10n.utilityDescription,
            AppRoutes.utilityPayment,
          ),
        ],
      ),
    ];

    final destinations = [
      for (final section in sections)
        NavigationPaneSection(
          title: section.$1,
          destinations: [
            for (final tile in section.$2)
              NavigationPaneDestination(
                icon: tile.$1,
                title: tile.$2,
                subtitle: tile.$3,
                route: tile.$4,
                menuTitle: switch (tile.$4) {
                  AppRoutes.emptyRoom => l10n.toolboxEmptyRoomTitle,
                  AppRoutes.jobFair => l10n.toolboxJobFairTitle,
                  AppRoutes.classroomUsage => l10n.toolboxClassroomUsageTitle,
                  AppRoutes.academicShortcuts =>
                    l10n.toolboxAcademicShortcutsTitle,
                  _ => tile.$2,
                },
              ),
          ],
        ),
    ];

    if (context.isLandscape) {
      return SplitNavigationPage(
        title: l10n.navToolbox,
        sections: destinations,
        initialRoute: AppRoutes.gpa,
        onGenerateRoute: AppRouter.onGenerateRoute,
        isActive: isActive,
        navigationBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
        menuBuilder: (context, selectedRoute, onSelected) => ToolboxMenu(
          sections: destinations,
          selectedRoute: selectedRoute,
          onSelected: onSelected,
        ),
      );
    }

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.navToolbox)),
      body: ToolboxMenu(
        sections: destinations,
        onSelected: (route) => context.pushNamed(route),
      ),
    );
  }
}
