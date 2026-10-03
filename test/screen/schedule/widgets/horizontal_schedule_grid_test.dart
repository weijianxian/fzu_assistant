import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/screen/schedule/widgets/course_card.dart';
import 'package:fzu_assistant/screen/schedule/widgets/horizontal_schedule_grid.dart';
import 'package:fzu_assistant/screen/schedule/widgets/schedule_grid.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

Course _course(
  String name,
  int day,
  int start,
  int end, {
  List<CourseAdjustRule> adjustments = const [],
}) => Course(
  type: '',
  name: name,
  credits: '2',
  electiveType: '',
  examType: '',
  teacher: '测试教师',
  rawExamTime: '',
  remark: '',
  adjustRules: adjustments,
  scheduleRules: [
    CourseScheduleRule(
      location: '旗山西2-101',
      startClass: start,
      endClass: end,
      startWeek: 1,
      endWeek: 16,
      weekday: day,
      single: true,
      double: true,
    ),
  ],
);

Widget _app(
  AppSettings settings,
  Widget child, {
  Brightness brightness = Brightness.light,
  String language = 'zh',
  double scale = 1,
}) => AppSettingsProvider(
  settings: settings,
  child: MaterialApp(
    theme: buildTheme(Colors.deepPurple, brightness: brightness),
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    ),
  ),
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
}

Finder _card(String name) => find.byWidgetPredicate(
  (widget) => widget is CourseCard && widget.course.name == name,
);

ScheduleGrid _grid({
  List<Course>? courses,
  List<ExamRoomInfo> exams = const [],
}) => ScheduleGrid(
  courses: courses ?? [_course('数学', 1, 1, 2), _course('工程项目管理与决策', 3, 5, 6)],
  examRooms: exams,
  week: 1,
  firstMonday: DateTime(2025, 9, 29),
  onRefresh: () async {},
);

void main() {
  testWidgets(
    'landscape places days vertically and courses across period columns',
    (tester) async {
      _viewport(tester, const Size(1400, 800));
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        _app(
          settings,
          _grid(
            exams: const [
              ExamRoomInfo(
                courseName: '英语',
                credit: '2',
                teacher: '',
                date: '2025年10月3日',
                time: '19:00-20:40',
                location: '东3-301',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HorizontalScheduleGrid), findsOneWidget);
      final monday = tester.getCenter(find.text('周一'));
      final wednesday = tester.getCenter(find.text('周三'));
      expect(monday.dx, wednesday.dx);
      expect(monday.dy, lessThan(wednesday.dy));
      final math = tester.getRect(_card('数学'));
      final project = tester.getRect(_card('工程项目管理与决策'));
      expect(math.width, greaterThan(math.height));
      expect(project.top, greaterThan(math.bottom));
      final p5 = tester.getRect(find.text('第 5 节'));
      final p6 = tester.getRect(find.text('第 6 节'));
      expect(project.left, lessThan(p5.center.dx));
      expect(project.right, greaterThan(p6.center.dx));
      final exam = tester.getRect(_card('[考试]英语'));
      expect(exam.left, lessThan(tester.getCenter(find.text('第 9 节')).dx));
      expect(exam.right, greaterThan(tester.getCenter(find.text('第 10 节')).dx));
      expect(exam.top, greaterThan(project.bottom));

      await tester.tap(_card('工程项目管理与决策'));
      await tester.pumpAndSettle();
      expect(find.text('测试教师'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'horizontal scrolling moves periods and cards while dates stay fixed',
    (tester) async {
      _viewport(tester, const Size(800, 480));
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await tester.pumpWidget(_app(settings, _grid()));
      await tester.pumpAndSettle();
      final monday = tester.getTopLeft(find.text('周一'));
      final header = tester.getTopLeft(find.text('第 5 节'));
      final project = tester.getTopLeft(_card('工程项目管理与决策'));
      await tester.timedDrag(
        find.byKey(const ValueKey('schedule-time-scroll')),
        const Offset(-260, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('周一')), monday);
      final headerDelta = tester.getTopLeft(find.text('第 5 节')).dx - header.dx;
      final cardDelta = tester.getTopLeft(_card('工程项目管理与决策')).dx - project.dx;
      expect(headerDelta, lessThan(-100));
      expect(cardDelta, closeTo(headerDelta, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mouse scrollbar reaches the last period with matching viewport width',
    (tester) async {
      _viewport(tester, const Size(600, 320));
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        _app(settings, _grid(courses: [_course('最后一节', 7, 11, 11)])),
      );
      await tester.pumpAndSettle();
      final times = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('schedule-time-scroll')),
          )
          .controller!;
      final days = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('schedule-day-scroll')),
          )
          .controller!;
      days.jumpTo(days.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final bar = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Scrollbar &&
              widget.scrollbarOrientation == ScrollbarOrientation.bottom,
        ),
      );
      expect(bar.width, closeTo(times.position.viewportDimension, 0.01));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final start = Offset(bar.left + 80, bar.bottom - 3);
      await gesture.addPointer(location: start);
      await gesture.moveTo(start);
      await tester.pumpAndSettle();
      await gesture.down(start);
      for (var step = 1; step <= 14; step++) {
        await gesture.moveBy(
          const Offset(50, 0),
          timeStamp: Duration(milliseconds: step * 20),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(times.offset, closeTo(times.position.maxScrollExtent, 0.01));
      final lastHeader = tester.getRect(find.text('第 11 节'));
      final lastCourse = tester.getRect(_card('最后一节'));
      expect(lastHeader.left, greaterThanOrEqualTo(88));
      expect(lastHeader.right, lessThanOrEqualTo(600));
      expect(lastCourse.left, greaterThanOrEqualTo(88));
      expect(lastCourse.right, lessThanOrEqualTo(600));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('adjusted sessions move to the new day and period', (
    tester,
  ) async {
    _viewport(tester, const Size(1400, 800));
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final moved = _course(
      '调课课程',
      1,
      1,
      2,
      adjustments: const [
        CourseAdjustRule(
          oldWeek: 1,
          oldWeekday: 1,
          oldStartClass: 1,
          oldEndClass: 2,
          newWeek: 1,
          newWeekday: 4,
          newStartClass: 7,
          newEndClass: 8,
          newLocation: '新教室',
        ),
      ],
    );
    await tester.pumpWidget(_app(settings, _grid(courses: [moved])));
    await tester.pumpAndSettle();
    expect(_card('调课课程'), findsOneWidget);
    expect(find.text('[调课]调课课程'), findsOneWidget);
    expect(find.text('新教室'), findsOneWidget);
    final rect = tester.getRect(_card('调课课程'));
    final thursdayY = tester.getCenter(find.text('周四')).dy;
    expect(rect.top, lessThan(thursdayY));
    expect(rect.bottom, greaterThan(thursdayY));
    expect(rect.left, lessThan(tester.getCenter(find.text('第 7 节')).dx));
    expect(rect.right, greaterThan(tester.getCenter(find.text('第 8 节')).dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile landscape hides scrollbars and still scrolls by touch',
    (tester) async {
      _viewport(tester, const Size(600, 320));
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await tester.pumpWidget(_app(settings, _grid()));
      await tester.pumpAndSettle();
      expect(find.byType(Scrollbar), findsNothing);
      final times = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('schedule-time-scroll')),
          )
          .controller!;
      final days = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('schedule-day-scroll')),
          )
          .controller!;
      await tester.timedDragFrom(
        tester.getCenter(find.byKey(const ValueKey('schedule-day-scroll'))),
        const Offset(-200, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(times.offset, greaterThan(0));
      await tester.timedDrag(
        find.byKey(const ValueKey('schedule-date-scroll')),
        const Offset(0, -120),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(days.offset, greaterThan(0));
      expect(find.byType(Scrollbar), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('portrait keeps days as columns and periods vertical', (
    tester,
  ) async {
    _viewport(tester, const Size(430, 900));
    final settings = AppSettings();
    addTearDown(settings.dispose);
    await tester.pumpWidget(_app(settings, _grid()));
    await tester.pumpAndSettle();
    expect(find.byType(HorizontalScheduleGrid), findsNothing);
    final monday = tester.getCenter(find.text('周一'));
    final wednesday = tester.getCenter(find.text('周三'));
    expect(monday.dy, wednesday.dy);
    expect(monday.dx, lessThan(wednesday.dx));
    final rect = tester.getRect(_card('数学'));
    expect(rect.height, greaterThan(rect.width));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('rotation switches the same schedule between both layouts', (
    tester,
  ) async {
    _viewport(tester, const Size(430, 900));
    final settings = AppSettings();
    addTearDown(settings.dispose);
    await tester.pumpWidget(_app(settings, _grid()));
    await tester.pumpAndSettle();
    expect(find.byType(HorizontalScheduleGrid), findsNothing);
    tester.view.physicalSize = const Size(900, 430);
    await tester.pumpAndSettle();
    expect(find.byType(HorizontalScheduleGrid), findsOneWidget);
    expect(_card('工程项目管理与决策'), findsOneWidget);
    tester.view.physicalSize = const Size(430, 900);
    await tester.pumpAndSettle();
    expect(find.byType(HorizontalScheduleGrid), findsNothing);
    expect(_card('工程项目管理与决策'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final language in ['zh', 'en']) {
      testWidgets(
        'small landscape fits enlarged text in $language and $brightness',
        (tester) async {
          _viewport(tester, const Size(720, 400));
          final settings = AppSettings();
          addTearDown(settings.dispose);
          await tester.pumpWidget(
            _app(
              settings,
              _grid(
                courses: [_course('高等数学与线性代数 Advanced Mathematics', 7, 11, 11)],
              ),
              brightness: brightness,
              language: language,
              scale: 1.5,
            ),
          );
          await tester.pumpAndSettle();
          final scroll = tester.widget<SingleChildScrollView>(
            find.byKey(const ValueKey('schedule-time-scroll')),
          );
          scroll.controller!.jumpTo(
            scroll.controller!.position.maxScrollExtent,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  testWidgets(
    'today and current time markers only appear in the displayed week',
    (tester) async {
      _viewport(tester, const Size(1400, 800));
      final settings = AppSettings();
      addTearDown(settings.dispose);
      final dates = List.generate(7, (i) => DateTime(2026, 9, 28 + i));
      Widget timeline(DateTime now) => _app(
        settings,
        HorizontalScheduleGrid(
          week: 5,
          weekdays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          weekDates: dates,
          now: now,
          onRefresh: () async {},
          cardBuilder: (_, _) => [],
        ),
      );
      await tester.pumpWidget(timeline(DateTime(2026, 9, 30, 14, 20)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-today-row')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-current-time')),
        findsOneWidget,
      );
      final lineX = tester
          .getCenter(find.byKey(const ValueKey('schedule-current-time')))
          .dx;
      expect(lineX, greaterThan(tester.getCenter(find.text('第 4 节')).dx));
      expect(lineX, lessThan(tester.getCenter(find.text('第 6 节')).dx));
      await tester.pumpWidget(timeline(DateTime(2026, 10, 7, 14, 20)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-today-row')), findsNothing);
      expect(find.byKey(const ValueKey('schedule-current-time')), findsNothing);
      await tester.pumpWidget(timeline(DateTime(2026, 9, 30, 23)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-today-row')), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule-current-time')), findsNothing);
    },
  );

  testWidgets(
    'opening a short landscape window centers today and the current time',
    (tester) async {
      _viewport(tester, const Size(600, 320));
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        _app(
          settings,
          HorizontalScheduleGrid(
            week: 5,
            weekdays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            weekDates: List.generate(7, (i) => DateTime(2026, 9, 28 + i)),
            now: DateTime(2026, 10, 2, 15, 10),
            onRefresh: () async {},
            cardBuilder: (_, _) => [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final days = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('schedule-day-scroll')),
      );
      final times = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('schedule-time-scroll')),
      );
      final header = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('schedule-header-scroll')),
      );
      expect(days.controller!.offset, greaterThan(0));
      expect(times.controller!.offset, greaterThan(0));
      final viewport = tester.getRect(
        find.byKey(const ValueKey('schedule-day-scroll')),
      );
      final today = tester.getRect(
        find.byKey(const ValueKey('schedule-today-row')),
      );
      final line = tester.getRect(
        find.byKey(const ValueKey('schedule-current-time')),
      );
      expect(today.center.dy, closeTo(viewport.center.dy, 0.01));
      expect(line.left, closeTo((88 + 600) / 2, 0.01));
      expect(
        header.controller!.offset,
        closeTo(times.controller!.offset, 0.01),
      );
      final headerTop = tester.getTopLeft(find.text('第 6 节')).dy;
      final dates = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('schedule-date-scroll')),
          )
          .controller!;
      expect(dates.offset, closeTo(days.controller!.offset, 0.01));
      days.controller!.jumpTo(0);
      times.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('第 6 节')).dy, headerTop);
      expect(header.controller!.offset, 0);
      expect(dates.offset, 0);
      dates.jumpTo(100);
      await tester.pumpAndSettle();
      expect(days.controller!.offset, closeTo(100, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'minute updates preserve manual scrolling and other weeks start at the beginning',
    (tester) async {
      _viewport(tester, const Size(600, 320));
      final settings = AppSettings();
      addTearDown(settings.dispose);
      Widget timeline(DateTime now) => _app(
        settings,
        HorizontalScheduleGrid(
          week: 5,
          weekdays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          weekDates: List.generate(7, (i) => DateTime(2026, 9, 28 + i)),
          now: now,
          onRefresh: () async {},
          cardBuilder: (_, _) => [],
        ),
      );
      await tester.pumpWidget(timeline(DateTime(2026, 10, 2, 15, 10)));
      await tester.pumpAndSettle();
      final days = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('schedule-day-scroll')),
          )
          .controller!;
      final times = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('schedule-time-scroll')),
          )
          .controller!;
      days.jumpTo(40);
      times.jumpTo(50);
      await tester.pumpAndSettle();
      await tester.pumpWidget(timeline(DateTime(2026, 10, 2, 15, 11)));
      await tester.pumpAndSettle();
      expect(days.offset, 40);
      expect(times.offset, 50);
      await tester.pumpWidget(timeline(DateTime(2026, 10, 9, 15, 11)));
      await tester.pumpAndSettle();
      expect(days.offset, 0);
      expect(times.offset, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('outside lesson hours focuses the nearest end of the time axis', (
    tester,
  ) async {
    _viewport(tester, const Size(600, 320));
    final settings = AppSettings();
    addTearDown(settings.dispose);
    Widget timeline(DateTime now) => _app(
      settings,
      HorizontalScheduleGrid(
        week: 5,
        weekdays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        weekDates: List.generate(7, (i) => DateTime(2026, 9, 28 + i)),
        now: now,
        onRefresh: () async {},
        cardBuilder: (_, _) => [],
      ),
    );
    await tester.pumpWidget(timeline(DateTime(2026, 10, 2, 7)));
    await tester.pumpAndSettle();
    final times = tester
        .widget<SingleChildScrollView>(
          find.byKey(const ValueKey('schedule-time-scroll')),
        )
        .controller!;
    expect(times.offset, 0);
    await tester.pumpWidget(timeline(DateTime(2026, 10, 3, 23)));
    await tester.pumpAndSettle();
    expect(times.offset, times.position.maxScrollExtent);
    expect(find.byKey(const ValueKey('schedule-current-time')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('current time interpolates through lesson and lunch break', () {
    const metrics = HorizontalScheduleMetrics(periodWidth: 100, groupGap: 16);
    expect(metrics.timeOffset(7 * 60), isNull);
    expect(metrics.timeOffset(8 * 60 + 20), 0);
    expect(metrics.timeOffset(12 * 60), 400);
    expect(metrics.timeOffset(13 * 60), 408);
    expect(metrics.timeOffset(14 * 60), 416);
    expect(metrics.timeOffset(21 * 60 + 35), metrics.width);
    expect(metrics.timeOffset(22 * 60), isNull);
  });
}
