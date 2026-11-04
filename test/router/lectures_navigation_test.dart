import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/academic/academic_shortcuts_page.dart';

void main() {
  for (final locale in ['zh', 'en']) {
    testWidgets('Jiaxi shortcut opens the native route ($locale)', (
      tester,
    ) async {
      RouteSettings? opened;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AcademicShortcutsPage(),
          onGenerateRoute: (settings) {
            opened = settings;
            return MaterialPageRoute<void>(
              builder: (_) =>
                  const Scaffold(body: Text('native-lectures-fixture')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AcademicShortcutsPage)),
      )!;
      await tester.scrollUntilVisible(find.text(l10n.jiaxiLectures), 250);
      await tester.tap(find.text(l10n.jiaxiLectures));
      await tester.pumpAndSettle();
      expect(opened!.name, AppRoutes.lectures);
      expect(opened!.arguments, isNull);
      expect(find.text('native-lectures-fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
