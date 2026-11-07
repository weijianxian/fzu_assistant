import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/common/utils/semester_utils.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/home_settings_page.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/reveal_widget.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final style in InterfaceStyle.values) {
    for (final language in ['zh', 'en']) {
      testWidgets(
        '$language $style preserves a restored term, cancels and selects auto',
        (tester) async {
          tester.view.physicalSize = const Size(360, 720);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
          addTearDown(tester.view.reset);
          final settings = AppSettings();
          await settings.load();
          addTearDown(settings.dispose);
          settings.interfaceStyle.value = style;
          settings.termsKey.value = ['202601'];
          settings.selectedSemesterKey.value = '202401';
          await tester.pumpWidget(
            AppSettingsProvider(
              settings: settings,
              child: MaterialApp(
                theme: settings.lightTheme,
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: const HomeSettingsPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(HomeSettingsPage)),
          )!;
          final selector = find.byType(SettingsChoiceTile<String>);
          await revealWidget(tester, selector);
          expect(
            tester.widget<SettingsChoiceTile<String>>(selector).value,
            '202401',
          );
          await tester.ensureVisible(selector);
          await tester.pumpAndSettle();
          await tester.tap(selector);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
                .groupValue,
            '202401',
          );
          expect(
            find.descendant(
              of: find.byType(RadioGroup<String>),
              matching: find.byType(Card),
            ),
            style == InterfaceStyle.cards ? findsNWidgets(3) : findsNothing,
          );
          expect(
            find.descendant(
              of: find.byType(RadioGroup<String>),
              matching: find.byType(Divider),
            ),
            findsNothing,
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(settings.selectedSemesterKey.value, '202401');
          await tester.tap(selector);
          await tester.pumpAndSettle();
          await tester.tap(find.text(SemesterUtils.formatSemester('202601')));
          await tester.pumpAndSettle();
          expect(settings.selectedSemesterKey.value, '202601');
          expect(find.byType(RadioGroup<String>), findsNothing);
          await tester.tap(selector);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(RadioGroup<String>),
              matching: find.text(l10n.autoSemester),
            ),
          );
          await tester.pumpAndSettle();
          expect(settings.selectedSemesterKey.value, '');
          await tester.runAsync(() async {
            final restored = AppSettings();
            await restored.load();
            expect(restored.selectedSemesterKey.value, '');
            expect(restored.interfaceStyle.value, style);
            restored.dispose();
          });
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      '$style toolbar semester sheet scrolls, preserves restored terms and opens once',
      (tester) async {
        tester.view.physicalSize = const Size(800, 360);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(left: 48, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(left: 48, bottom: 24);
        addTearDown(tester.view.reset);
        String? changed;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(Colors.deepPurple, interfaceStyle: style),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppScaffold(
              appBar: AppBar(
                actions: [
                  TermSelectorButton(
                    terms: [
                      for (var year = 2026; year > 2010; year--) '${year}01',
                    ],
                    selected: '200901',
                    onSelected: (value) => changed = value,
                  ),
                ],
              ),
              body: const SizedBox(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final open = tester
            .widget<IconButton>(find.byType(IconButton))
            .onPressed!;
        open();
        open();
        await tester.pumpAndSettle();
        expect(find.byType(RadioGroup<String>), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        final surface = find
            .ancestor(
              of: find.byType(RadioGroup<String>),
              matching: find.byType(Material),
            )
            .first;
        expect(tester.getRect(surface).width, closeTo(800 * 2 / 3, .001));
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          '200901',
        );
        final restoredTerm = find.text(SemesterUtils.formatSemester('200901'));
        await revealWidget(tester, restoredTerm);
        expect(restoredTerm.hitTestable(), findsOneWidget);
        expect(tester.getRect(restoredTerm).left, greaterThanOrEqualTo(48));
        expect(tester.getRect(restoredTerm).bottom, lessThanOrEqualTo(336));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(changed, isNull);
        expect(find.byType(RadioGroup<String>), findsNothing);
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('自动（当前学期）'));
        await tester.pumpAndSettle();
        expect(changed, '');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '$style restored semester can return to auto without a cached term list',
      (tester) async {
        String? changed;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(Colors.blue, interfaceStyle: style),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppScaffold(
              appBar: AppBar(
                actions: [
                  TermSelectorButton(
                    terms: const [],
                    selected: '202401',
                    onSelected: (value) => changed = value,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          '202401',
        );
        await tester.tap(find.text('自动（当前学期）'));
        await tester.pumpAndSettle();
        expect(changed, '');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
