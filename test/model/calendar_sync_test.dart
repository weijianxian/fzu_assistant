import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/calendar_export.dart';
import 'package:fzu_assistant/model/calendar_sync.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';

import 'calendar_export_test.dart' as fixture;

void main() {
  test(
    'native payload shares course expansion, UTC times and hashed identities',
    () {
      Map<String, Object> build(String raw) => buildCalendarSyncPayload(
        account: 'private-account',
        terms: [fixture.term],
        coursesByTerm: {
          fixture.term.term: [fixture.sample(rawExamTime: raw)],
        },
        customCourses: [],
        hiddenSessions: [],
        autoAdjust: true,
        includeExams: true,
        reminderMinutes: 15,
        now: DateTime.utc(2026, 11),
      );
      final payload = build('2026年11月13日14:00-16:00旗山');
      expect(payload.toString(), isNot(contains('private-account')));
      final events = payload['events'] as List<Map<String, Object>>;
      expect(events.length, 2);
      expect(events.first['rrule'], 'FREQ=WEEKLY;INTERVAL=1;COUNT=2');
      expect(payload['occurrenceCount'], 3);
      expect(
        events.first['start'],
        DateTime.utc(2026, 11, 2, 0, 20).millisecondsSinceEpoch,
      );
      final invalid = build('考试待定');
      expect(invalid['protected'], [events.last['uid']]);
      final removed = build('');
      expect(removed['protected'], isEmpty);
      expect(removed['events'], hasLength(1));
    },
  );

  test(
    'missing term cache cannot generate a destructive empty replacement',
    () {
      expect(
        () => buildCalendarSyncPayload(
          account: 'account',
          terms: [fixture.term],
          coursesByTerm: {},
          customCourses: [],
          hiddenSessions: [],
          autoAdjust: true,
          includeExams: true,
          reminderMinutes: 0,
          now: DateTime.utc(2026),
        ),
        throwsStateError,
      );
    },
  );

  const longTerm = CalTerm(
    termId: '1',
    schoolYear: '2026-2027',
    term: '202601',
    startDate: '2026-11-02',
    endDate: '2027-02-21',
  );
  Course course({
    List<CourseScheduleRule>? rules,
    List<CourseAdjustRule> adjustments = const [],
    bool oddOnly = false,
  }) => Course(
    type: 'required',
    name: '数学',
    credits: '3',
    electiveType: '',
    examType: '',
    teacher: '李老师',
    scheduleRules:
        rules ??
        [
          CourseScheduleRule(
            location: '教室 A',
            startClass: 1,
            endClass: 2,
            startWeek: 1,
            endWeek: 16,
            weekday: 1,
            single: true,
            double: !oddOnly,
          ),
        ],
    adjustRules: adjustments,
    rawExamTime: '',
    remark: '',
  );
  Map<String, Object> build(
    List<Course> courses, {
    List<HiddenCourseSession> hidden = const [],
    List<CustomCourse> custom = const [],
    bool autoAdjust = true,
  }) => buildCalendarSyncPayload(
    account: 'student',
    terms: [longTerm],
    coursesByTerm: {longTerm.term: courses},
    customCourses: custom,
    hiddenSessions: hidden,
    autoAdjust: autoAdjust,
    includeExams: true,
    reminderMinutes: 15,
    now: DateTime.utc(2026, 11),
  );

  test('16 次常规课只写一条系统每周重复日程，单双周使用隔周重复', () {
    final weekly = build([course()]);
    final events = weekly['events'] as List<Map<String, Object>>;
    expect(events, hasLength(1));
    expect(events.single['rrule'], 'FREQ=WEEKLY;INTERVAL=1;COUNT=16');
    expect(weekly['occurrenceCount'], 16);
    final odd = build([course(oddOnly: true)]);
    expect(
      (odd['events'] as List<Map<String, Object>>).single['rrule'],
      'FREQ=WEEKLY;INTERVAL=2;COUNT=8',
    );
    expect(odd['occurrenceCount'], 8);
  });

  test('单次隐藏和停课使用 EXDATE，调课与单次换教室关联原始实例', () {
    final scheduled = course(
      adjustments: const [
        CourseAdjustRule(
          oldWeek: 4,
          oldWeekday: 1,
          oldStartClass: 1,
          oldEndClass: 2,
          newWeek: 4,
          newWeekday: 3,
          newStartClass: 3,
          newEndClass: 4,
          newLocation: '教室 B',
        ),
        CourseAdjustRule(
          oldWeek: 6,
          oldWeekday: 1,
          oldStartClass: 1,
          oldEndClass: 2,
          canceled: true,
          newWeek: 0,
          newWeekday: 0,
          newStartClass: 0,
          newEndClass: 0,
          newLocation: '',
        ),
        CourseAdjustRule(
          oldWeek: 7,
          oldWeekday: 1,
          oldStartClass: 1,
          oldEndClass: 2,
          newWeek: 7,
          newWeekday: 1,
          newStartClass: 1,
          newEndClass: 2,
          newLocation: '教室 C',
        ),
      ],
    );
    final hidden = [
      HiddenCourseSession(
        account: 'student',
        term: longTerm.term,
        courseKey: HiddenCourseSession.keyForCourse(scheduled),
        name: scheduled.name,
        teacher: scheduled.teacher,
        location: '',
        week: 5,
        weekday: 1,
        startClass: 1,
        endClass: 2,
      ),
    ];
    final payload = build([scheduled], hidden: hidden);
    final events = payload['events'] as List<Map<String, Object>>;
    final parent = events.first;
    expect(parent['rrule'], 'FREQ=WEEKLY;INTERVAL=1;COUNT=16');
    expect(parent['exdate'], '20261130T002000Z,20261207T002000Z');
    expect(events, hasLength(3));
    expect(
      events.skip(1).every((event) => event['originalUid'] == parent['uid']),
      isTrue,
    );
    final moved = events.singleWhere((event) => event['location'] == '教室 B');
    expect(
      moved['originalStart'],
      DateTime.utc(2026, 11, 23, 0, 20).millisecondsSinceEpoch,
    );
    expect(
      moved['start'],
      DateTime.utc(2026, 11, 25, 2, 20).millisecondsSinceEpoch,
    );
    expect(payload['occurrenceCount'], 14);
    final expanded = CalendarExport.build(
      account: 'student',
      term: longTerm,
      courses: [scheduled],
      hiddenSessions: hidden,
      autoAdjust: true,
      includeExams: true,
      reminderMinutes: 15,
      calendarName: '',
      generatedAt: DateTime.utc(2026),
    );
    expect(_instances(payload), _expandedInstances(expanded.events));
    expect(
      (build([scheduled], hidden: hidden, autoAdjust: false)['events']
              as List<Map<String, Object>>)
          .where((event) => event.containsKey('originalUid')),
      isEmpty,
    );
  });

  test('不连续周次、不同教室和重复数据仍与实际课表一致', () {
    CourseScheduleRule rule(int first, int last, String room) =>
        CourseScheduleRule(
          location: room,
          startClass: 1,
          endClass: 2,
          startWeek: first,
          endWeek: last,
          weekday: 1,
          single: true,
          double: true,
        );
    final scheduled = course(
      rules: [rule(1, 4, 'A'), rule(7, 10, 'A'), rule(11, 16, 'B')],
    );
    final payload = build([scheduled, scheduled]);
    final events = payload['events'] as List<Map<String, Object>>;
    expect(events, hasLength(2));
    expect(events.every((event) => event.containsKey('rrule')), isTrue);
    expect(events.first['rrule'], 'FREQ=WEEKLY;INTERVAL=1;COUNT=10');
    expect(events.first['exdate'], '20261130T002000Z,20261207T002000Z');
    final expanded = CalendarExport.build(
      account: 'student',
      term: longTerm,
      courses: [scheduled, scheduled],
      hiddenSessions: [],
      autoAdjust: true,
      includeExams: true,
      reminderMinutes: 15,
      calendarName: '',
      generatedAt: DateTime.utc(2026),
    );
    expect(_instances(payload), _expandedInstances(expanded.events));
  });

  test('隐藏调入课程时仅排除原始实例，恢复后例外身份稳定', () {
    final scheduled = course(
      adjustments: const [
        CourseAdjustRule(
          oldWeek: 1,
          oldWeekday: 1,
          oldStartClass: 1,
          oldEndClass: 2,
          newWeek: 1,
          newWeekday: 2,
          newStartClass: 3,
          newEndClass: 4,
          newLocation: '新教室',
        ),
      ],
    );
    final visible = build([scheduled]);
    final hidden = build(
      [scheduled],
      hidden: [
        HiddenCourseSession(
          account: 'student',
          term: longTerm.term,
          courseKey: HiddenCourseSession.keyForCourse(scheduled),
          name: scheduled.name,
          teacher: scheduled.teacher,
          location: '',
          week: 1,
          weekday: 2,
          startClass: 3,
          endClass: 4,
        ),
      ],
    );
    final events = hidden['events'] as List<Map<String, Object>>;
    expect(events, hasLength(1));
    expect(events.single['exdate'], '20261102T002000Z');
    expect(hidden['occurrenceCount'], 15);
    expect(build([scheduled]), visible);
  });

  test('自定义课程按账号学期隔离并使用系统重复，真正单次补课保持单次', () {
    final extra = course(
      rules: [],
      adjustments: const [
        CourseAdjustRule(
          oldWeek: 1,
          oldWeekday: 1,
          oldStartClass: 1,
          oldEndClass: 2,
          newWeek: 1,
          newWeekday: 2,
          newStartClass: 3,
          newEndClass: 4,
          newLocation: '补课',
        ),
      ],
    );
    CustomCourse custom(String account) => CustomCourse(
      id: 'custom',
      account: account,
      term: longTerm.term,
      name: '自定义',
      startClass: 5,
      endClass: 6,
      startWeek: 1,
      endWeek: 16,
      weekday: 3,
    );
    final payload = build(
      [extra],
      custom: [custom('student'), custom('other')],
    );
    final events = payload['events'] as List<Map<String, Object>>;
    expect(events, hasLength(2));
    expect(events.where((event) => event.containsKey('rrule')), hasLength(1));
    expect(payload['occurrenceCount'], 17);
  });
}

typedef _Instance = (String, String, int, int);

List<_Instance> _expandedInstances(List<ScheduleCalendarEvent> events) => [
  for (final event in events)
    (
      event.title,
      event.location,
      event.start.millisecondsSinceEpoch,
      event.end.millisecondsSinceEpoch,
    ),
]..sort((a, b) => a.toString().compareTo(b.toString()));

List<_Instance> _instances(Map<String, Object> payload) {
  final events = payload['events'] as List<Map<String, Object>>;
  final result = <(String, int), _Instance>{};
  for (final event in events.where(
    (event) => !event.containsKey('originalUid'),
  )) {
    final rule = event['rrule'] as String?;
    final start = event['start'] as int;
    final end = event['end'] as int;
    final parts = rule?.split(';');
    final interval = parts == null ? 1 : int.parse(parts[1].split('=').last);
    final count = parts == null ? 1 : int.parse(parts[2].split('=').last);
    final excluded = (event['exdate'] as String? ?? '')
        .split(',')
        .where((value) => value.isNotEmpty)
        .map((value) => DateTime.parse(value).millisecondsSinceEpoch)
        .toSet();
    for (var index = 0; index < count; index++) {
      final offset = Duration(days: 7 * interval * index).inMilliseconds;
      if (excluded.contains(start + offset)) continue;
      result[(event['uid'] as String, start + offset)] = (
        event['title'] as String,
        event['location'] as String,
        start + offset,
        end + offset,
      );
    }
  }
  for (final event in events.where(
    (event) => event.containsKey('originalUid'),
  )) {
    result[(event['originalUid'] as String, event['originalStart'] as int)] = (
      event['title'] as String,
      event['location'] as String,
      event['start'] as int,
      event['end'] as int,
    );
  }
  return result.values.toList()
    ..sort((a, b) => a.toString().compareTo(b.toString()));
}
