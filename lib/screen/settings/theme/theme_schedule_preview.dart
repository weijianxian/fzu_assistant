import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/app_theme_background.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/screen/schedule/widgets/schedule_grid.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

/// The real portrait timetable, laid out at phone size before being scaled.
/// Only local inputs are read; draft themes never become application settings.
class ThemeSchedulePreview extends HookWidget {
  const ThemeSchedulePreview({
    super.key,
    required this.theme,
    this.maxHeight = 400,
  });

  final ThemeData theme;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final api = ApiClient.instance;
    final account = api.studentId ?? '';
    final term = useValueListenable(settings.selectedSemesterKey);
    final cacheRevision = useValueListenable(CacheHelper.changes);
    final cachedSession = useValueListenable(api.usingCachedSession);
    final adjustments = useValueListenable(settings.west2AdjustmentsAccess);
    final custom = useValueListenable(CustomCourseStore.instance);
    useValueListenable(settings.autoAdjustCourse);
    useValueListenable(settings.showExamOnSchedule);
    final pending = useMemoized(
      () => _loadSchedule(
        api.captureSession(),
        term,
        useWest2Adjustments: settings.useWest2Adjustments,
      ),
      [account, term, cacheRevision, cachedSession, adjustments],
    );
    // Do not retain a previous account/semester while a newer read is pending.
    final data = useFuture(pending, preserveState: false).data;
    final firstMonday = data?.firstMonday;
    final week = firstMonday == null
        ? 1
        : CourseService.getWeekFromFirstMonday(firstMonday);
    final courses = [
      ...?data?.courses,
      for (final entry in custom)
        if (entry.account == account && entry.term == (data?.term ?? term))
          entry.toCourse(),
    ];
    final media = MediaQuery.of(context);
    final size = media.size;
    final isPhone =
        (theme.platform == TargetPlatform.android ||
            theme.platform == TargetPlatform.iOS) &&
        size.shortestSide > 0 &&
        size.shortestSide < 600;
    final phone = isPhone
        ? Size(size.shortestSide, size.longestSide)
        : const Size(400, 800);
    final phoneTheme = theme.copyWith(
      platform: TargetPlatform.android,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label: l10n.themePreview,
      image: true,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(
                  constraints.maxWidth,
                  math.min(phone.width, maxHeight * phone.width / phone.height),
                );
                final borderRadius = BorderRadius.circular(width * 0.1);
                return Center(
                  child: Container(
                    key: const ValueKey('theme-preview-phone'),
                    width: width,
                    height: width * phone.height / phone.width,
                    foregroundDecoration: BoxDecoration(
                      borderRadius: borderRadius,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox.fromSize(
                          size: phone,
                          child: MediaQuery(
                            data: media.copyWith(
                              size: phone,
                              padding: EdgeInsets.zero,
                              viewPadding: EdgeInsets.zero,
                              viewInsets: EdgeInsets.zero,
                              systemGestureInsets: EdgeInsets.zero,
                            ),
                            child: Theme(
                              data: phoneTheme,
                              child: PrimaryScrollController.none(
                                child: AppThemeBackground(
                                  key: const ValueKey('theme-editor-preview'),
                                  child: AppScaffold(
                                    appBar: AppBar(
                                      automaticallyImplyLeading: false,
                                      title: Text(l10n.weekN(week)),
                                    ),
                                    body: ScheduleGrid(
                                      term: data?.term ?? term,
                                      courses: courses,
                                      examRooms: data?.exams ?? const [],
                                      week: week,
                                      firstMonday: firstMonday,
                                      onRefresh: () async {},
                                    ),
                                    bottomNavigationBar: NavigationBar(
                                      selectedIndex: 0,
                                      destinations: [
                                        NavigationDestination(
                                          icon: const Icon(Icons.home_outlined),
                                          selectedIcon: const Icon(Icons.home),
                                          label: l10n.navSchedule,
                                        ),
                                        NavigationDestination(
                                          icon: const Icon(
                                            Icons.build_outlined,
                                          ),
                                          label: l10n.navToolbox,
                                        ),
                                        NavigationDestination(
                                          icon: const Icon(Icons.qr_code),
                                          label: l10n.campusCode,
                                        ),
                                        NavigationDestination(
                                          icon: const Icon(
                                            Icons.person_outline,
                                          ),
                                          label: l10n.navMy,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewSchedule {
  const _PreviewSchedule({
    required this.term,
    required this.firstMonday,
    required this.courses,
    required this.exams,
  });

  final String term;
  final DateTime? firstMonday;
  final List<Course> courses;
  final List<ExamRoomInfo> exams;
}

Future<_PreviewSchedule> _loadSchedule(
  AcademicSessionGuard session,
  String preferredTerm, {
  required bool useWest2Adjustments,
}) async {
  final maps = await Future.wait([
    CacheHelper.loadMap(SpKeys.cacheSchoolCalendar),
    CacheHelper.loadMap(SpKeys.cacheCoursesMap),
    CacheHelper.loadMap(SpKeys.cacheExamRoomsMap),
    if (useWest2Adjustments)
      CacheHelper.loadMap(SpKeys.cacheHolidayAdjustmentsMap),
  ]);
  session.check();
  final calendar = maps[0].isEmpty ? null : SchoolCalendar.fromJson(maps[0]);
  final term = preferredTerm.isNotEmpty
      ? preferredTerm
      : calendar == null
      ? (maps[1].keys.toList()..sort()).lastOrNull ?? ''
      : AcademicService.getCurrentTermFromCalendar(calendar);
  final calendarTerm = calendar?.terms
      .where((entry) => entry.term == term)
      .firstOrNull;
  final hasAccount = session.account?.isNotEmpty == true;
  final cached = hasAccount ? maps[1][term] : null;
  var courses = cached is Map && cached['courses'] is List
      ? (cached['courses'] as List)
            .map(
              (row) => Course.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList()
      : <Course>[];
  if (useWest2Adjustments) {
    courses = CourseService.applyHolidayAdjustments(
      courses,
      (maps[3][term] as List?) ?? const [],
    );
  }
  final exams = hasAccount ? maps[2][term] : null;
  return _PreviewSchedule(
    term: term,
    firstMonday: calendarTerm == null
        ? null
        : CourseService.getFirstMondayFromTerm(calendarTerm),
    courses: courses,
    exams: exams is List
        ? exams
              .map(
                (row) => ExamRoomInfo.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList()
        : const [],
  );
}
