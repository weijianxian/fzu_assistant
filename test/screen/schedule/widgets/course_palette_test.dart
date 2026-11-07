import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/screen/schedule/widgets/course_card.dart';
import 'package:fzu_assistant/service/course_color_palettes.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

const _course = Course(
  type: '',
  name: '课程色卡测试',
  credits: '',
  electiveType: '',
  examType: '',
  teacher: '',
  scheduleRules: [],
  adjustRules: [],
  rawExamTime: '',
  remark: '',
);

const _tailwindLight = [
  0xFF7DD3FC,
  0xFF93C5FD,
  0xFFA5B4FC,
  0xFFC4B5FD,
  0xFFD8B4FE,
  0xFFF0ABFC,
  0xFFF9A8D4,
  0xFFFDA4AF,
  0xFFFDBA74,
  0xFFFCD34D,
  0xFFFDE047,
  0xFFBEF264,
  0xFF86EFAC,
  0xFF6EE7B7,
  0xFF5EEAD4,
  0xFF67E8F9,
  0xFFCBD5E1,
  0xFFD1D5DB,
  0xFFD6D3D1,
  0xFFFCA5A5,
];
const _tailwindDark = [
  0xFF075985,
  0xFF1E40AF,
  0xFF3730A3,
  0xFF5B21B6,
  0xFF6B21A8,
  0xFF86198F,
  0xFF9D174D,
  0xFF9F1239,
  0xFF9A3412,
  0xFF92400E,
  0xFF854D0E,
  0xFF3F6212,
  0xFF166534,
  0xFF065F46,
  0xFF115E59,
  0xFF155E75,
  0xFF1E293B,
  0xFF1F2937,
  0xFF292524,
  0xFF991B1B,
];
const _fuu = [
  0xFF7A6068,
  0xFF8D5270,
  0xFF5A9DBD,
  0xFF307D81,
  0xFFB99799,
  0xFFAA9CC6,
  0xFFA2CAE7,
  0xFF619AA0,
  0xFFD8B4BB,
  0xFFE5B9D3,
  0xFF5BB3DD,
  0xFF94C096,
  0xFFD07A88,
  0xFFF0C4A9,
  0xFF92BAC5,
  0xFF9AD1CD,
  0xFFF39E9D,
  0xFFE0B092,
  0xFF7D89AB,
  0xFFBBD5B4,
  0xFFC6A5B6,
  0xFF87B9C1,
  0xFFE3A8A1,
  0xFFA5C7A6,
  0xFFD4B8CE,
];

Future<ThemeData> _pump(
  WidgetTester tester, {
  required bool horizontal,
  required Brightness brightness,
  ThemeVisuals? visuals,
  Course course = _course,
}) async {
  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: brightness,
    ),
    extensions: [?visuals],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      themeAnimationDuration: Duration.zero,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            height: 120,
            child: CourseCard(
              course: course,
              location: '教学楼 101',
              isHorizontal: horizontal,
            ),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  return theme;
}

Finder _inside(Type type) =>
    find.descendant(of: find.byType(CourseCard), matching: find.byType(type));

Color _background(WidgetTester tester, bool horizontal) => horizontal
    ? tester.widget<Material>(_inside(Material).first).color!
    : (tester.widget<Container>(_inside(Container).first).decoration!
              as BoxDecoration)
          .color!;

Color _accent(WidgetTester tester) =>
    tester.widget<ColoredBox>(_inside(ColoredBox).first).color;

Color _tint(Color accent, ThemeData theme) => Color.alphaBlend(
  accent.withValues(
    alpha: accent.a * (theme.brightness == Brightness.dark ? 0.12 : 0.08),
  ),
  theme.colorScheme.surfaceContainerLow,
);

void _expectForeground(
  WidgetTester tester,
  ThemeData theme,
  bool horizontal, {
  String name = '课程色卡测试',
}) {
  final dark =
      ThemeData.estimateBrightnessForColor(
        Color.alphaBlend(
          _background(tester, horizontal),
          theme.colorScheme.surface,
        ),
      ) ==
      Brightness.dark;
  final followsScheme =
      horizontal && dark == (theme.brightness == Brightness.dark);
  expect(
    tester.widget<Text>(find.text(name)).style!.color,
    followsScheme
        ? theme.colorScheme.onSurface
        : (dark ? Colors.white : Colors.black87),
  );
  expect(
    tester.widget<Text>(find.text('教学楼 101')).style!.color,
    followsScheme
        ? theme.colorScheme.onSurfaceVariant
        : (dark ? Colors.white70 : Colors.black54),
  );
}

void main() {
  setUp(() {
    final previous = CustomCourseStore.instance.value;
    CustomCourseStore.instance.value = const [];
    addTearDown(() => CustomCourseStore.instance.value = previous);
  });

  test(
    'presets retain original Tailwind and FUU colors including dark alpha',
    () {
      expect(
        CourseColorPalettes.colors('tailwind', dark: false),
        _tailwindLight,
      );
      expect(CourseColorPalettes.colors('tailwind', dark: true), _tailwindDark);
      expect(CourseColorPalettes.colors('fuu', dark: false), _fuu);
      expect(
        CourseColorPalettes.colors('fuu', dark: true),
        _fuu.map((color) => (color & 0x00FFFFFF) | 0xC0000000).toList(),
      );
    },
  );

  for (final horizontal in [false, true]) {
    for (final brightness in Brightness.values) {
      final dark = brightness == Brightness.dark;
      final label = 'horizontal=$horizontal $brightness';
      testWidgets('default Tailwind preserves original appearance $label', (
        tester,
      ) async {
        final index = _course.name.hashCode.abs() % 20;
        final background = Color(
          (dark ? _tailwindDark : _tailwindLight)[index],
        );
        final accent = Color((dark ? _tailwindLight : _tailwindDark)[index]);
        for (final visuals in <ThemeVisuals?>[null, const ThemeVisuals()]) {
          final theme = await _pump(
            tester,
            horizontal: horizontal,
            brightness: brightness,
            visuals: visuals,
          );
          expect(
            _background(tester, horizontal),
            horizontal ? _tint(accent, theme) : background,
          );
          if (horizontal) expect(_accent(tester), accent);
          _expectForeground(tester, theme, horizontal);
        }
      });

      testWidgets('FUU selects stable mode color and composes alpha $label', (
        tester,
      ) async {
        final rgb = _fuu[_course.name.hashCode.abs() % _fuu.length];
        final selected = Color(dark ? (rgb & 0x00FFFFFF) | 0xC0000000 : rgb);
        final theme = await _pump(
          tester,
          horizontal: horizontal,
          brightness: brightness,
          visuals: const ThemeVisuals(coursePaletteKey: 'fuu'),
        );
        expect(
          _background(tester, horizontal),
          horizontal ? _tint(selected, theme) : selected,
        );
        if (horizontal) expect(_accent(tester), selected);
        _expectForeground(tester, theme, horizontal);
      });

      testWidgets('DIY overrides preset and uses actual foreground $label', (
        tester,
      ) async {
        // Both opaque extremes and alpha exercise contrast independently of mode.
        for (final selected in [
          Colors.white,
          Colors.black,
          const Color(0x40FFFFFF),
        ]) {
          final theme = await _pump(
            tester,
            horizontal: horizontal,
            brightness: brightness,
            visuals: ThemeVisuals(
              coursePaletteKey: 'fuu',
              coursePalette: [selected],
              courseCardOpacity: 0.75,
            ),
          );
          final expected = horizontal ? _tint(selected, theme) : selected;
          expect(
            _background(tester, horizontal),
            expected.withValues(alpha: expected.a * 0.75),
          );
          if (horizontal) expect(_accent(tester), selected);
          _expectForeground(tester, theme, horizontal);
        }
      });

      testWidgets('single-course color takes precedence over theme $label', (
        tester,
      ) async {
        final custom = CustomCourse(
          id: 'palette',
          account: 'test',
          term: '202601',
          name: _course.name,
          startClass: 1,
          endClass: 2,
          startWeek: 1,
          endWeek: 19,
          weekday: 1,
          color: 0xFF123456,
        );
        CustomCourseStore.instance.value = [custom];
        final theme = await _pump(
          tester,
          horizontal: horizontal,
          brightness: brightness,
          course: custom.toCourse(),
          visuals: const ThemeVisuals(
            coursePaletteKey: 'fuu',
            coursePalette: [Colors.yellow],
            colors: {'courseCard': Colors.red, 'courseAccent': Colors.green},
          ),
        );
        const own = Color(0xFF123456);
        expect(
          _background(tester, horizontal),
          horizontal ? _tint(own, theme) : own,
        );
        if (horizontal) expect(_accent(tester), own);
        _expectForeground(tester, theme, horizontal);
      });

      testWidgets('theme single colors override DIY and preset $label', (
        tester,
      ) async {
        final theme = await _pump(
          tester,
          horizontal: horizontal,
          brightness: brightness,
          visuals: ThemeVisuals(
            coursePaletteKey: 'fuu',
            coursePalette: const [Colors.yellow],
            colors: {
              'courseCard': dark ? Colors.white : Colors.black,
              'courseAccent': Colors.pink,
            },
          ),
        );
        expect(
          _background(tester, horizontal),
          dark ? Colors.white : Colors.black,
        );
        if (horizontal) expect(_accent(tester), Colors.pink);
        _expectForeground(tester, theme, horizontal);
      });

      testWidgets('palette switching and rebuilding retain name index $label', (
        tester,
      ) async {
        const diy = [Colors.red, Colors.green, Colors.blue];
        for (final visuals in [
          const ThemeVisuals(),
          const ThemeVisuals(coursePaletteKey: 'fuu'),
          const ThemeVisuals(coursePalette: diy),
          const ThemeVisuals(coursePaletteKey: 'fuu'),
          const ThemeVisuals(),
        ]) {
          final colors = visuals.coursePalette.isNotEmpty
              ? visuals.coursePalette
              : CourseColorPalettes.colors(
                  visuals.coursePaletteKey,
                  dark: horizontal && visuals.coursePaletteKey == 'tailwind'
                      ? !dark
                      : dark,
                ).map(Color.new).toList();
          final selected = colors[_course.name.hashCode.abs() % colors.length];
          for (var rebuild = 0; rebuild < 2; rebuild++) {
            final theme = await _pump(
              tester,
              horizontal: horizontal,
              brightness: brightness,
              visuals: visuals,
            );
            expect(
              _background(tester, horizontal).toARGB32(),
              (horizontal ? _tint(selected, theme) : selected).toARGB32(),
            );
            if (horizontal) expect(_accent(tester), selected);
          }
        }
      });
    }
  }
}
