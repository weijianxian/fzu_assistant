import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/calendar_export.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';

const term = CalTerm(
  termId: '1',
  schoolYear: '2026-2027',
  term: '202601',
  startDate: '2026-11-02',
  endDate: '2026-11-15',
);
Course sample({
  String name = '数学',
  String rawExamTime = '',
  List<CourseAdjustRule> adjustments = const [],
  bool single = true,
  bool double = true,
}) => Course(
  type: 'required',
  name: name,
  credits: '3',
  electiveType: '',
  examType: '考试',
  teacher: '李老师',
  scheduleRules: [
    CourseScheduleRule(
      location: '旗山,东3;106',
      startClass: 1,
      endClass: 2,
      startWeek: 1,
      endWeek: 2,
      weekday: 1,
      single: single,
      double: double,
    ),
  ],
  adjustRules: adjustments,
  rawExamTime: rawExamTime,
  remark: '',
);
CalendarExport export(
  List<Course> courses, {
  List<HiddenCourseSession> hidden = const [],
  bool includeExams = true,
  int reminder = 15,
  DateTime? generated,
}) => CalendarExport.build(
  account: 'student',
  term: term,
  courses: courses,
  hiddenSessions: hidden,
  autoAdjust: true,
  includeExams: includeExams,
  reminderMinutes: reminder,
  calendarName: '福州大学课表',
  generatedAt: generated ?? DateTime.utc(2026, 11),
);

void main() {
  test('UTF-8、CRLF、文本转义、75 字节折行和北京时间均符合日历格式', () {
    final name = '${List.filled(30, '课程🐟').join()},A;B\nC\\D';
    final output = export([sample(name: name)]);
    expect(output.eventCount, 2);
    final unfolded = output.content.replaceAll('\r\n ', '');
    expect(unfolded, contains('SUMMARY:${CalendarExport.escape(name)}\r\n'));
    expect(unfolded, contains('LOCATION:旗山\\,东3\\;106\r\n'));
    expect(unfolded, contains('DTSTART:20261102T002000Z'));
    expect(unfolded, contains('DTEND:20261102T020000Z'));
    expect(unfolded, contains('TRIGGER:-PT15M'));
    expect(output.content.endsWith('\r\n'), isTrue);
    for (final line in output.content.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }
    expect(unfolded, isNot(contains('student')));
  });

  test('单双周、调课、单次隐藏与首页一致，考试不受隐藏课程影响', () {
    final course = sample(
      rawExamTime: '2026年11月13日14:00-16:00旗山东3-106',
      adjustments: const [
        CourseAdjustRule(
          oldWeek: 1,
          oldWeekday: 1,
          oldStartClass: 1,
          oldEndClass: 2,
          canceled: false,
          newWeek: 1,
          newWeekday: 2,
          newStartClass: 3,
          newEndClass: 4,
          newLocation: '铜盘',
        ),
      ],
    );
    final hidden = HiddenCourseSession(
      account: 'student',
      term: term.term,
      courseKey: HiddenCourseSession.keyForCourse(course),
      name: course.name,
      teacher: course.teacher,
      location: '',
      week: 2,
      weekday: 1,
      startClass: 1,
      endClass: 2,
    );
    final result = export([course], hidden: [hidden]);
    expect(result.eventCount, 2);
    expect(result.content, contains('DTSTART:20261103T022000Z'));
    expect(result.content, isNot(contains('DTSTART:20261102')));
    expect(result.content, isNot(contains('DTSTART:20261109')));
    expect(result.content, contains('DTSTART:20261113T060000Z'));
    expect(export([sample(single: false)]).eventCount, 1);
  });

  test('关闭提醒和考试生效，无法解析的考试单独计数', () {
    final output = export([sample(rawExamTime: '考试时间待定')], reminder: 0);
    expect(output.skippedExams, 1);
    expect(output.content, isNot(contains('VALARM')));
    final noExams = export([
      sample(rawExamTime: '考试时间待定'),
    ], includeExams: false);
    expect(noExams.skippedExams, 0);
  });

  test('UID 与导出时间无关，相同课程不会因重复记录产生重复日程', () {
    final course = sample();
    List<String> uids(CalendarExport value) => value.content
        .replaceAll('\r\n ', '')
        .split('\r\n')
        .where((s) => s.startsWith('UID:'))
        .toList();
    expect(
      uids(export([course])),
      uids(export([course], generated: DateTime.utc(2027))),
    );
    expect(export([course, course]).eventCount, 2);
    expect(export([]).eventCount, 0);
  });
}
