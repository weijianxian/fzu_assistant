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
import 'package:fzu_assistant/screen/campus_code/campus_code_page.dart';
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
  RouteFactory? onGenerateRoute,
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
      child: child!,
    ),
    routes: {
      AppRoutes.homeSettings: (_) =>
          const Scaffold(body: Text('Settings page')),
    },
    onGenerateRoute: onGenerateRoute,
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
    SharedPreferences.setMockInitialValues({
      'home_style': 'timeline',
      'timeline_days': 7,
    });
    FlutterSecureStorage.setMockInitialValues({});
    final offline = InterceptorsWrapper(
      onRequest: (request, handler) => handler.reject(
        DioException(requestOptions: request, error: 'Offline widget test'),
      ),
    );
    ApiClient.instance.dio.interceptors.add(offline);
    addTearDown(() => ApiClient.instance.dio.interceptors.remove(offline));
  });

  testWidgets('缓存模式提示可见且缺少考场缓存仍展示课表', (tester) async {
    _viewport(tester, const Size(400, 800));
    final settings = AppSettings();
    addTearDown(settings.dispose);
    await tester.runAsync(() async {
      await _cacheSchedule();
      await CacheHelper.removeAll([SpKeys.cacheExamRoomsMap]);
    });
    ApiClient.instance.usingCachedSession.value = true;
    addTearDown(() => ApiClient.instance.usingCachedSession.value = false);
    await tester.pumpWidget(_app(settings, child: const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('正在展示历史缓存'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.textContaining('数学'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(400, 900), const Size(1200, 700)]) {
    for (final cached in [true, false]) {
      testWidgets(
        'home consumes system insets once at $size (cached=$cached)',
        (tester) async {
          _viewport(tester, size);
          final landscape = size.width > size.height;
          final insets = landscape
              ? const EdgeInsets.fromLTRB(40, 24, 20, 34)
              : const EdgeInsets.only(top: 48, bottom: 34);
          final settings = AppSettings();
          addTearDown(settings.dispose);
          await tester.runAsync(_cacheSchedule);
          ApiClient.instance.usingCachedSession.value = cached;
          addTearDown(
            () => ApiClient.instance.usingCachedSession.value = false,
          );
          await tester.pumpWidget(
            _app(settings, child: const HomeScreen(), insets: insets),
          );
          await tester.pumpAndSettle();

          double contentTop() {
            if (!cached) return 0;
            final banner = tester.getRect(find.byType(MaterialBanner));
            expect(banner.top, 0);
            expect(
              tester.getRect(find.textContaining('正在展示历史缓存')).top,
              greaterThanOrEqualTo(insets.top),
            );
            return banner.bottom;
          }

          void expectAppBarsBelowBanner() {
            final top = contentTop();
            expect(find.byType(AppBar), findsAtLeastNWidgets(1));
            for (final element in find.byType(AppBar).evaluate()) {
              final rect = tester.getRect(find.byWidget(element.widget));
              expect(rect.top, top);
              expect(rect.height, kToolbarHeight + (cached ? 0 : insets.top));
            }
          }

          if (landscape) {
            final grid = tester.getRect(find.byType(HorizontalScheduleGrid));
            final rail = tester.getRect(find.byType(NavigationRail));
            expect(grid.top, cached ? contentTop() : insets.top);
            expect(grid.bottom, size.height);
            expect(rail.top, 0);
            expect(rail.bottom, size.height);
            expect(rail.left, 0);
            expect(grid.left, rail.right);
            final railLabel = tester.getRect(
              find.descendant(
                of: find.byType(NavigationRail),
                matching: find.text('课程表'),
              ),
            );
            expect(railLabel.left, greaterThanOrEqualTo(insets.left));
            expect(railLabel.top, greaterThanOrEqualTo(insets.top));
            expect(
              railLabel.bottom,
              lessThanOrEqualTo(size.height - insets.bottom),
            );
            expect(grid.right, size.width - insets.right);
            expect(
              tester
                  .getRect(find.byKey(const ValueKey('schedule-week-header')))
                  .top,
              grid.top,
            );
          } else {
            expectAppBarsBelowBanner();
            final appBar = tester.getRect(find.byType(AppBar));
            expect(
              tester.getCenter(find.byIcon(Icons.settings_outlined)).dy,
              contentTop() + (cached ? 0 : insets.top) + kToolbarHeight / 2,
            );
            final weekday = tester.getRect(find.text('周一').first);
            expect(weekday.top, greaterThanOrEqualTo(appBar.bottom));
            expect(weekday.bottom, lessThanOrEqualTo(appBar.bottom + 48));
            final navigation = tester.getRect(find.byType(NavigationBar));
            final label = tester.getRect(
              find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text('课程表'),
              ),
            );
            expect(navigation.bottom, size.height);
            expect(
              label.bottom,
              lessThanOrEqualTo(size.height - insets.bottom),
            );
          }

          final navigation = landscape
              ? find.byType(NavigationRail)
              : find.byType(NavigationBar);
          for (final label in ['工具箱', '一码通', '我的']) {
            await tester.tap(
              find.descendant(of: navigation, matching: find.text(label)),
            );
            await tester.pumpAndSettle();
            expectAppBarsBelowBanner();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in [const Size(400, 800), const Size(1200, 800)]) {
    for (final cached in [true, false]) {
      testWidgets(
        'add custom course stays left of settings and uses the displayed term at $size (cached=$cached)',
        (tester) async {
          _viewport(tester, size);
          final settings = AppSettings();
          addTearDown(settings.dispose);
          if (cached) {
            await tester.runAsync(_cacheSchedule);
          } else {
            settings.selectedSemesterKey.value = '202501';
          }
          CustomCourseEditArgs? args;
          await tester.pumpWidget(
            _app(
              settings,
              onGenerateRoute: (route) {
                expect(route.name, AppRoutes.customCourseEdit);
                args = route.arguments as CustomCourseEditArgs;
                return MaterialPageRoute<void>(
                  settings: route,
                  builder: (_) =>
                      const Scaffold(body: Text('custom-course-editor')),
                );
              },
            ),
          );
          if (cached) {
            await tester.pumpAndSettle();
          } else {
            // A failed academic query may leave its loading indicator active;
            // creating a local course must remain available regardless.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
          }
          final add = find.byTooltip('添加课程');
          final settingsButton = find.byIcon(Icons.settings_outlined);
          final addRect = tester.getRect(add);
          final settingsRect = tester.getRect(settingsButton);
          expect(addRect.right, lessThanOrEqualTo(settingsRect.left));
          expect(addRect.center.dy, settingsRect.center.dy);
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(args?.term, cached ? '202601' : '202501');
          expect(args?.course, isNull);
          expect(find.text('custom-course-editor'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in [const Size(400, 800), const Size(1200, 800)]) {
    testWidgets('campus code is a main navigation tab at $size', (
      tester,
    ) async {
      _viewport(tester, size);
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await tester.runAsync(_cacheSchedule);
      await tester.pumpWidget(_app(settings, child: const HomeScreen()));
      await tester.pumpAndSettle();
      final navigation = size.width > size.height
          ? find.byType(NavigationRail)
          : find.byType(NavigationBar);
      await tester.tap(
        find.descendant(of: navigation, matching: find.text('一码通')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CampusCodePage), findsOneWidget);
      expect(find.text('天视图'), findsNothing);
      expect(
        tester.widget<PageView>(find.byType(PageView)).scrollDirection,
        Axis.vertical,
      );
      await tester.tap(
        find.descendant(of: navigation, matching: find.text('我的')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CampusCodePage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

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

    expect(find.text('天视图'), findsNothing);
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
    expect(rail.left, 0);
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
                child: FloatingScheduleControls(
                  onAdd: () {},
                  onSettings: () {},
                ),
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
