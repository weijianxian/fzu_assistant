import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppSettings settings;
  late AppLocalizations l10n;
  final calendar = const SchoolCalendar(
    currentTerm: '202601',
    terms: [
      CalTerm(
        termId: '1',
        schoolYear: '2026',
        term: '202601',
        startDate: '2026-09-07',
        endDate: '2027-01-17',
      ),
    ],
  ).toJson();
  Course course(
    String name, {
    int start = 1,
    int day = 1,
    bool oddOnly = false,
  }) => Course.fromJson({
    'name': name,
    'scheduleRules': [
      CourseScheduleRule(
        location: '教学楼 A',
        startClass: start,
        endClass: start + 1,
        startWeek: 1,
        endWeek: 19,
        weekday: day,
        single: true,
        double: !oddOnly,
      ).toJson(),
    ],
  });
  List<Map<String, Object>> plans(
    List<Course>? courses, {
    DateTime? now,
    Map<String, dynamic> holidays = const {},
  }) => CourseReminderService.buildPlans(
    settings: settings,
    account: 'student',
    l10n: l10n,
    calendar: calendar,
    caches: courses == null
        ? {}
        : {
            '202601': {'courses': courses.map((c) => c.toJson()).toList()},
          },
    holidays: holidays,
    now: now ?? DateTime.utc(2026, 9, 13, 12),
  );

  setUp(() async {
    settings = AppSettings();
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });
  tearDown(() => settings.dispose());

  test('北京时间 21 点提醒最早课程，保留同时间冲突课程', () {
    final result = plans([course('下午', start: 5), course('高数'), course('英语')]);
    expect(
      result.first['at'],
      DateTime.utc(2026, 9, 13, 13).millisecondsSinceEpoch,
    );
    expect(result.first['body'], contains('8:20'));
    expect(result.first['body'], contains('高数'));
    expect(result.first['body'], contains('英语'));
    expect(result.first['body'], isNot(contains('下午')));
    expect(result.first['body'], contains('教学楼 A'));
  });

  test('已过提醒时间不补发，跨北京时间午夜使用次日课表', () {
    final result = plans([course('高数')], now: DateTime.utc(2026, 9, 13, 13, 1));
    expect(
      result.first['at'],
      DateTime.utc(2026, 9, 14, 13).millisecondsSinceEpoch,
    );
    expect(result.first['body'], l10n.courseReminderRest);
    final midnight = plans([
      course('周二课', day: 2),
    ], now: DateTime.utc(2026, 9, 13, 16, 1));
    expect(midnight.first['body'], contains('周二课'));
  });

  test('区分无课、单双周不匹配、缺少缓存和学期外未知', () {
    expect(plans([]).first['body'], l10n.courseReminderRest);
    expect(
      plans([course('单周课', oddOnly: true)]).first['body'],
      l10n.courseReminderRest,
    );
    expect(plans(null).first['body'], l10n.courseReminderUnknown);
    expect(
      plans([], now: DateTime.utc(2027, 1, 20)).first['body'],
      l10n.courseReminderUnknown,
    );
  });

  test('遵循调课和隐藏设置，历史学期选择不影响实际日期', () {
    final early = course('早课');
    final late = course('晚课', start: 5);
    settings.selectedSemesterKey.value = '202501';
    settings.hiddenCourseSessions.value = [
      HiddenCourseSession(
        account: 'student',
        term: '202601',
        courseKey: HiddenCourseSession.keyForCourse(early),
        name: early.name,
        teacher: '',
        location: '教学楼 A',
        week: 2,
        weekday: 1,
        startClass: 1,
        endClass: 2,
      ),
    ];
    expect(plans([early, late]).first['body'], contains('14:00'));
    settings.hiddenCourseSessions.value = [];
    settings.west2AdjustmentsAccess.value = FeatureAccess.allow;
    final holidays = {
      '202601': [
        {'enabled': true, 'from_week': 2, 'from_weekday': 1, 'to_date': ''},
      ],
    };
    expect(
      plans([early], holidays: holidays).first['body'],
      l10n.courseReminderRest,
    );
    settings.autoAdjustCourse.value = false;
    expect(plans([early], holidays: holidays).first['body'], contains('早课'));
  });
}
