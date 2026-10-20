import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/schedule/widgets/schedule_grid.dart';
import 'package:fzu_assistant/screen/settings/home_settings_page.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoginAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/logincheck.asp')) {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['/?token=token&id=initial&num=1'],
        },
      );
    }
    if (path.endsWith('/SSOLogin')) {
      return ResponseBody.fromString(
        '{"code":200}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (path.endsWith('/loginchk_xs.aspx')) {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['/?id=session-id'],
        },
      );
    }
    return ResponseBody.fromString('<html></html>', 200);
  }

  @override
  void close({bool force = false}) {}
}

final _course = Course.fromJson({
  'name': '测试课程',
  'teacher': '张老师',
  'scheduleRules': [
    for (final start in [1, 5])
      CourseScheduleRule(
        location: 'A101',
        startClass: start,
        endClass: start + 1,
        startWeek: 1,
        endWeek: 19,
        weekday: 1,
        single: true,
        double: true,
      ).toJson(),
  ],
});

HiddenCourseSession _hidden({
  String account = 'student',
  String term = '202601',
  int week = 3,
  int weekday = 1,
  int start = 1,
}) => HiddenCourseSession(
  account: account,
  term: term,
  courseKey: HiddenCourseSession.keyForCourse(_course),
  name: _course.name,
  teacher: _course.teacher,
  location: 'A101',
  week: week,
  weekday: weekday,
  startClass: start,
  endClass: start + 1,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('隐藏一次课不影响其他周次、节次、学期或账号，且支持调入课程', () {
    List<CourseSession> sessions({
      String account = 'student',
      String term = '202601',
      int week = 3,
      int weekday = 1,
      List<Course>? courses,
    }) => CourseSessions.forDay(
      courses: courses ?? [_course],
      week: week,
      weekday: weekday,
      autoAdjust: true,
      account: account,
      term: term,
      hiddenSessions: [_hidden()],
    );
    expect(sessions().map((s) => s.startClass), [5]);
    expect(sessions(week: 4), hasLength(2));
    expect(sessions(term: '202602'), hasLength(2));
    expect(sessions(account: 'another'), hasLength(2));
    final moved = Course.fromJson(
      _course.toJson()
        ..['adjustRules'] = [
          const CourseAdjustRule(
            oldWeek: 2,
            oldWeekday: 2,
            oldStartClass: 1,
            oldEndClass: 2,
            newWeek: 3,
            newWeekday: 1,
            newStartClass: 1,
            newEndClass: 2,
            newLocation: 'B102',
          ).toJson(),
        ],
    );
    expect(sessions(courses: [moved]).map((s) => s.startClass), [5]);
  });

  test('隐藏记录持久化、去重，全部恢复保留其他账号记录', () async {
    final settings = AppSettings();
    await settings.load();
    settings.hideCourseSession(_hidden());
    settings.hideCourseSession(_hidden());
    settings.hideCourseSession(_hidden(account: 'another'));
    await Future<void>.delayed(Duration.zero);
    final reloaded = AppSettings();
    await reloaded.load();
    expect(reloaded.hiddenCourseSessions.value, hasLength(2));
    reloaded.restoreAllCourseSessions('student');
    expect(reloaded.hiddenCourseSessions.value.single.account, 'another');
    reloaded.restoreCourseSession(_hidden(account: 'another'));
    expect(reloaded.hiddenCourseSessions.value, isEmpty);
    await Future<void>.delayed(Duration.zero);
    settings.dispose();
    reloaded.dispose();
  });

  for (final size in [const Size(420, 900), const Size(1200, 800)]) {
    testWidgets('课程详情底部隐藏并从设置恢复 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ApiClient.instance;
      final original = api.dio.httpClientAdapter;
      api.dio.httpClientAdapter = _LoginAdapter();
      addTearDown(() async {
        await api.clearSession();
        api.dio.httpClientAdapter = original;
      });
      await tester.runAsync(() => api.login('student', 'test', '12'));
      final settings = AppSettings();
      await settings.load();
      settings.termsKey.value = ['202601'];
      await tester.pumpWidget(
        AppSettingsProvider(
          settings: settings,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routes: {AppRoutes.homeSettings: (_) => const HomeSettingsPage()},
            home: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () =>
                          context.pushNamed(AppRoutes.homeSettings),
                    ),
                  ],
                ),
                body: KeyedSubtree(
                  key: ValueKey(MediaQuery.orientationOf(context)),
                  child: ScheduleGrid(
                    term: '202601',
                    courses: [_course],
                    examRooms: const [],
                    week: 3,
                    firstMonday: null,
                    onRefresh: () async {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_course.name), findsNWidgets(2));
      await tester.tap(find.text(_course.name).first);
      await tester.pumpAndSettle();
      tester.view.physicalSize = size.width > size.height
          ? const Size(420, 900)
          : const Size(1200, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byType(DraggableScrollableSheet),
        size.width > size.height ? findsOneWidget : findsNothing,
      );
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('我不想上'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我不想上'));
      await tester.pumpAndSettle();
      expect(settings.hiddenCourseSessions.value, hasLength(1));
      expect(find.text(_course.name), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('不展示的课'), 250);
      await tester.ensureVisible(find.byTooltip('恢复展示'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('恢复展示'));
      await tester.pumpAndSettle();
      expect(settings.hiddenCourseSessions.value, isEmpty);
      expect(find.text('暂无不展示的课'), findsOneWidget);
      settings.hideCourseSession(_hidden());
      settings.hideCourseSession(_hidden(week: 4));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('全部恢复'));
      await tester.tap(find.text('全部恢复'));
      await tester.pumpAndSettle();
      expect(settings.hiddenCourseSessions.value, isEmpty);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(_course.name), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    });
  }
}
