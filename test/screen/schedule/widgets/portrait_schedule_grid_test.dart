import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/screen/schedule/widgets/course_card.dart';
import 'package:fzu_assistant/screen/schedule/widgets/schedule_grid.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

final _monday = DateTime(2026, 11, 2);
final _column = find.byKey(const ValueKey('portrait-schedule-today-column'));
final _line = find.byKey(const ValueKey('portrait-schedule-current-time'));

Course _course(int period, {int weekday = 1}) => Course(
  type: '',
  name: '课程$period',
  credits: '2',
  electiveType: '',
  examType: '',
  teacher: '测试教师',
  rawExamTime: '',
  remark: '',
  adjustRules: const [],
  scheduleRules: [
    CourseScheduleRule(
      location: 'A101',
      startClass: period,
      endClass: period,
      startWeek: 1,
      endWeek: 16,
      weekday: weekday,
      single: true,
      double: true,
    ),
  ],
);

Finder _card(int period) => find.byWidgetPredicate(
  (widget) => widget is CourseCard && widget.course.name == '课程$period',
);

Widget _app(
  AppSettings settings, {
  DateTime? now,
  DateTime? firstMonday,
  int week = 1,
  List<Course> courses = const [],
  ThemeVisuals? visuals,
  Brightness brightness = Brightness.light,
}) => AppSettingsProvider(
  settings: settings,
  child: MaterialApp(
    theme: buildTheme(
      Colors.deepPurple,
      brightness: brightness,
      visuals: visuals,
    ).copyWith(platform: TargetPlatform.android),
    themeAnimationDuration: Duration.zero,
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ScheduleGrid(
        now: now,
        firstMonday: firstMonday,
        week: week,
        courses: courses,
        examRooms: const [],
        onRefresh: () async {},
      ),
    ),
  ),
);

AppSettings _setup(WidgetTester tester, [Size size = const Size(430, 900)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final settings = AppSettings();
  addTearDown(settings.dispose);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  return settings;
}

ScrollPosition _scrollPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(ScheduleGrid),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

void main() {
  testWidgets('today column spans all periods and aligns with its date', (
    tester,
  ) async {
    final settings = _setup(tester);
    await tester.pumpWidget(
      _app(
        settings,
        firstMonday: _monday,
        now: DateTime(2026, 11, 4, 8, 35),
        courses: [_course(1, weekday: 3), _course(maxCoursePeriod, weekday: 3)],
      ),
    );
    await tester.pumpAndSettle();

    final column = tester.getRect(_column);
    final header = tester.getRect(
      find
          .ancestor(of: find.text('11/4'), matching: find.byType(Container))
          .first,
    );
    final first = tester.getRect(_card(1));
    final last = tester.getRect(_card(maxCoursePeriod));
    expect(
      column.center.dx,
      closeTo(tester.getCenter(find.text('11/4')).dx, 0.01),
    );
    expect(column.left, lessThan(first.left));
    expect(column.right, greaterThan(first.right));
    expect(header.left, closeTo(column.left, 0.01));
    expect(header.right, closeTo(column.right, 0.01));
    expect(header.bottom, closeTo(column.top, 0.01));
    expect(column.top, closeTo(first.top - 1, 0.01));
    expect(column.bottom, closeTo(last.bottom + 1, 0.01));
    final line = tester.getRect(_line);
    expect(line.height, 2);
    expect(line.left, lessThanOrEqualTo(column.left));
    expect(line.right, greaterThanOrEqualTo(column.right));
    // 8:35 位于第一节的三分之一处，而不是整行的中央。
    expect(line.top, closeTo(column.top + (first.height + 2) / 3, 0.01));
    final scheme = Theme.of(tester.element(find.byType(ScheduleGrid)))
        .colorScheme;
    expect(
      tester.widget<ColoredBox>(_column).color,
      scheme.primary.withValues(alpha: 0.07),
    );
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('custom highlight and wallpaper opacity: $brightness', (
      tester,
    ) async {
      final settings = _setup(tester);
      await tester.pumpWidget(
        _app(
          settings,
          firstMonday: _monday,
          now: DateTime(2026, 11, 4, 14, 20),
          brightness: brightness,
          visuals: const ThemeVisuals(
            colors: {
              'todayHighlight': Color(0x80445566),
              'onTodayHighlight': Colors.yellow,
            },
            backgroundImage: 'wallpaper.jpg',
            surfaceOpacity: 0.5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<ColoredBox>(_column).color.toARGB32(), 0x40445566);
      expect(tester.widget<ColoredBox>(_line).color.toARGB32(), 0x80445566);
      expect(
        tester.widget<Text>(find.text('11/4')).style?.color,
        Colors.yellow,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _app(
          settings,
          firstMonday: _monday,
          now: DateTime(2026, 11, 4, 14, 20),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      final scheme = Theme.of(tester.element(find.byType(ScheduleGrid)))
          .colorScheme;
      expect(
        tester.widget<ColoredBox>(_column).color,
        scheme.primary.withValues(alpha: 0.07),
      );
      expect(
        tester.widget<Text>(find.text('11/4')).style?.color,
        scheme.onPrimaryContainer,
      );
    });
  }

  testWidgets('another week or missing dates has no current-day decoration', (
    tester,
  ) async {
    final settings = _setup(tester);
    for (final firstMonday in [_monday, null]) {
      await tester.pumpWidget(
        _app(
          settings,
          firstMonday: firstMonday,
          week: 2,
          now: DateTime(2026, 11, 4, 14, 20),
        ),
      );
      await tester.pumpAndSettle();
      expect(_column, findsNothing);
      expect(_line, findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('time outside the course range keeps only today background', (
    tester,
  ) async {
    final settings = _setup(tester);
    for (final time in [
      DateTime(2026, 11, 2, 8, 19),
      DateTime(2026, 11, 2, 21, 36),
    ]) {
      await tester.pumpWidget(_app(settings, firstMonday: _monday, now: time));
      await tester.pumpAndSettle();
      expect(_column, findsOneWidget);
      expect(_line, findsNothing);
    }
  });

  testWidgets(
    'breaks stay at period boundaries without drifting into classes',
    (tester) async {
      final settings = _setup(tester);
      final courses = [for (var i = 1; i <= maxCoursePeriod; i++) _course(i)];
      // 用实际课程边缘验证课间、午休和晚饭，而不是复制时间映射算法。
      for (final (hour, minute, period, atEnd) in [
        (8, 20, 1, false),
        (9, 5, 1, true),
        (9, 10, 1, true),
        (9, 15, 2, false),
        (12, 0, 4, true),
        (13, 0, 4, true),
        (14, 0, 5, false),
        (17, 30, 8, true),
        (18, 0, 8, true),
        (19, 0, 9, false),
      ]) {
        await tester.pumpWidget(
          _app(
            settings,
            firstMonday: _monday,
            now: DateTime(2026, 11, 2, hour, minute),
            courses: courses,
          ),
        );
        await tester.pumpAndSettle();
        final card = tester.getRect(_card(period));
        expect(
          tester.getTopLeft(_line).dy,
          closeTo(atEnd ? card.bottom + 1 : card.top - 1, 0.01),
          reason: '$hour:$minute should meet period $period',
        );
      }
      await tester.pumpWidget(
        _app(
          settings,
          firstMonday: _monday,
          now: DateTime(2026, 11, 2, 21, 35),
          courses: courses,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(_line).bottom, tester.getRect(_column).bottom);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('line allows course taps and small-screen scrolling', (
    tester,
  ) async {
    final settings = _setup(tester, const Size(320, 480));
    await tester.pumpWidget(
      _app(
        settings,
        firstMonday: _monday,
        now: DateTime(2026, 11, 2, 8, 40),
        courses: [_course(1)],
      ),
    );
    await tester.pumpAndSettle();
    final card = tester.getRect(_card(1));
    await tester.tapAt(Offset(card.center.dx, tester.getCenter(_line).dy));
    await tester.pumpAndSettle();
    expect(find.text('测试教师'), findsOneWidget);
    Navigator.of(tester.element(find.text('测试教师'))).pop();
    await tester.pumpAndSettle();

    final position = _scrollPosition(tester);
    await tester.timedDragFrom(
      Offset(tester.getRect(_card(1)).center.dx, tester.getCenter(_line).dy),
      const Offset(0, -48),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    final offset = position.pixels;
    await tester.pumpWidget(
      _app(
        settings,
        firstMonday: _monday,
        now: DateTime(2026, 11, 2, 8, 41),
        courses: [_course(1)],
      ),
    );
    await tester.pumpAndSettle();
    expect(_scrollPosition(tester).pixels, offset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('midnight moves today and preserves scroll; Sunday leaves week', (
    tester,
  ) async {
    final settings = _setup(tester, const Size(320, 480));
    Future<void> show(DateTime time) async {
      await tester.pumpWidget(_app(settings, firstMonday: _monday, now: time));
      await tester.pumpAndSettle();
    }

    await show(DateTime(2026, 11, 2, 23, 59));
    final mondayX = tester.getCenter(_column).dx;
    final columnWidth = tester.getSize(_column).width;
    final position = _scrollPosition(tester);
    position.jumpTo(80);
    await tester.pump();
    await show(DateTime(2026, 11, 3));
    expect(tester.getCenter(_column).dx, closeTo(mondayX + columnWidth, 0.01));
    expect(_line, findsNothing);
    expect(_scrollPosition(tester).pixels, 80);
    await show(DateTime(2026, 11, 8, 23, 59));
    expect(_column, findsOneWidget);
    await show(DateTime(2026, 11, 9));
    expect(_column, findsNothing);
    expect(_line, findsNothing);
    expect(_scrollPosition(tester).pixels, 80);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live minute updates preserve scroll and cancel on removal', (
    tester,
  ) async {
    final settings = _setup(tester, const Size(320, 480));
    final today = DateUtils.dateOnly(DateTime.now());
    await tester.pumpWidget(
      _app(
        settings,
        firstMonday: today.subtract(Duration(days: today.weekday - 1)),
      ),
    );
    await tester.pumpAndSettle();
    final position = _scrollPosition(tester);
    position.jumpTo(70);
    await tester.pump(const Duration(minutes: 2));
    expect(_scrollPosition(tester), same(position));
    expect(position.pixels, 70);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 2));
    expect(tester.takeException(), isNull);
  });
}
