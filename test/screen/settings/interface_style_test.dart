import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/screen/settings/settings_page.dart';
import 'package:fzu_assistant/screen/settings/theme/theme_section.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/theme_customization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/reminder_channel.dart';
import '../../fixtures/reveal_widget.dart';

class _EmptyThemeStore extends ThemeCustomizationService {
  @override
  Future<List<ThemeProfile>> loadAll() async => const [];
}

AppSettings _settings() => AppSettings(themeStore: _EmptyThemeStore());

Widget app(
  AppSettings settings,
  String language, {
  Widget? home,
  double textScale = 1.3,
}) => AnimatedBuilder(
  animation: Listenable.merge([
    settings.interfaceStyle,
    settings.themeModeKey,
    settings.themeKey,
  ]),
  builder: (_, _) => AppSettingsProvider(
    settings: settings,
    child: MaterialApp(
      theme: settings.lightTheme,
      darkTheme: settings.darkTheme,
      themeMode: settings.currentThemeMode,
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home ?? const SettingsPage(),
    ),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockReminderChannel();
  });

  for (final language in ['zh', 'en']) {
    testWidgets(
      '$language switches style immediately and persists across routes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = _settings();
        await settings.load();
        addTearDown(settings.dispose);
        await tester.pumpWidget(app(settings, language));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SettingsPage)),
        )!;
        expect(settings.interfaceStyle.value, InterfaceStyle.cards);
        expect(find.byType(Card), findsWidgets);
        await revealWidget(tester, find.text(l10n.themeSettings));
        await tester.tap(find.text(l10n.themeSettings));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.interfaceStyle));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.interfaceStyleClassic));
        await tester.pumpAndSettle();
        expect(settings.interfaceStyle.value, InterfaceStyle.classic);
        expect(find.byType(Card), findsNothing);
        expect(settings.themeKey.value, 'deep_purple');
        expect(settings.themeModeKey.value, 'system');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(Card), findsNothing);
        expect(find.text(l10n.homeSettings), findsOneWidget);
        await tester.runAsync(() async {
          final reloaded = _settings();
          await reloaded.load();
          expect(reloaded.interfaceStyle.value, InterfaceStyle.classic);
          reloaded.dispose();
        });
        await revealWidget(tester, find.text(l10n.themeSettings));
        await tester.tap(find.text(l10n.themeSettings));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.interfaceStyle));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.interfaceStyleCards));
        await tester.pumpAndSettle();
        expect(settings.interfaceStyle.value, InterfaceStyle.cards);
        expect(find.byType(Card), findsWidgets);
        await tester.runAsync(() async {
          final reloaded = _settings();
          await reloaded.load();
          expect(reloaded.interfaceStyle.value, InterfaceStyle.cards);
          reloaded.dispose();
        });
        await tester.tap(find.text(l10n.interfaceStyle));
        await tester.pumpAndSettle();
        final continuousChoice = find.widgetWithText(
          RadioListTile<InterfaceStyle>,
          l10n.interfaceStyleContinuousCards,
        );
        expect(
          tester.getTopLeft(continuousChoice).dy,
          greaterThan(
            tester
                .getTopLeft(
                  find.widgetWithText(
                    RadioListTile<InterfaceStyle>,
                    l10n.interfaceStyleCards,
                  ),
                )
                .dy,
          ),
        );
        await tester.ensureVisible(continuousChoice);
        await tester.pumpAndSettle();
        expect(continuousChoice.hitTestable(), findsOneWidget);
        await tester.tap(continuousChoice);
        await tester.pumpAndSettle();
        expect(settings.interfaceStyle.value, InterfaceStyle.continuousCards);
        expect(find.byType(Card), findsWidgets);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(Card), findsWidgets);
        await tester.runAsync(() async {
          final reloaded = _settings();
          await reloaded.load();
          expect(reloaded.interfaceStyle.value, InterfaceStyle.continuousCards);
          reloaded.dispose();
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    for (final style in InterfaceStyle.values) {
      testWidgets(
        '$language $style scrolls vertical color previews and saves the selection',
        (tester) async {
          tester.view.physicalSize = const Size(320, 920);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final settings = _settings();
          await settings.load();
          settings.interfaceStyle.value = style;
          settings.themeModeKey.value = 'dark';
          addTearDown(settings.dispose);
          await tester.pumpWidget(app(settings, language, textScale: 2));
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(SettingsPage)),
          )!;
          await tester.ensureVisible(find.text(l10n.themeSettings));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.themeSettings));
          await tester.pumpAndSettle();
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
            ),
            findsNothing,
          );
          final vertical = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          expect(find.text(l10n.themeBrown).hitTestable(), findsNothing);
          await revealWidget(tester, find.text(l10n.themeBrown));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.themeBrown));
          await tester.pumpAndSettle();
          expect(settings.themeKey.value, 'brown');
          expect(settings.interfaceStyle.value, style);
          expect(settings.themeModeKey.value, 'dark');
          expect(vertical.position.pixels, greaterThan(0));
          expect(find.byType(DraggableScrollableSheet), findsNothing);
          expect(
            Theme.of(tester.element(find.byType(ThemeSection))).colorScheme,
            ColorScheme.fromSeed(
              seedColor: appThemes.last.color,
              brightness: Brightness.dark,
            ),
          );
          await tester.runAsync(() async {
            final reloaded = _settings();
            await reloaded.load();
            expect(reloaded.themeKey.value, 'brown');
            expect(reloaded.interfaceStyle.value, style);
            expect(reloaded.themeModeKey.value, 'dark');
            reloaded.dispose();
          });
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(l10n.themeSettings));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.themeSettings));
          await tester.pumpAndSettle();
          await revealWidget(tester, find.text(l10n.themeBrown));
          await tester.pumpAndSettle();
          expect(find.text(l10n.themeBrown).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets(
        '$language $style supports dark mode, large text and system insets',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final settings = _settings()
            ..interfaceStyle.value = style
            ..themeModeKey.value = 'dark';
          addTearDown(settings.dispose);
          for (final (size, insets) in [
            (const Size(320, 920), const FakeViewPadding(top: 24, bottom: 34)),
            (
              const Size(920, 400),
              const FakeViewPadding(left: 48, top: 24, bottom: 34),
            ),
            (
              const Size(920, 400),
              const FakeViewPadding(right: 48, top: 24, bottom: 34),
            ),
          ]) {
            tester.view.physicalSize = size;
            tester.view.padding = insets;
            tester.view.viewPadding = insets;
            await tester.pumpWidget(
              app(settings, language, home: const ThemeSection()),
            );
            await tester.pumpAndSettle();
            final scroll = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );
            for (
              double offset = 0;
              offset < scroll.position.maxScrollExtent;
              offset += 200
            ) {
              scroll.position.jumpTo(offset);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            scroll.position.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(tester.getRect(find.byType(ListView)).bottom, size.height);
            final paletteRect = tester.getRect(
              find.byKey(const ValueKey('theme-color-brown')),
            );
            expect(
              paletteRect.bottom,
              lessThanOrEqualTo(size.height - insets.bottom),
            );
            expect(paletteRect.left, greaterThanOrEqualTo(insets.left));
            expect(
              paletteRect.right,
              lessThanOrEqualTo(size.width - insets.right),
            );
            final theme = Theme.of(tester.element(find.byType(ThemeSection)));
            expect(theme.brightness, Brightness.dark);
            expect(theme.extension<InterfaceTheme>()!.style, style);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('restored dynamic color handles unavailable system colors', (
    tester,
  ) async {
    final dynamicSupported = AppSettings.dynamicColorSupported;
    AppSettings.dynamicColorSupported = false;
    addTearDown(() => AppSettings.dynamicColorSupported = dynamicSupported);
    final settings = _settings()..themeKey.value = 'dynamic';
    addTearDown(settings.dispose);
    await tester.pumpWidget(app(settings, 'zh', home: const ThemeSection()));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThemeSection)),
    )!;
    await revealWidget(tester, find.text(l10n.themeDynamic));
    expect(find.text(l10n.themeDynamic).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text(l10n.themeBlue));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.themeBlue));
    await tester.pumpAndSettle();
    expect(settings.themeKey.value, 'blue');
    expect(find.text(l10n.themeDynamic), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
