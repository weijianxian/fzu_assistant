import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/academic/academic_shortcuts_page.dart';

void main() {
  for (final locale in ['zh', 'en']) {
    testWidgets(
      'academic links preserve login injection and page title ($locale)',
      (tester) async {
        WebViewArgs? args;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AcademicShortcutsPage(),
            onGenerateRoute: (settings) {
              expect(settings.name, AppRoutes.webview);
              args = settings.arguments as WebViewArgs;
              return MaterialPageRoute<void>(
                builder: (_) =>
                    const Scaffold(body: Text('webview-placeholder')),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(AcademicShortcutsPage));
        final l10n = AppLocalizations.of(context)!;
        await tester.tap(find.text(l10n.evalTabXqxk));
        await tester.pumpAndSettle();
        expect(
          args!.url,
          'https://jwcjwxt2.fzu.edu.cn:81/student/glxk/xqxk/xqxk_cszt.aspx',
        );
        expect(args!.title, l10n.evalTabXqxk);
        expect(args!.injectCookies, isTrue);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(l10n.jiaxiLectures), 250);
        await tester.tap(find.text(l10n.jiaxiLectures));
        await tester.pumpAndSettle();
        expect(
          args!.url,
          'https://jwcjwxt2.fzu.edu.cn:81/student/glbm/lecture/jxjt_cszt.aspx',
        );
        expect(args!.title, l10n.jiaxiLectures);
        expect(args!.injectCookies, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
