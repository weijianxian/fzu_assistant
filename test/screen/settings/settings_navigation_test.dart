import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/settings/home_settings_page.dart';
import 'package:fzu_assistant/screen/settings/settings_page.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/reminder_channel.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockReminderChannel();
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final style in InterfaceStyle.values) {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
    ]) {
      testWidgets(
        '$platform $style exposes calendar sync only in the platform group',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(400, 800);
          addTearDown(tester.view.reset);
          final settings = AppSettings()
            ..interfaceStyle.value = style
            ..termsKey.value = ['202601'];
          addTearDown(settings.dispose);
          String? navigated;
          Widget app(Widget page) => AppSettingsProvider(
            settings: settings,
            child: MaterialApp(
              theme: settings.lightTheme,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              onGenerateRoute: (route) {
                navigated = route.name;
                return MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(),
                );
              },
              home: page,
            ),
          );
          await tester.pumpWidget(app(const SettingsPage()));
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(SettingsPage)),
          )!;
          if (platform == TargetPlatform.android) {
            final platformSection = find.byWidgetPredicate(
              (widget) =>
                  widget is SettingsSection &&
                  widget.title == l10n.settingsPlatformSection,
            );
            final calendar = find.descendant(
              of: platformSection,
              matching: find.text(l10n.calendarSync),
            );
            await tester.scrollUntilVisible(calendar, 200);
            await tester.pumpAndSettle();
            await tester.tap(calendar);
            await tester.pumpAndSettle();
            expect(navigated, AppRoutes.calendarExport);
            Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
            await tester.pumpAndSettle();
            final sync = find.descendant(
              of: platformSection,
              matching: find.text(l10n.scheduleSync),
            );
            await tester.ensureVisible(sync);
            await tester.tap(sync);
            await tester.pumpAndSettle();
            expect(navigated, AppRoutes.scheduleSyncSettings);
          } else {
            expect(find.text(l10n.settingsPlatformSection), findsNothing);
            expect(find.text(l10n.calendarSync), findsNothing);
            expect(find.text(l10n.scheduleSync), findsNothing);
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(app(const HomeSettingsPage()));
          await tester.pumpAndSettle();
          expect(find.text(l10n.calendarSync), findsNothing);
          if (platform == TargetPlatform.android) {
            expect(find.text(l10n.calendarExport), findsNothing);
          } else {
            await tester.tap(find.text(l10n.calendarExport));
            await tester.pumpAndSettle();
            expect(navigated, AppRoutes.calendarExport);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
}
