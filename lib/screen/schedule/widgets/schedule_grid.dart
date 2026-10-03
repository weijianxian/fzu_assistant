import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/common/utils/date_text.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/schedule/widgets/course_card.dart';
import 'package:fzu_assistant/screen/schedule/widgets/horizontal_schedule_grid.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

const _headerHeight = 48.0;
const _labelWidth = 44.0;
const _minCellHeight = 52.0;

List<String> _weekdays(AppLocalizations l10n) => [
  l10n.monday,
  l10n.tuesday,
  l10n.wednesday,
  l10n.thursday,
  l10n.friday,
  l10n.saturday,
  l10n.sunday,
];

class ScheduleGrid extends HookWidget {
  final List<Course> courses;
  final List<ExamRoomInfo> examRooms;
  final int week;
  final DateTime? firstMonday;
  final Future<void> Function() onRefresh;

  const ScheduleGrid({
    super.key,
    required this.courses,
    required this.examRooms,
    required this.week,
    required this.firstMonday,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = context.isLandscape;
    final minuteTick = useState(0);
    useEffect(() {
      if (!isLandscape) return null;
      final timer = Timer.periodic(const Duration(minutes: 1), (_) {
        minuteTick.value += 1;
      });
      return timer.cancel;
    }, [isLandscape]);

    final weekDates = <DateTime>[];
    if (firstMonday != null) {
      final monday = firstMonday!.add(Duration(days: (week - 1) * 7));
      for (var i = 0; i < 7; i++) {
        weekDates.add(monday.add(Duration(days: i)));
      }
    }
    final weekdays = _weekdays(AppLocalizations.of(context)!);
    if (isLandscape) {
      return HorizontalScheduleGrid(
        week: week,
        weekdays: weekdays,
        weekDates: weekDates,
        now: DateTime.now(),
        onRefresh: onRefresh,
        cardBuilder: (weekday, metrics) => _buildCards(
          context,
          courses,
          weekday,
          week,
          0,
          horizontalMetrics: metrics,
        ),
      );
    }

    final isWindows =
        !kIsWeb && Theme.of(context).platform == TargetPlatform.windows;
    final textScale = isWindows
        ? math.max(1.0, MediaQuery.textScalerOf(context).scale(14) / 14)
        : 1.0;
    final headerHeight = _headerHeight * textScale;
    final labelWidth = (isWindows ? 56.0 : _labelWidth) * textScale;
    final minCellHeight = _minCellHeight * textScale;
    final minGridHeight = maxCoursePeriod * minCellHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight - headerHeight;
        final canFill = available >= minGridHeight;
        final cellHeight = canFill
            ? available / maxCoursePeriod
            : minCellHeight;
        final gridHeight = maxCoursePeriod * cellHeight;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final nowMinutes = now.hour * 60 + now.minute;

        final content = Column(
          children: [
            // 顶部星期行
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  SizedBox(width: labelWidth),
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: weekDates.isNotEmpty
                            ? _buildDateHeader(
                                context,
                                weekdays[i],
                                weekDates[i],
                                weekDates[i] == today,
                              )
                            : Text(
                                weekdays[i],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
            // 网格区域
            SizedBox(
              height: gridHeight,
              child: Stack(
                children: [
                  // 左侧节次索引
                  Positioned(
                    left: 0,
                    width: labelWidth,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      children: [
                        for (var p = 0; p < maxCoursePeriod; p++)
                          _buildPeriodLabel(
                            context,
                            p,
                            cellHeight,
                            labelWidth,
                            nowMinutes,
                          ),
                      ],
                    ),
                  ),
                  // 课程卡片
                  Positioned(
                    left: labelWidth,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var wd = 1; wd <= 7; wd++)
                          Expanded(
                            child: SizedBox(
                              height: gridHeight,
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: _buildCards(
                                  context,
                                  courses,
                                  wd,
                                  week,
                                  cellHeight,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: canFill ? gridHeight + headerHeight : null,
              child: content,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateHeader(
    BuildContext context,
    String weekday,
    DateTime date,
    bool isToday,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isWindows = !kIsWeb && theme.platform == TargetPlatform.windows;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: isToday
          ? BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            weekday,
            style: TextStyle(
              fontSize: isWindows ? 13 : 12,
              fontWeight: isWindows ? FontWeight.w600 : FontWeight.bold,
              color: isToday ? scheme.onPrimaryContainer : null,
            ),
          ),
          Text(
            '${date.month}/${date.day}',
            style: TextStyle(
              fontSize: isWindows ? 11 : 10,
              color: isToday ? scheme.onPrimaryContainer : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodLabel(
    BuildContext context,
    int index,
    double cellHeight,
    double labelWidth,
    int nowMinutes,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isWindows = !kIsWeb && theme.platform == TargetPlatform.windows;
    final slot = coursePeriodTimes[index];
    final startParts = slot.$1.split(':');
    final endParts = slot.$2.split(':');
    final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final isCurrent = nowMinutes >= startMin && nowMinutes <= endMin;

    return SizedBox(
      width: labelWidth,
      height: cellHeight,
      child: Container(
        decoration: isCurrent
            ? BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: isWindows ? 12 : 11,
                fontWeight: FontWeight.w600,
                color: isCurrent ? scheme.onPrimaryContainer : null,
              ),
            ),
            Text(
              '${slot.$1}\n${slot.$2}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isWindows ? 10 : 7.5,
                height: 1.2,
                color: isCurrent ? scheme.onPrimaryContainer : scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCards(
    BuildContext context,
    List<Course> courses,
    int wd,
    int week,
    double cellHeight, {
    HorizontalScheduleMetrics? horizontalMetrics,
  }) {
    final cards = <Widget>[];
    final autoAdjust = AppSettingsProvider.of(context).autoAdjustCourse.value;

    final sessions = CourseSessions.forDay(
      courses: courses,
      week: week,
      weekday: wd,
      autoAdjust: autoAdjust,
    );
    final l10n = AppLocalizations.of(context)!;

    Widget positionCard(int start, int end, Widget child) {
      if (horizontalMetrics != null) {
        return Positioned(
          left: horizontalMetrics.start(start - 1) + 4,
          width:
              horizontalMetrics.end(end - 1) -
              horizontalMetrics.start(start - 1) -
              8,
          top: 6,
          bottom: 6,
          child: child,
        );
      }
      return Positioned(
        top: (start - 1) * cellHeight + 1,
        left: 2,
        right: 2,
        height: (end - start + 1) * cellHeight - 2,
        child: child,
      );
    }

    for (final session in sessions) {
      final displayName = session.adjusted
          ? '${l10n.adjustedMark}${session.course.name}'
          : session.course.name;

      cards.add(
        positionCard(
          session.startClass,
          session.endClass,
          CourseCard(
            isHorizontal: horizontalMetrics != null,
            course: session.course,
            location: session.location,
            displayName: displayName,
            onTap: () => _showCourseDetail(
              context,
              session.course,
              session.location,
              displayName: displayName,
            ),
          ),
        ),
      );
    }
    // 渲染考试卡片
    if (firstMonday != null &&
        AppSettingsProvider.of(context).showExamOnSchedule.value) {
      for (final exam in examRooms) {
        final examDate = DateText.parseChineseDate(exam.date);
        if (examDate == null) continue;

        final examWeekday = examDate.weekday;
        if (examWeekday != wd) continue;

        final examWeek = CourseService.getScheduleWeekForDate(
          firstMonday!,
          examDate,
        );
        if (examWeek != week) continue;

        final (startClass, endClass) = _mapExamTimeToPeriods(exam.time);
        if (startClass < 1 || startClass > maxCoursePeriod) continue;

        final end = endClass > maxCoursePeriod ? maxCoursePeriod : endClass;
        final examCourse = Course(
          type: '',
          name: '${l10n.scheduleExamMark}${exam.courseName}',
          credits: exam.credit,
          electiveType: '',
          examType: '',
          teacher: exam.teacher,
          scheduleRules: const [],
          adjustRules: const [],
          rawExamTime: '${exam.date} ${exam.time}',
          remark: '',
          syllabus: '',
          lessonplan: '',
        );
        cards.add(
          positionCard(
            startClass,
            end,
            CourseCard(
              isHorizontal: horizontalMetrics != null,
              course: examCourse,
              location: exam.location,
              onTap: () =>
                  _showCourseDetail(context, examCourse, exam.location),
            ),
          ),
        );
      }
    }

    return cards;
  }

  /// 将考试时间（如 "12:30-17:30"）映射到课表节次
  static (int, int) _mapExamTimeToPeriods(String timeStr) {
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*[-–]\s*(\d{1,2}):(\d{2})')
        .firstMatch(timeStr);
    if (match == null) return (0, 0);
    final startMin =
        int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
    final endMin = int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);

    int? startPeriod;
    int? endPeriod;

    for (var i = 0; i < coursePeriodTimes.length; i++) {
      final slot = coursePeriodTimes[i];
      final sParts = slot.$1.split(':');
      final eParts = slot.$2.split(':');
      final slotStart = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      final slotEnd = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);

      // 考试开始时间在此节次之前或之内 → 起始节次
      if (startPeriod == null && startMin <= slotEnd) {
        startPeriod = i + 1;
      }
      // 考试结束时间在此节次之内或之后 → 结束节次
      if (endMin >= slotStart) {
        endPeriod = i + 1;
      }
    }

    return (startPeriod ?? 0, endPeriod ?? 0);
  }

  void _showCourseDetail(
    BuildContext context,
    Course course,
    String location, {
    String? displayName,
  }) {
    showHalfScreenSheet(
      context,
      builder: (controller) => ListView(
        controller: controller,
        children: [
          ListTile(
            title: Text(
              displayName ?? course.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (course.teacher.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('教师'),
              subtitle: Text(course.teacher),
            ),
          if (location.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('地点'),
              subtitle: Text(location),
            ),
          if (course.credits.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('学分'),
              subtitle: Text(course.credits),
            ),
          if (course.rawExamTime.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('考试时间'),
              subtitle: Text(course.rawExamTime),
            ),
          if (course.remark.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('备注'),
              subtitle: Text(course.remark),
            ),
          if (course.electiveType.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('类型'),
              subtitle: Text(course.electiveType),
            ),
          if (course.examType.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.quiz),
              title: const Text('考试'),
              subtitle: Text(course.examType),
            ),
          if (course.syllabus.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('教学大纲'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed(
                AppRoutes.webview,
                arguments: WebViewArgs(url: course.syllabus),
              ),
            ),
          if (course.lessonplan.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('授课计划'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed(
                AppRoutes.webview,
                arguments: WebViewArgs(url: course.lessonplan),
              ),
            ),
        ],
      ),
    );
  }
}
