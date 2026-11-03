import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/home_settings_page.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

void main() {
  testWidgets(
    'a restored or custom term remains selectable outside cached terms',
    (tester) async {
      final settings = AppSettings();
      settings.termsKey.value = ['202601'];
      settings.selectedSemesterKey.value = '202401';
      await tester.pumpWidget(
        AppSettingsProvider(
          settings: settings,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        '202401',
      );
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
    },
  );
}
