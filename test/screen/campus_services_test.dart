import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/guest/webview_page.dart';
import 'package:fzu_assistant/screen/toolbox/campus_services/campus_services_page.dart';

void main() {
  for (final locale in ['zh', 'en']) {
    for (final size in [const Size(400, 800), const Size(1200, 800)]) {
      testWidgets(
        'official campus links use SSO instead of academic cookies ($locale, $size)',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          WebViewArgs? args;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CampusServicesPage(),
              onGenerateRoute: (route) {
                expect(route.name, AppRoutes.webview);
                args = route.arguments as WebViewArgs;
                return MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('browser')),
                );
              },
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CampusServicesPage)),
          )!;
          for (final entry in [
            (l10n.campusDormRepair, 'ehall.fzu.edu.cn'),
            (l10n.campusLibraryReservation, 'kjgl.fzu.edu.cn'),
            (l10n.campusAttendance, 'yzsxg.fzu.edu.cn'),
          ]) {
            await tester.scrollUntilVisible(find.text(entry.$1), 200);
            await tester.tap(find.text(entry.$1));
            await tester.pumpAndSettle();
            expect(Uri.parse(args!.url).host, entry.$2);
            expect(args!.injectSsoCookies, isTrue);
            expect(args!.injectCookies, isFalse);
            tester.state<NavigatorState>(find.byType(Navigator).first).pop();
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'missing SSO ticket shows app login without creating a native WebView',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'fzu_username': 'student',
        'fzu_password': 'password',
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WebViewPage(
            url: 'https://kjgl.fzu.edu.cn/libseat',
            injectCookies: false,
            injectSsoCookies: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '统一身份认证登录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
