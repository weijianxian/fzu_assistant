import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/service/api/course_service.dart';

void main() {
  Course course(
    String name, {
    int startWeek = 1,
    bool single = true,
    bool double = true,
    int startClass = 1,
  }) => Course.fromJson({
    'name': name,
    'scheduleRules': [
      CourseScheduleRule(
        location: 'A',
        startClass: startClass,
        endClass: startClass + 1,
        startWeek: startWeek,
        endWeek: 19,
        weekday: 1,
        single: single,
        double: double,
      ).toJson(),
    ],
  });
  List<CourseSession> sessions(
    List<Course> courses, {
    bool show = true,
    int week = 2,
    int day = 1,
  }) => CourseSessions.forDay(
    courses: courses,
    week: week,
    weekday: day,
    autoAdjust: true,
    showNonCurrentWeekCourses: show,
  );

  test('非本周课程默认隐藏，开启后显示未开始和单双周不匹配课程', () {
    final courses = [
      course('future', startWeek: 5),
      course('odd', single: true, double: false, startClass: 3),
    ];
    expect(sessions(courses, show: false), isEmpty);
    expect(sessions(courses).map((s) => s.course.name), ['future', 'odd']);
    expect(sessions(courses).every((s) => !s.isCurrentWeek), isTrue);
  });
  test('本周课程优先，部分重叠的非本周课程不遮挡本周课程', () {
    final result = sessions([
      course('future', startWeek: 5),
      course('current', startClass: 2),
    ]);
    expect(result.single.course.name, 'current');
    expect(result.single.isCurrentWeek, isTrue);
  });
  test('自动调课后停课不作为非本周课程重新出现', () {
    final courses = CourseService.applyHolidayAdjustments(
      [course('canceled')],
      [
        {'enabled': true, 'from_week': 2, 'from_weekday': 1, 'to_date': ''},
      ],
    );
    expect(sessions(courses), isEmpty);
  });
  test('调入课程优先于非本周课程', () {
    final moved = CourseService.applyHolidayAdjustments(
      [course('moved')],
      [
        {
          'enabled': true,
          'from_week': 1,
          'from_weekday': 1,
          'to_date': '2026-10-06',
          'to_week': 2,
          'to_weekday': 2,
        },
      ],
    );
    final other = Course.fromJson({
      'name': 'future',
      'scheduleRules': [
        const CourseScheduleRule(
          location: 'B',
          startClass: 1,
          endClass: 2,
          startWeek: 5,
          endWeek: 19,
          weekday: 2,
          single: true,
          double: true,
        ).toJson(),
      ],
    });
    final result = sessions([other, ...moved], day: 2);
    expect(result.single.course.name, 'moved');
    expect(result.single.adjusted, isTrue);
    expect(result.single.isCurrentWeek, isTrue);
  });
}
