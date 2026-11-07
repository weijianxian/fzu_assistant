import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/screen/settings/third_party_settings_page.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final language in ['zh', 'en']) {
    testWidgets(
      'three choices stay ordered, independent and persistent on a narrow $language screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final settings = AppSettings();
        await settings.load();
        await tester.pumpWidget(
          AppSettingsProvider(
            settings: settings,
            child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const ThirdPartySettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final page = find.byType(ThirdPartySettingsPage);
        final l10n = AppLocalizations.of(tester.element(page))!;
        final choices = find.byType(SegmentedButton<FeatureAccess>);
        expect(choices, findsAtLeastNWidgets(1));
        final first = choices.first;
        final firstWidget = tester.widget<SegmentedButton<FeatureAccess>>(
          first,
        );
        expect(firstWidget.segments.map((segment) => segment.value), [
          FeatureAccess.hide,
          FeatureAccess.tip,
          FeatureAccess.allow,
        ]);
        expect(firstWidget.selected, {FeatureAccess.tip});
        await tester.ensureVisible(first);
        await tester.pumpAndSettle();
        Finder choice(Finder group, String label) =>
            find.descendant(of: group, matching: find.text(label));
        final hidden = choice(first, l10n.accessHide);
        final asked = choice(first, l10n.accessTip);
        final allowed = choice(first, l10n.accessAllow);
        expect(
          tester.getCenter(hidden).dx,
          lessThan(tester.getCenter(asked).dx),
        );
        expect(
          tester.getCenter(asked).dx,
          lessThan(tester.getCenter(allowed).dx),
        );
        expect(tester.takeException(), isNull);

        await tester.tap(allowed);
        await tester.pumpAndSettle();
        expect(settings.west2AdjustmentsAccess.value, FeatureAccess.allow);
        expect(settings.papersAccess.value, FeatureAccess.tip);
        await tester.scrollUntilVisible(
          find.text(l10n.pastPapers),
          250,
          scrollable: find.byType(Scrollable).first,
          continuous: true,
        );
        final second = find.descendant(
          of: find.byType(FeatureAccessTile).last,
          matching: choices,
        );
        expect(tester.widget<SegmentedButton<FeatureAccess>>(second).selected, {
          FeatureAccess.tip,
        });
        await tester.ensureVisible(second);
        await tester.tap(choice(second, l10n.accessHide));
        await tester.pumpAndSettle();
        expect(settings.papersAccess.value, FeatureAccess.hide);
        expect(tester.widget<SegmentedButton<FeatureAccess>>(second).selected, {
          FeatureAccess.hide,
        });
        await tester.runAsync(() async {
          final restored = AppSettings();
          await restored.load();
          expect(restored.west2AdjustmentsAccess.value, FeatureAccess.allow);
          expect(restored.papersAccess.value, FeatureAccess.hide);
          restored.dispose();
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        settings.dispose();
      },
    );
  }
}
