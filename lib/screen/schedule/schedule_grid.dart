import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/half_screen_sheet.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/guest/webview_page.dart';
import 'package:fzu_assistant/screen/schedule/course_card.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

const _maxPeriod = 11;
const _headerHeight = 48.0;
const _labelWidth = 44.0;
const _minCellHeight = 52.0;

const _timeSlots = [
  ('8:20', '9:05'),
  ('9:15', '10:00'),
  ('10:20', '11:05'),
  ('11:15', '12:00'),
  ('14:00', '14:45'),
  ('14:55', '15:40'),
  ('15:50', '16:35'),
  ('16:45', '17:30'),
  ('19:00', '19:45'),
  ('19:55', '20:40'),
  ('20:50', '21:35'),
];

List<String> _weekdays(AppLocalizations l10n) => [
  l10n.monday,
  l10n.tuesday,
  l10n.wednesday,
  l10n.thursday,
  l10n.friday,
  l10n.saturday,
  l10n.sunday,
];

class ScheduleGrid extends StatelessWidget {
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
    final minGridHeight = _maxPeriod * _minCellHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight - _headerHeight;
        final canFill = available >= minGridHeight;
        final cellHeight = canFill ? available / _maxPeriod : _minCellHeight;
        final gridHeight = _maxPeriod * cellHeight;

        final weekDates = <DateTime>[];
        if (firstMonday != null) {
          final monday = firstMonday!.add(Duration(days: (week - 1) * 7));
          for (var i = 0; i < 7; i++) {
            weekDates.add(monday.add(Duration(days: i)));
          }
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final nowMinutes = now.hour * 60 + now.minute;

        final weekdays = _weekdays(AppLocalizations.of(context)!);

        final content = Column(
          children: [
            // 顶部星期行
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  const SizedBox(width: _labelWidth),
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
                    width: _labelWidth,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      children: [
                        for (var p = 0; p < _maxPeriod; p++)
                          _buildPeriodLabel(context, p, cellHeight, nowMinutes),
                      ],
                    ),
                  ),
                  // 课程卡片
                  Positioned(
                    left: _labelWidth,
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
              height: canFill ? gridHeight + _headerHeight : null,
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
    final scheme = Theme.of(context).colorScheme;
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isToday ? scheme.onPrimaryContainer : null,
            ),
          ),
          Text(
            '${date.month}/${date.day}',
            style: TextStyle(
              fontSize: 10,
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
    int nowMinutes,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final slot = _timeSlots[index];
    final startParts = slot.$1.split(':');
    final endParts = slot.$2.split(':');
    final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final isCurrent = nowMinutes >= startMin && nowMinutes <= endMin;

    return SizedBox(
      width: _labelWidth,
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
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isCurrent ? scheme.onPrimaryContainer : null,
              ),
            ),
            Text(
              '${slot.$1}\n${slot.$2}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 7.5,
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
    double cellHeight,
  ) {
    final cards = <Widget>[];
    final autoAdjust = AppSettingsProvider.of(context).autoAdjustCourse.value;

    for (final c in courses) {
      // 收集本周该星期被调课取消的节次范围
      final canceledSlots = <(int, int)>[];
      // 收集本周该星期的调课新增
      final adjustedSlots = <CourseAdjustRule>[];

      if (autoAdjust) {
        for (final a in c.adjustRules) {
          // 原位置被调走（显式取消 或 普通调课的原位置）
          if (a.oldWeek == week && a.oldWeekday == wd) {
            canceledSlots.add((a.oldStartClass, a.oldEndClass));
          }
          // 调课目标位置
          if (a.newWeek == week && a.newWeekday == wd) {
            adjustedSlots.add(a);
          }
        }
      }

      for (final r in c.scheduleRules) {
        if (r.weekday != wd) continue;
        if (r.startWeek > week || r.endWeek < week) continue;
        if (r.single && !r.double && week % 2 == 0) continue;
        if (r.double && !r.single && week % 2 == 1) continue;
        if (r.startClass < 1 || r.startClass > _maxPeriod) continue;

        // 检查是否被调课取消
        final isCanceled = canceledSlots.any(
          (slot) => r.startClass == slot.$1 && r.endClass == slot.$2,
        );
        if (isCanceled) continue;

        final end = r.endClass > _maxPeriod ? _maxPeriod : r.endClass;
        final top = (r.startClass - 1) * cellHeight;
        final height = (end - r.startClass + 1) * cellHeight;

        cards.add(
          Positioned(
            top: top + 1,
            left: 2,
            right: 2,
            height: height - 2,
            child: CourseCard(
              course: c,
              location: r.location,
              onTap: () => _showCourseDetail(context, c, r.location),
            ),
          ),
        );
      }

      // 绘制调课新增的卡片
      for (final a in adjustedSlots) {
        if (a.newStartClass < 1 || a.newStartClass > _maxPeriod) continue;
        final end = a.newEndClass > _maxPeriod ? _maxPeriod : a.newEndClass;
        final top = (a.newStartClass - 1) * cellHeight;
        final height = (end - a.newStartClass + 1) * cellHeight;

        final adjustedCourse = Course(
          type: c.type,
          name: '[调课]${c.name}',
          credits: c.credits,
          electiveType: c.electiveType,
          examType: c.examType,
          teacher: c.teacher,
          scheduleRules: c.scheduleRules,
          adjustRules: c.adjustRules,
          rawExamTime: c.rawExamTime,
          remark: c.remark,
          syllabus: c.syllabus,
          lessonplan: c.lessonplan,
        );
        cards.add(
          Positioned(
            top: top + 1,
            left: 2,
            right: 2,
            height: height - 2,
            child: CourseCard(
              course: adjustedCourse,
              location: a.newLocation,
              onTap: () =>
                  _showCourseDetail(context, adjustedCourse, a.newLocation),
            ),
          ),
        );
      }
    }
    // 渲染考试卡片
    if (firstMonday != null &&
        AppSettingsProvider.of(context).showExamOnSchedule.value) {
      for (final exam in examRooms) {
        final examDate = _parseExamDate(exam.date);
        if (examDate == null) continue;

        final examWeekday = examDate.weekday;
        if (examWeekday != wd) continue;

        final examWeek = examDate.difference(firstMonday!).inDays ~/ 7 + 1;
        if (examWeek != week) continue;

        final (startClass, endClass) = _mapExamTimeToPeriods(exam.time);
        if (startClass < 1 || startClass > _maxPeriod) continue;

        final end = endClass > _maxPeriod ? _maxPeriod : endClass;
        final top = (startClass - 1) * cellHeight;
        final height = (end - startClass + 1) * cellHeight;

        final examCourse = Course(
          type: '',
          name: '[考试]${exam.courseName}',
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
          Positioned(
            top: top + 1,
            left: 2,
            right: 2,
            height: height - 2,
            child: CourseCard(
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

  static DateTime? _parseExamDate(String dateStr) {
    final match = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(dateStr);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// 将考试时间（如 "12:30-17:30"）映射到课表节次
  static (int, int) _mapExamTimeToPeriods(String timeStr) {
    final match = RegExp(
      r'(\d{1,2}):(\d{2})\s*[-–]\s*(\d{1,2}):(\d{2})',
    ).firstMatch(timeStr);
    if (match == null) return (0, 0);
    final startMin =
        int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
    final endMin = int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);

    int? startPeriod;
    int? endPeriod;

    for (var i = 0; i < _timeSlots.length; i++) {
      final slot = _timeSlots[i];
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

  void _showCourseDetail(BuildContext context, Course course, String location) {
    showHalfScreenSheet(
      context,
      builder: (controller) => ListView(
        controller: controller,
        children: [
          ListTile(
            title: Text(
              course.name,
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
              onTap: () => context.push(WebViewPage(url: course.syllabus)),
            ),
          if (course.lessonplan.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('授课计划'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(WebViewPage(url: course.lessonplan)),
            ),
        ],
      ),
    );
  }
}
