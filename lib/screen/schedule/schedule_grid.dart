import 'package:flutter/material.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/screen/schedule/course_card.dart';

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
  final int week;
  final DateTime? firstMonday;

  const ScheduleGrid({
    super.key,
    required this.courses,
    required this.week,
    required this.firstMonday,
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
                          SizedBox(
                            height: cellHeight,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${p + 1}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_timeSlots[p].$1}\n${_timeSlots[p].$2}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    height: 1.2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

        if (canFill) return content;
        return SingleChildScrollView(child: content);
      },
    );
  }

  Widget _buildDateHeader(String weekday, DateTime date, bool isToday) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          weekday,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          '${date.month}/${date.day}',
          style: TextStyle(fontSize: 10, color: isToday ? null : Colors.grey),
        ),
      ],
    );
  }

  List<Widget> _buildCards(
    List<Course> courses,
    int wd,
    int week,
    double cellHeight,
  ) {
    final cards = <Widget>[];
    for (final c in courses) {
      for (final r in c.scheduleRules) {
        if (r.weekday != wd) continue;
        if (r.startWeek > week || r.endWeek < week) continue;
        if (r.single && !r.double && week % 2 == 0) continue;
        if (r.double && !r.single && week % 2 == 1) continue;
        if (r.startClass < 1 || r.startClass > _maxPeriod) continue;

        final end = r.endClass > _maxPeriod ? _maxPeriod : r.endClass;
        final top = (r.startClass - 1) * cellHeight;
        final height = (end - r.startClass + 1) * cellHeight;

        cards.add(
          Positioned(
            top: top + 1,
            left: 2,
            right: 2,
            height: height - 2,
            child: CourseCard(course: c, location: r.location),
          ),
        );
      }
    }
    return cards;
  }
}
