import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';

void main() {
  const term = CalTerm(
    termId: 'fall',
    schoolYear: '2026',
    term: '202601',
    startDate: '2026-09-07',
    endDate: '2027-01-17',
  );
  Course course(
    String name, {
    int start = 1,
    int day = 1,
    bool oddOnly = false,
    List<CourseAdjustRule> adjustments = const [],
  }) => Course.fromJson({
    'name': name,
    'type': 'official',
    'scheduleRules': [
      CourseScheduleRule(
        location: '东 301',
        startClass: start,
        endClass: start + 1,
        startWeek: 1,
        endWeek: 19,
        weekday: day,
        single: true,
        double: !oddOnly,
      ).toJson(),
    ],
    'adjustRules': adjustments.map((entry) => entry.toJson()).toList(),
  });
  NextCourseWidgetSnapshot build(
    List<Course>? courses, {
    DateTime? now,
    List<CalTerm> terms = const [term],
    List<HiddenCourseSession> hidden = const [],
    List<CustomCourse> custom = const [],
    bool autoAdjust = true,
    String account = 'student',
    int days = 7,
    DateTime? sourceUpdatedAt,
  }) => NextCourseWidgetSnapshot.build(
    account: account,
    terms: terms,
    coursesByTerm: courses == null ? {} : {'202601': courses},
    now: now ?? DateTime.utc(2026, 9, 13, 16),
    autoAdjust: autoAdjust,
    customCourses: custom,
    hiddenSessions: hidden,
    horizonDays: days,
    sourceUpdatedAt: sourceUpdatedAt,
  );

  test('late-week rebuild retains elapsed Monday through Sunday', () {
    final now = DateTime.utc(2026, 9, 17, 5); // Thursday in Beijing.
    final snapshot = build([
      course('周一课'),
      course('周三课', day: 3),
      course('周日课', day: 7),
    ], now: now);
    expect(snapshot.days.first.start, DateTime.utc(2026, 9, 13, 16));
    expect(snapshot.days.last.start, DateTime.utc(2026, 9, 19, 16));
    expect(snapshot.days, hasLength(7));
    expect(snapshot.days.every((day) => day.week == 2), isTrue);
    expect(snapshot.days.first.courses.single.name, '周一课');
    expect(snapshot.days[2].courses.single.name, '周三课');
    // Passed courses remain available to the timetable, but aren't "next".
    expect(snapshot.select(now).courses.single.name, '周日课');
  });

  test('week changes at Beijing Monday, not UTC or device Monday', () {
    final sunday = build([], now: DateTime.utc(2026, 9, 13, 15, 59, 59));
    final monday = build([], now: DateTime.utc(2026, 9, 13, 16));
    final offsetMonday = build(
      [],
      now: DateTime.parse('2026-09-13T09:00:00-07:00'),
    );
    expect(sunday.days.first.start, DateTime.utc(2026, 9, 6, 16));
    expect(sunday.days.last.week, 1);
    expect(monday.days.first.start, DateTime.utc(2026, 9, 13, 16));
    expect(monday.days.first.week, 2);
    expect(offsetMonday.days.first.start, monday.days.first.start);
    expect(
      sunday.select(DateTime.utc(2026, 9, 13, 15, 59, 59)).state,
      NextCourseWidgetState.noUpcoming,
    );
    expect(
      sunday.select(DateTime.utc(2026, 9, 13, 16)).state,
      NextCourseWidgetState.unknown,
    );
  });

  test('version-one coverage stays bounded including elapsed weekdays', () {
    final snapshot = build(
      [],
      now: DateTime.utc(2026, 9, 20, 12), // Sunday in Beijing.
      days: 999,
    );
    expect(snapshot.days, hasLength(180));
    expect(snapshot.toJson()['version'], 1);
    expect(snapshot.days.first.start, DateTime.utc(2026, 9, 13, 16));
    expect(
      snapshot.days.last.start.difference(snapshot.days.first.start).inDays,
      179,
    );
    expect(build([], days: -1).days, isEmpty);
  });

  test('week is optional and does not imply valid cached course coverage', () {
    final unknown = build(null);
    expect(unknown.days.first.known, isFalse);
    expect(unknown.days.first.week, 2);
    expect(unknown.days.first.toJson()['week'], 2);
    final outside = build([], terms: []);
    expect(outside.days.first.week, isNull);
    expect(outside.days.first.toJson(), isNot(contains('week')));
  });

  test('cache freshness stays distinct from snapshot generation time', () {
    final now = DateTime.utc(2026, 9, 13, 16);
    final updated = now.subtract(const Duration(days: 2));
    final snapshot = build([], now: now, sourceUpdatedAt: updated);
    expect(snapshot.generatedAt, now);
    expect(snapshot.sourceUpdatedAt, updated);
    expect(
      snapshot.toJson()['sourceUpdatedAt'],
      updated.millisecondsSinceEpoch,
    );
    for (final invalid in [
      null,
      now.add(const Duration(seconds: 1)),
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ]) {
      expect(
        build([], now: now, sourceUpdatedAt: invalid).toJson(),
        isNot(contains('sourceUpdatedAt')),
      );
    }
    expect(
      build([], account: '', sourceUpdatedAt: updated).sourceUpdatedAt,
      isNull,
    );
  });

  test('Beijing midnight and class boundaries are UTC instants', () {
    final now = DateTime.utc(2026, 9, 13, 16);
    final snapshot = build([course('高数')], now: now);
    expect(snapshot.days.first.start, now);
    final entry = snapshot.days.first.courses.single;
    expect(entry.start, DateTime.utc(2026, 9, 14, 0, 20));
    expect(entry.end, DateTime.utc(2026, 9, 14, 2));
    expect(entry.week, 2);
    expect(
      snapshot.select(entry.start.subtract(const Duration(seconds: 1))).state,
      NextCourseWidgetState.upcoming,
    );
    expect(
      snapshot.select(entry.start).state,
      NextCourseWidgetState.inProgress,
    );
    expect(snapshot.select(entry.end).courses, isEmpty);
  });

  test(
    'an in-progress class is retained and simultaneous courses are visible',
    () {
      final snapshot = build([
        course('下午课', start: 5),
        course('高数'),
        course('英语'),
      ]);
      final result = snapshot.select(DateTime.utc(2026, 9, 14, 1));
      expect(result.state, NextCourseWidgetState.inProgress);
      expect(result.courses.map((c) => c.name), ['高数', '英语']);
      final next = snapshot.select(DateTime.utc(2026, 9, 14, 2));
      expect(next.state, NextCourseWidgetState.upcoming);
      expect(next.courses.single.name, '下午课');
    },
  );

  test('odd/even weeks and hidden occurrences share timetable filtering', () {
    final hiddenCourse = course('隐藏课');
    final snapshot = build(
      [course('单周课', oddOnly: true), hiddenCourse, course('下午课', start: 5)],
      hidden: [
        HiddenCourseSession(
          account: 'student',
          term: '202601',
          courseKey: HiddenCourseSession.keyForCourse(hiddenCourse),
          name: hiddenCourse.name,
          teacher: '',
          location: '东 301',
          week: 2,
          weekday: 1,
          startClass: 1,
          endClass: 2,
        ),
      ],
    );
    expect(snapshot.days.first.courses.map((c) => c.name), ['下午课']);
  });

  test('individual and public adjustments honor auto-adjust setting', () {
    const adjustment = CourseAdjustRule(
      oldWeek: 2,
      oldWeekday: 1,
      oldStartClass: 1,
      oldEndClass: 2,
      newWeek: 2,
      newWeekday: 2,
      newStartClass: 5,
      newEndClass: 6,
      newLocation: '西 102',
    );
    final moved = course('调课', adjustments: [adjustment]);
    final snapshot = build([moved]);
    expect(snapshot.days.first.courses, isEmpty);
    expect(snapshot.days[1].courses.single.location, '西 102');
    expect(snapshot.days[1].courses.single.start, DateTime.utc(2026, 9, 15, 6));
    expect(
      build([moved], autoAdjust: false).days.first.courses.single.name,
      '调课',
    );
    expect(build([moved], autoAdjust: false).days[1].courses, isEmpty);
  });

  test('elapsed week days preserve hidden, custom and adjusted filtering', () {
    final hidden = course('已隐藏');
    final shifted = course(
      '调到周二',
      adjustments: [
        const CourseAdjustRule(
          oldWeek: 2,
          oldWeekday: 1,
          oldStartClass: 1,
          oldEndClass: 2,
          newWeek: 2,
          newWeekday: 2,
          newStartClass: 5,
          newEndClass: 6,
          newLocation: '西 102',
        ),
      ],
    );
    final snapshot = build(
      [hidden, shifted, course('单周', oddOnly: true)],
      now: DateTime.utc(2026, 9, 17),
      hidden: [
        HiddenCourseSession(
          account: 'student',
          term: '202601',
          courseKey: HiddenCourseSession.keyForCourse(hidden),
          name: hidden.name,
          teacher: '',
          location: '东 301',
          week: 2,
          weekday: 1,
          startClass: 1,
          endClass: 2,
        ),
      ],
      custom: [
        CustomCourse(
          id: 'local',
          account: 'student',
          term: '202601',
          name: '周三自习',
          weekday: 3,
          startClass: 3,
          endClass: 4,
          startWeek: 1,
          endWeek: 19,
        ),
      ],
    );
    expect(snapshot.days.first.courses, isEmpty);
    expect(snapshot.days[1].courses.single.name, '调到周二');
    expect(snapshot.days[1].courses.single.location, '西 102');
    expect(snapshot.days[2].courses.single.name, '周三自习');
  });

  test('custom classes remain scoped to account and actual calendar term', () {
    CustomCourse local(String account, String term, String name) =>
        CustomCourse(
          id: name,
          account: account,
          term: term,
          name: name,
          startClass: 1,
          endClass: 2,
          startWeek: 1,
          endWeek: 19,
          weekday: 1,
        );
    final custom = [
      local('student', '202601', '实验'),
      local('other', '202601', '其他账号'),
      local('student', '202501', '历史课程'),
    ];
    expect(build([], custom: custom).days.first.courses.single.name, '实验');
    expect(build(null, custom: custom).days.first.known, isFalse);
    expect(build(null, custom: custom).days.first.courses, isEmpty);
  });

  test('unknown is distinct from a known empty date and expired coverage', () {
    final today = DateTime.utc(2026, 9, 13, 16);
    final known = build([], now: today);
    expect(known.days.first.known, isTrue);
    expect(known.select(today).state, NextCourseWidgetState.noUpcoming);
    expect(build(null).select(today).state, NextCourseWidgetState.unknown);
    expect(
      build([], terms: []).select(today).state,
      NextCourseWidgetState.unknown,
    );
    expect(
      known.select(today.add(const Duration(days: 8))).state,
      NextCourseWidgetState.unknown,
    );
    final outside = DateTime.utc(2027, 1, 20);
    expect(
      build([], now: outside).select(outside).state,
      NextCourseWidgetState.unknown,
    );
  });

  test(
    '19-week limit does not repeat the last week of a long calendar term',
    () {
      const longTerm = CalTerm(
        termId: 'long',
        schoolYear: '2026',
        term: '202601',
        startDate: '2026-09-07',
        endDate: '2027-03-01',
      );
      final now = DateTime.utc(2027, 1, 18);
      final result = build([course('高数')], terms: [longTerm], now: now);
      expect(result.days.first.known, isFalse);
      expect(result.select(now).state, NextCourseWidgetState.unknown);
    },
  );

  test('malformed course periods never index outside shared period times', () {
    Course invalid(int start, int end) => Course.fromJson({
      'name': '无效节次',
      'scheduleRules': [
        {
          'startClass': start,
          'endClass': end,
          'startWeek': 1,
          'endWeek': 19,
          'weekday': 1,
        },
      ],
    });
    final snapshot = build([
      invalid(0, 2),
      invalid(12, 13),
      invalid(5, 1),
      course('有效课程'),
    ]);
    expect(snapshot.days.first.courses.single.name, '有效课程');
    expect(() => build([invalid(11, 999)]), returnsNormally);
  });

  test(
    'unknown dates block claiming a later cached term has the next class',
    () {
      const nextTerm = CalTerm(
        termId: 'spring',
        schoolYear: '2027',
        term: '202602',
        startDate: '2026-09-16',
        endDate: '2026-10-31',
      );
      const shortTerm = CalTerm(
        termId: 'short',
        schoolYear: '2026',
        term: '202601',
        startDate: '2026-09-07',
        endDate: '2026-09-14',
      );
      final now = DateTime.utc(2026, 9, 13, 16);
      final result = NextCourseWidgetSnapshot.build(
        account: 'student',
        terms: const [shortTerm, nextTerm],
        coursesByTerm: {
          '202601': [],
          '202602': [course('后续课程', day: 3)],
        },
        now: now,
        autoAdjust: true,
        horizonDays: 5,
      );
      expect(result.days[1].known, isFalse);
      expect(result.days[2].courses, isNotEmpty);
      expect(result.select(now).state, NextCourseWidgetState.unknown);
    },
  );

  test(
    'serialized snapshot excludes account IDs and all private course metadata',
    () {
      final privateCourse = Course.fromJson({
        ...course('高数').toJson(),
        'teacher': '不需要保存的教师',
        'remark': '不需要保存的备注',
        'rawExamTime': '不需要保存的考试',
      });
      final encoded = jsonEncode(build([privateCourse]).toJson());
      expect(encoded, isNot(contains('student')));
      expect(encoded, isNot(contains('不需要保存')));
      expect(encoded, isNot(contains('account')));
      expect(encoded, isNot(contains('cookie')));
      expect(encoded, contains('高数'));
      expect(encoded, contains('东 301'));
      final signedOut = build([privateCourse], account: '');
      expect(
        signedOut.select(DateTime.utc(2026, 9, 13, 16)).state,
        NextCourseWidgetState.signedOut,
      );
      expect(signedOut.days.every((day) => day.courses.isEmpty), isTrue);
    },
  );
}
