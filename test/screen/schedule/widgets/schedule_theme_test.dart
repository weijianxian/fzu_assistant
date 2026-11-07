import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/screen/schedule/widgets/course_card.dart';
import 'package:fzu_assistant/screen/schedule/widgets/horizontal_schedule_grid.dart';
import 'package:fzu_assistant/screen/schedule/widgets/schedule_grid.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

const _course = Course(
  type: '',
  name: '主题测试课程',
  credits: '2',
  electiveType: '',
  examType: '',
  teacher: '',
  scheduleRules: [],
  adjustRules: [],
  rawExamTime: '',
  remark: '',
);
const _location = '教学楼 101';

Widget _app(
  Widget child, {
  ThemeVisuals? visuals,
  Brightness brightness = Brightness.light,
  AppSettings? settings,
}) {
  final app = MaterialApp(
    theme: buildTheme(
      Colors.deepPurple,
      brightness: brightness,
      visuals: visuals,
    ),
    themeAnimationDuration: Duration.zero,
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
  return settings == null
      ? app
      : AppSettingsProvider(settings: settings, child: app);
}

Widget _card({
  required bool horizontal,
  Course course = _course,
  VoidCallback? onTap,
}) => Center(
  child: SizedBox(
    width: horizontal ? 240 : 100,
    height: 100,
    child: CourseCard(
      course: course,
      location: _location,
      isHorizontal: horizontal,
      onTap: onTap,
    ),
  ),
);

Color _cardBackground(WidgetTester tester, bool horizontal) {
  final descendants = find.descendant(
    of: find.byType(CourseCard),
    matching: find.byType(horizontal ? Material : Container),
  );
  return horizontal
      ? tester.widget<Material>(descendants.first).color!
      : (tester.widget<Container>(descendants.first).decoration!
                as BoxDecoration)
            .color!;
}

BorderRadiusGeometry _cardRadius(WidgetTester tester, bool horizontal) {
  if (horizontal) {
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(CourseCard),
            matching: find.byType(Material),
          )
          .first,
    );
    return (material.shape! as RoundedRectangleBorder).borderRadius;
  }
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(CourseCard),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration! as BoxDecoration).borderRadius!;
}

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

BoxDecoration _labelDecoration(WidgetTester tester, String text) =>
    tester
            .widget<Container>(
              find
                  .ancestor(
                    of: find.text(text),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
}

Widget _timeline() => HorizontalScheduleGrid(
  week: 5,
  weekdays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  weekDates: List.generate(7, (i) => DateTime(2026, 9, 28 + i)),
  now: DateTime(2026, 9, 30, 14, 20),
  onRefresh: () async {},
  cardBuilder: (_, _) => [],
);

BoxDecoration _todayRow(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.byKey(const ValueKey('schedule-today-row')),
            )
            .decoration
        as BoxDecoration;

Color _timelineBackground(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(HorizontalScheduleGrid),
            matching: find.byType(ColoredBox),
          )
          .first,
    )
    .color;

void main() {
  for (final horizontal in [false, true]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'no visual extension preserves card defaults: horizontal=$horizontal $brightness',
        (tester) async {
          await tester.pumpWidget(
            _app(_card(horizontal: horizontal), brightness: brightness),
          );
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(CourseCard));
          final theme = Theme.of(context);
          expect(theme.extension<ThemeVisuals>(), isNull);
          expect(
            _cardRadius(tester, horizontal),
            BorderRadius.circular(horizontal ? 10 : 8),
          );
          expect(_cardBackground(tester, horizontal).a, 1);
          expect(
            _textColor(tester, _course.name),
            horizontal
                ? theme.colorScheme.onSurface
                : brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          );
          expect(
            _textColor(tester, _location),
            horizontal
                ? theme.colorScheme.onSurfaceVariant
                : brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'card roles retain ARGB alpha and apply background opacity: horizontal=$horizontal',
      (tester) async {
        const background = Color(0x80345678);
        const title = Color(0xff123456);
        const secondary = Color(0xff654321);
        const accent = Color(0x9955aa77);
        const visuals = ThemeVisuals(
          colors: {
            'courseCard': background,
            'courseCardText': title,
            'courseCardSecondaryText': secondary,
            'courseAccent': accent,
          },
          courseCardOpacity: 0.5,
          courseCardRadius: 18,
        );
        var tapped = false;
        await tester.pumpWidget(
          _app(
            _card(horizontal: horizontal, onTap: () => tapped = true),
            visuals: visuals,
          ),
        );
        await tester.pumpAndSettle();

        final color = _cardBackground(tester, horizontal);
        expect(color.toARGB32(), 0x40345678);
        expect(_cardRadius(tester, horizontal), BorderRadius.circular(18));
        expect(_textColor(tester, _course.name), title);
        expect(_textColor(tester, _location), secondary);
        if (horizontal) {
          final stripe = tester.widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(CourseCard),
                  matching: find.byType(ColoredBox),
                )
                .first,
          );
          expect(stripe.color, accent);
        }
        await tester.tap(find.byType(CourseCard));
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a course color keeps priority over general theme colors: horizontal=$horizontal',
      (tester) async {
        final store = CustomCourseStore.instance;
        final original = store.value;
        addTearDown(() => store.value = original);
        final custom = CustomCourse(
          id: 'theme-test',
          account: 'test-account',
          term: '202601',
          name: '自定义颜色课程',
          startClass: 1,
          endClass: 2,
          startWeek: 1,
          endWeek: 16,
          weekday: 1,
          color: 0xff126449,
        );
        store.value = [custom];
        final card = _card(horizontal: horizontal, course: custom.toCourse());
        await tester.pumpWidget(_app(card));
        await tester.pumpAndSettle();
        final originalColor = _cardBackground(tester, horizontal);
        await tester.pumpWidget(
          _app(
            card,
            visuals: const ThemeVisuals(
              colors: {
                'courseCard': Colors.purple,
                'courseAccent': Colors.orange,
              },
              courseCardOpacity: 0.4,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          _cardBackground(tester, horizontal),
          originalColor.withValues(alpha: 0.4),
        );
        if (horizontal) {
          final stripe = tester.widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(CourseCard),
                  matching: find.byType(ColoredBox),
                )
                .first,
          );
          expect(stripe.color, const Color(0xff126449));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a dark card override keeps default text readable: horizontal=$horizontal',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _card(horizontal: horizontal),
            visuals: const ThemeVisuals(colors: {'courseCard': Colors.black}),
          ),
        );
        await tester.pumpAndSettle();
        expect(_textColor(tester, _course.name), Colors.white);
        expect(_textColor(tester, _location), Colors.white70);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('portrait today labels follow and reset theme roles', (
    tester,
  ) async {
    _viewport(tester, const Size(430, 900));
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final grid = ScheduleGrid(
      courses: const [],
      examRooms: const [],
      week: 1,
      firstMonday: today.subtract(Duration(days: today.weekday - 1)),
      onRefresh: () async {},
    );
    final dateText = '${today.month}/${today.day}';
    await tester.pumpWidget(
      _app(
        grid,
        settings: settings,
        visuals: const ThemeVisuals(
          colors: {
            'todayHighlight': Color(0x88445566),
            'onTodayHighlight': Colors.yellow,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_labelDecoration(tester, dateText).color, const Color(0x88445566));
    expect(_textColor(tester, dateText), Colors.yellow);
    await tester.pumpWidget(_app(grid, settings: settings));
    await tester.pumpAndSettle();
    final scheme = Theme.of(tester.element(find.byType(ScheduleGrid)))
        .colorScheme;
    expect(_labelDecoration(tester, dateText).color, scheme.primaryContainer);
    expect(_textColor(tester, dateText), scheme.onPrimaryContainer);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'horizontal today and divider roles update without losing scroll',
    (tester) async {
      _viewport(tester, const Size(600, 320));
      await tester.pumpWidget(_app(_timeline()));
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('schedule-time-scroll')),
          )
          .controller!;
      scroll.jumpTo(50);
      await tester.pumpAndSettle();
      const divider = Color(0x88667788);
      const highlight = Color(0x88445566);
      await tester.pumpWidget(
        _app(
          _timeline(),
          visuals: const ThemeVisuals(
            colors: {
              'todayHighlight': highlight,
              'onTodayHighlight': Colors.yellow,
              'divider': divider,
            },
            dividerWidth: 2.5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(scroll.offset, 50);
      expect(_todayRow(tester).color, highlight);
      expect((_todayRow(tester).border! as Border).top.color, divider);
      expect((_todayRow(tester).border! as Border).top.width, 2.5);
      final label = _labelDecoration(tester, 'Wed');
      expect(label.color, highlight);
      expect((label.border! as Border).top.color, divider);
      expect((label.border! as Border).top.width, 2.5);
      expect(_textColor(tester, 'Wed'), Colors.yellow);
      expect(_textColor(tester, '9/30'), Colors.yellow);
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('schedule-current-time')),
            )
            .color,
        highlight,
      );
      final lines = find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == divider,
      );
      expect(lines, findsNWidgets(maxCoursePeriod));
      for (final line in lines.evaluate()) {
        expect(tester.getSize(find.byWidget(line.widget)).width, 2.5);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zero divider width hides both lines and hairline borders', (
    tester,
  ) async {
    _viewport(tester, const Size(1400, 800));
    await tester.pumpWidget(
      _app(
        _timeline(),
        visuals: const ThemeVisuals(
          colors: {'divider': Colors.red},
          dividerWidth: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect((_todayRow(tester).border! as Border).top.style, BorderStyle.none);
    expect(
      (_labelDecoration(tester, 'Wed').border! as Border).top.style,
      BorderStyle.none,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == Colors.red,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('horizontal background image shows through themed surfaces', (
    tester,
  ) async {
    _viewport(tester, const Size(1400, 800));
    await tester.pumpWidget(
      _app(
        _timeline(),
        visuals: const ThemeVisuals(
          backgroundImage: 'test-background.jpg',
          surfaceOpacity: 0.35,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scheme = Theme.of(tester.element(find.byType(HorizontalScheduleGrid)))
        .colorScheme;
    expect(_timelineBackground(tester), Colors.transparent);
    expect(
      tester
          .widget<Container>(find.byKey(const ValueKey('schedule-week-header')))
          .color
          ?.a,
      closeTo(0.35, 0.001),
    );
    expect(_labelDecoration(tester, 'Mon').color?.a, closeTo(0.35, 0.001));
    final header = tester.widget<ColoredBox>(
      find
          .ancestor(of: find.text('上午'), matching: find.byType(ColoredBox))
          .first,
    );
    expect(header.color, scheme.surface.withValues(alpha: 0.35));

    await tester.pumpWidget(_app(_timeline()));
    await tester.pumpAndSettle();
    expect(_timelineBackground(tester), scheme.surface);
    expect(
      tester
          .widget<Container>(find.byKey(const ValueKey('schedule-week-header')))
          .color,
      scheme.surfaceContainerLow,
    );
    expect(_labelDecoration(tester, 'Mon').color, scheme.surfaceContainerLow);
    expect(_labelDecoration(tester, 'Wed').color, scheme.primaryContainer);
    expect((_todayRow(tester).border! as Border).top.width, 1);
    expect(tester.takeException(), isNull);
  });
}
