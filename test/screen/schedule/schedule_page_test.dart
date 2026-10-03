import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/home/home_screen.dart';
import 'package:fzu_assistant/screen/schedule/schedule.dart';
import 'package:fzu_assistant/screen/schedule/widgets/floating_schedule_controls.dart';
import 'package:fzu_assistant/screen/schedule/widgets/horizontal_schedule_grid.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(
  AppSettings settings, {
  Widget child = const SchedulePage(),
  EdgeInsets insets = EdgeInsets.zero,
  String language = 'zh',
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => AppSettingsProvider(
  settings: settings,
  child: MaterialApp(
    theme: buildTheme(Colors.deepPurple, brightness: brightness),
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: insets,
        viewPadding: insets,
        textScaler: TextScaler.linear(scale),
      ),
      child: SafeArea(top: false, bottom: false, child: child!),
    ),
    routes: {
      AppRoutes.homeSettings: (_) =>
          const Scaffold(body: Text('Settings page')),
    },
    home: child,
  ),
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
}

Future<void> _cacheSchedule() async {
  const term = '202601';
  final now = DateTime.now();
  final monday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1 + 28));
  await CacheHelper.saveMap(
    SpKeys.cacheSchoolCalendar,
    SchoolCalendar(
      currentTerm: term,
      terms: [
        CalTerm(
          termId: term,
          schoolYear: '2026',
          term: term,
          startDate: monday.toIso8601String(),
          endDate: monday.add(const Duration(days: 130)).toIso8601String(),
        ),
      ],
    ).toJson(),
  );
  await CacheHelper.saveForKey(SpKeys.cacheCoursesMap, term, {
    'courses': [
      Course(
        type: '',
        name: '数学',
        credits: '2',
        electiveType: '',
        examType: '',
        teacher: '教师',
        rawExamTime: '',
        remark: '',
        adjustRules: [],
        scheduleRules: [
          CourseScheduleRule(
            location: '西2-101',
            startClass: 1,
            endClass: 2,
            startWeek: 1,
            endWeek: 19,
            weekday: 1,
            single: true,
            double: true,
          ),
        ],
      ).toJson(),
    ],
  });
  await CacheHelper.saveForKey(SpKeys.cacheExamRoomsMap, term, []);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final offline = InterceptorsWrapper(
      onRequest: (request, handler) => handler.reject(
        DioException(requestOptions: request, error: 'Offline widget test'),
      ),
    );
    ApiClient.instance.dio.interceptors.add(offline);
    addTearDown(() => ApiClient.instance.dio.interceptors.remove(offline));
  });

  testWidgets('floating controls overlay the full grid inside system insets', (
    tester,
  ) async {
    _viewport(tester, const Size(1400, 800));
    final settings = AppSettings();
    addTearDown(settings.dispose);
    await tester.runAsync(_cacheSchedule);
    await tester.pumpWidget(
      _app(settings, insets: const EdgeInsets.fromLTRB(16, 24, 20, 0)),
    );
    await tester.pumpAndSettle();

    final grid = tester.getRect(find.byType(HorizontalScheduleGrid));
    final buttons = tester.getRect(find.byType(FloatingScheduleControls));
    expect(find.byType(AppBar), findsNothing);
    expect(grid, const Rect.fromLTWH(16, 24, 1364, 776));
    expect(buttons.top, grid.top);
    expect(buttons.overlaps(grid), isTrue);
    final week = tester.getRect(
      find.byKey(const ValueKey('schedule-week-header')),
    );
    expect(week.topLeft, grid.topLeft);
    expect(find.text('日期'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FloatingScheduleControls),
        matching: find.text('第 5 周'),
      ),
      findsNothing,
    );
    expect(find.text('第 5 周'), findsOneWidget);

    await tester.tap(find.byTooltip('下一周'));
    await tester.pumpAndSettle();
    expect(find.text('第 6 周'), findsOneWidget);
    await tester.tap(find.text('第 6 周'));
    await tester.pumpAndSettle();
    expect(find.text('第 6 周'), findsOneWidget);
    await tester.tap(find.byTooltip('上一周'));
    await tester.pumpAndSettle();
    expect(find.text('第 5 周'), findsOneWidget);

    await tester.tap(find.text('天视图'));
    await tester.pumpAndSettle();
    expect(settings.homeStyleKey.value, AppSettings.timelineHomeStyle);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Settings page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait uses the AppBar after rotating from landscape', (
    tester,
  ) async {
    _viewport(tester, const Size(900, 600));
    final settings = AppSettings();
    addTearDown(settings.dispose);
    await tester.runAsync(_cacheSchedule);
    await tester.pumpWidget(_app(settings));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingScheduleControls), findsOneWidget);

    tester.view.physicalSize = const Size(600, 900);
    await tester.pumpAndSettle();
    expect(find.byType(FloatingScheduleControls), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('第 5 周'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar remains separate and clickable beside the timetable', (
    tester,
  ) async {
    _viewport(tester, const Size(1400, 800));
    final settings = AppSettings();
    addTearDown(settings.dispose);
    await tester.runAsync(_cacheSchedule);
    await tester.pumpWidget(
      _app(
        settings,
        child: const HomeScreen(),
        insets: const EdgeInsets.fromLTRB(40, 24, 16, 0),
      ),
    );
    await tester.pumpAndSettle();
    final rail = tester.getRect(find.byType(NavigationRail));
    final grid = tester.getRect(find.byType(HorizontalScheduleGrid));
    final header = tester.getRect(
      find.byKey(const ValueKey('schedule-week-header')),
    );
    expect(rail.left, 40);
    expect(grid.left, rail.right);
    expect(grid.right, 1400 - 16);
    expect(grid.top, 24);
    expect(header.left, grid.left);
    expect(header.overlaps(rail), isFalse);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('工具箱'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
    expect(find.byType(HorizontalScheduleGrid), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('课程表'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HorizontalScheduleGrid), findsOneWidget);
    await tester.tap(find.byTooltip('下一周'));
    await tester.pumpAndSettle();
    expect(find.text('第 6 周'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('课程表'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('第 5 周'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty floating space passes taps to the timetable below', (
    tester,
  ) async {
    _viewport(tester, const Size(1200, 600));
    final settings = AppSettings();
    addTearDown(settings.dispose);
    var taps = 0;
    await tester.pumpWidget(
      _app(
        settings,
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const ColoredBox(color: Colors.transparent),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FloatingScheduleControls(onSettings: () {}),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(450, 36));
    expect(taps, 1);
  });

  for (final language in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'compact floating buttons support $language $brightness large text',
        (tester) async {
          _viewport(tester, const Size(650, 360));
          final settings = AppSettings();
          addTearDown(settings.dispose);
          await tester.runAsync(_cacheSchedule);
          await tester.pumpWidget(
            _app(
              settings,
              insets: const EdgeInsets.only(top: 24),
              language: language,
              brightness: brightness,
              scale: 1.5,
            ),
          );
          await tester.pumpAndSettle();
          final week = tester.getRect(
            find.byKey(const ValueKey('schedule-week-header')),
          );
          final next = tester.getRect(find.byIcon(Icons.chevron_right));
          expect(week.top, 24);
          expect(next.top, greaterThan(24));
          expect(next.left, greaterThanOrEqualTo(week.right));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
