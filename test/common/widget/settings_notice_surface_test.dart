import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/course_reminder_settings_page.dart';
import 'package:fzu_assistant/screen/settings/third_party_settings_page.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capture = ValueKey('notice-frame');
const _backdrop = Color(0xff2585c5);
const _surface = Color(0xffe3dccf);
const _lightBackground = Color(0xfff7f2e9);
const _darkBackground = Color(0xff211f1b);

ThemeData _theme({
  InterfaceStyle style = InterfaceStyle.classic,
  Brightness brightness = Brightness.light,
  bool wallpaper = true,
  double opacity = 0.4,
}) => buildTheme(
  Colors.teal,
  brightness: brightness,
  interfaceStyle: style,
  visuals: ThemeVisuals(
    backgroundImage: wallpaper ? 'wallpaper.png' : null,
    colors: {
      'surfaceContainerLow': _surface,
      'surface': brightness == Brightness.light
          ? _lightBackground
          : _darkBackground,
    },
    surfaceOpacity: opacity,
    cardRadius: 30,
  ),
  // Surface tests supply a solid backdrop to measure the panel's compositing.
  // Decoding and painting real wallpaper is covered by the navigation tests.
).copyWith(pageTransitionsTheme: const PageTransitionsTheme());

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  themeAnimationDuration: Duration.zero,
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: RepaintBoundary(
    key: _capture,
    child: ColoredBox(
      color: theme.extension<ThemeVisuals>()!.hasBackground
          ? _backdrop
          : theme.colorScheme.surface,
      child: Material(
        type: MaterialType.transparency,
        child: Align(alignment: Alignment.topCenter, child: child),
      ),
    ),
  ),
);

Future<Color> _pixel(WidgetTester tester, Offset point) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  return (await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 1);
    try {
      final data = (await picture.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final index = (point.dy.floor() * picture.width + point.dx.floor()) * 4;
      return Color.fromARGB(
        bytes[index + 3],
        bytes[index],
        bytes[index + 1],
        bytes[index + 2],
      );
    } finally {
      picture.dispose();
    }
  }))!;
}

void _expectColor(Color actual, Color expected) {
  for (final shift in [0, 8, 16, 24]) {
    expect(
      (actual.toARGB32() >> shift) & 0xff,
      closeTo((expected.toARGB32() >> shift) & 0xff, 2),
    );
  }
}

void _viewport(WidgetTester tester, [Size size = const Size(500, 1200)]) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
}

Finder _materialBehind(Finder content) =>
    find.ancestor(of: content, matching: find.byType(Material)).first;

void _expectUnbacked(WidgetTester tester, Finder content) {
  final material = tester.widget<Material>(_materialBehind(content));
  expect(
    material.type == MaterialType.transparency ||
        material.color == Colors.transparent,
    isTrue,
  );
}

Future<void> _expectInfoCardSurface(
  WidgetTester tester,
  Finder content,
  ThemeData theme,
) async {
  expect(content, findsOneWidget);
  expect(
    find.ancestor(of: content, matching: find.byType(AppInfoCard)),
    findsOneWidget,
  );
  final card = find.ancestor(of: content, matching: find.byType(Card));
  expect(card, findsOneWidget);
  expect(
    find.ancestor(of: content, matching: find.byType(ListTile)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: card, matching: find.byIcon(Icons.info_outline)),
    findsOneWidget,
  );
  final materialFinder = _materialBehind(content);
  final material = tester.widget<Material>(materialFinder);
  expect(material.type, MaterialType.card);
  expect(material.color, theme.cardTheme.color);
  expect(material.shape, theme.cardTheme.shape);
  expect(material.elevation, theme.cardTheme.elevation);
  final background = theme.extension<ThemeVisuals>()!.hasBackground
      ? _backdrop
      : theme.colorScheme.surface;
  _expectColor(
    await _pixel(
      tester,
      tester.getRect(materialFinder).topCenter + const Offset(0, 3),
    ),
    Color.alphaBlend(theme.cardTheme.color!, background),
  );
}

void main() {
  for (final style in InterfaceStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$style $brightness standalone status keeps the wallpaper visible at every panel opacity',
        (tester) async {
          _viewport(tester);
          var actions = 0;
          for (final opacity in [0.4, 0.0, 1.0]) {
            final theme = _theme(
              style: style,
              brightness: brightness,
              opacity: opacity,
            );
            await tester.pumpWidget(
              _app(
                theme,
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsStatus(
                      title: 'Sync failed',
                      details: const ['Saved data remains available'],
                      isError: true,
                      action: TextButton(
                        onPressed: () => actions++,
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(Card), findsNothing);
            _expectUnbacked(tester, find.text('Sync failed'));
            final bounds = tester.getRect(find.byType(SettingsStatus));
            _expectColor(
              await _pixel(tester, bounds.topCenter + const Offset(0, 3)),
              _backdrop,
            );
            expect(
              tester.widget<Text>(find.text('Sync failed')).style!.color,
              theme.colorScheme.error,
            );
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.liveRegion == true,
              ),
              findsOneWidget,
            );
            await tester.tap(find.text('Retry'));
          }
          expect(actions, 3);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('$style without wallpaper retains the original flat notices', (
      tester,
    ) async {
      _viewport(tester);
      final theme = _theme(style: style, wallpaper: false, opacity: 0);
      await tester.pumpWidget(
        _app(theme, const SettingsStatus(title: 'Status')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);
      expect(tester.getTopLeft(find.text('Status')), const Offset(16, 16));
      _expectColor(
        await _pixel(tester, const Offset(250, 3)),
        theme.colorScheme.surface,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$style grouped status reuses its wallpaper surface', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(
        _app(
          _theme(style: style),
          const SettingsSection(
            title: 'Sync status',
            child: SettingsStatus(title: 'Up to date', details: ['Today']),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cards = style.isCard;
      expect(find.byType(Card), cards ? findsOneWidget : findsNothing);
      expect(
        find.ancestor(of: find.text('Up to date'), matching: find.byType(Card)),
        cards ? findsOneWidget : findsNothing,
      );
      expect(
        tester.widget<Material>(_materialBehind(find.text('Up to date'))).color,
        cards ? _surface.withValues(alpha: 0.4) : null,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('status in a native card keeps the card opacity', (tester) async {
    _viewport(tester);
    final theme = _theme();
    const status = SettingsStatus(title: 'Nested status');
    await tester.pumpWidget(
      _app(theme, Card(color: _surface.withValues(alpha: 0.4), child: status)),
    );
    await tester.pumpAndSettle();
    final ancestors = find.ancestor(
      of: find.text('Nested status'),
      matching: find.byType(Material),
    );
    expect(ancestors, findsNWidgets(2));
    final text = tester.getRect(find.text('Nested status'));
    _expectColor(
      await _pixel(tester, text.topLeft - const Offset(0, 8)),
      Color.alphaBlend(_surface.withValues(alpha: 0.4), _backdrop),
    );
  });

  testWidgets('ordinary cards and sliver panels keep their chosen opacity', (
    tester,
  ) async {
    _viewport(tester);
    for (final opacity in [0.0, 0.4, 1.0]) {
      for (final sliver in [false, true]) {
        await tester.pumpWidget(
          _app(
            _theme(style: InterfaceStyle.cards, opacity: opacity),
            sliver
                ? const AppCustomScrollView(
                    slivers: [
                      AppSliverSurface(
                        sliver: SliverToBoxAdapter(
                          child: SettingsStatus(title: 'Panel status'),
                        ),
                      ),
                    ],
                  )
                : const AppSurface(
                    child: SettingsStatus(title: 'Panel status'),
                  ),
          ),
        );
        await tester.pumpAndSettle();
        final text = tester.getRect(find.text('Panel status'));
        _expectColor(
          await _pixel(tester, text.topLeft - const Offset(0, 8)),
          Color.alphaBlend(_surface.withValues(alpha: opacity), _backdrop),
        );
      }
    }
  });

  testWidgets('tool pages without a timestamp keep the footer unpainted', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(
      _app(
        _theme(opacity: 0),
        ToolPageWrapper(
          onRefresh: () async {},
          loading: false,
          emptyText: 'No records',
          child: const SizedBox(height: 20),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _expectColor(await _pixel(tester, const Offset(250, 40)), _backdrop);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('$brightness shared headings keep layout without a backing', (
      tester,
    ) async {
      _viewport(tester);
      for (final mode in ['header', 'section', 'sliver']) {
        Rect? originalTitle;
        for (final wallpaper in [false, true, false]) {
          final theme = _theme(
            brightness: brightness,
            wallpaper: wallpaper,
            opacity: 0,
          );
          final Widget content = switch (mode) {
            'section' => const Section(
              title: 'Shared heading',
              child: SizedBox(height: 30),
            ),
            'sliver' => const AppCustomScrollView(
              slivers: [
                Section.sliver(
                  title: 'Shared heading',
                  child: SliverToBoxAdapter(child: SizedBox(height: 30)),
                ),
              ],
            ),
            _ => const SectionHeader(title: 'Shared heading'),
          };
          await tester.pumpWidget(
            _app(theme, SizedBox(width: double.infinity, child: content)),
          );
          await tester.pumpAndSettle();
          final title = find.text('Shared heading');
          final bounds = tester.getRect(title);
          originalTitle ??= bounds;
          expect(bounds, originalTitle);
          expect(bounds.topLeft, const Offset(16, 16));
          expect(
            tester.widget<Text>(title).style!.color,
            theme.colorScheme.primary,
          );
          _expectUnbacked(tester, title);
          _expectColor(
            await _pixel(tester, bounds.topCenter - const Offset(0, 8)),
            wallpaper ? _backdrop : theme.colorScheme.surface,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets(
      '$brightness tool page states and footer do not add text backings',
      (tester) async {
        _viewport(tester);
        for (final wallpaper in [true, false]) {
          for (final state in ['loading', 'error', 'empty', 'footer']) {
            final theme = _theme(
              brightness: brightness,
              wallpaper: wallpaper,
              opacity: 0,
            );
            await tester.pumpWidget(
              _app(
                theme,
                ToolPageWrapper(
                  onRefresh: () async {},
                  loading: state == 'loading',
                  hasData: state == 'footer',
                  error: state == 'error' ? 'Offline' : null,
                  emptyText: 'No records',
                  refreshTime: DateTime(2026, 11, 7, 10, 30),
                  child: const SizedBox(height: 20),
                ),
              ),
            );
            // An indeterminate progress indicator never settles.
            await tester.pump();
            final message = switch (state) {
              'loading' => find.byType(CircularProgressIndicator),
              'error' => find.textContaining('Offline'),
              'empty' => find.text('No records'),
              _ => find.textContaining('2026-11-07'),
            };
            expect(message, findsOneWidget);
            _expectUnbacked(tester, message);
            final bounds = tester.getRect(message);
            _expectColor(
              await _pixel(tester, bounds.topCenter - const Offset(0, 3)),
              wallpaper ? _backdrop : theme.colorScheme.surface,
            );
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  }

  testWidgets(
    'classic reminder advisory uses a themed info card while errors stay flat',
    (tester) async {
      _viewport(tester);
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        CourseReminderService.channel,
        (call) async => switch (call.method) {
          'deviceInfo' => {'manufacturer': 'Xiaomi', 'brand': 'Redmi'},
          'permissions' => {'notifications': true, 'exact': true},
          _ => null,
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          CourseReminderService.channel,
          null,
        ),
      );
      final settings = AppSettings();
      addTearDown(settings.dispose);
      CourseReminderService.instance.error.value = true;
      addTearDown(() => CourseReminderService.instance.error.value = false);
      for (final brightness in Brightness.values) {
        for (final wallpaper in [false, true, false]) {
          for (final opacity in [0.0, 0.4, 1.0]) {
            final theme = _theme(
              brightness: brightness,
              wallpaper: wallpaper,
              opacity: opacity,
            );
            await tester.pumpWidget(
              _app(
                theme,
                AppSettingsProvider(
                  settings: settings,
                  child: const CourseReminderSettingsPage(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final context = tester.element(
              find.byType(CourseReminderSettingsPage),
            );
            final l10n = AppLocalizations.of(context)!;
            expect(find.text(l10n.reminderXiaomiNotice), findsOneWidget);
            await _expectInfoCardSurface(
              tester,
              find.text(l10n.reminderXiaomiDescription),
              theme,
            );
            expect(find.byType(Card), findsOneWidget);
            final error = find.text(l10n.reminderFailed);
            expect(error, findsOneWidget);
            expect(
              find.ancestor(of: error, matching: find.byType(Card)),
              findsNothing,
            );
            final errorTile = find.ancestor(
              of: error,
              matching: find.byType(ListTile),
            );
            expect(errorTile, findsOneWidget);
            final retry = find.descendant(
              of: errorTile,
              matching: find.widgetWithText(TextButton, l10n.retry),
            );
            expect(retry, findsOneWidget);
            expect(tester.widget<TextButton>(retry).onPressed, isNotNull);
            if (wallpaper) {
              _expectUnbacked(tester, error);
            } else {
              expect(
                tester.widget<Material>(_materialBehind(error)).color,
                theme.colorScheme.surface,
              );
            }
            _expectColor(
              await _pixel(
                tester,
                tester.getRect(errorTile).topCenter + const Offset(0, 3),
              ),
              wallpaper ? _backdrop : theme.colorScheme.surface,
            );
            expect(
              find.ancestor(
                of: find.byType(SwitchListTile),
                matching: find.byType(Card),
              ),
              findsNothing,
            );
            final toggle = tester.widget<SwitchListTile>(
              find.byType(SwitchListTile),
            );
            expect(toggle.onChanged, isNotNull);
            expect(tester.takeException(), isNull);
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'third party introduction uses an info card with themed wallpaper opacity',
    (tester) async {
      _viewport(tester);
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      addTearDown(settings.dispose);
      for (final style in InterfaceStyle.values) {
        for (final brightness in Brightness.values) {
          for (final wallpaper in [true, false]) {
            for (final opacity in [0.0, 0.4, 1.0]) {
              final theme = _theme(
                style: style,
                brightness: brightness,
                wallpaper: wallpaper,
                opacity: opacity,
              );
              await tester.pumpWidget(
                _app(
                  theme,
                  AppSettingsProvider(
                    settings: settings,
                    child: const ThirdPartySettingsPage(),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final context = tester.element(
                find.byType(ThirdPartySettingsPage),
              );
              final message = find.text(
                AppLocalizations.of(context)!.thirdPartyDescription,
              );
              expect(find.byType(AppInfoCard), findsOneWidget);
              await _expectInfoCardSurface(tester, message, theme);
              expect(tester.takeException(), isNull);
            }
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
