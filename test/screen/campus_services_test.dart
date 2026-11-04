import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/campus_service.dart';
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
            (
              CampusService.dormRepair,
              l10n.campusDormRepair,
              'ehall.fzu.edu.cn',
            ),
            (
              CampusService.libraryReservation,
              l10n.campusLibraryReservation,
              'kjgl.fzu.edu.cn',
            ),
            (
              CampusService.attendance,
              l10n.campusAttendance,
              'yzsxg.fzu.edu.cn',
            ),
          ]) {
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pumpAndSettle();
            final tile = await _visibleCampusTile(tester, entry.$1);
            expect(
              find.descendant(of: tile, matching: find.text(entry.$2)),
              findsOneWidget,
            );
            args = null;
            await tester.tap(tile);
            await tester.pumpAndSettle();
            expect(args, isNotNull);
            expect(Uri.parse(args!.url).host, entry.$3);
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

  test(
    'the official directory keeps the original services and distinct links',
    () {
      const originalLinks = {
        CampusService.dormRepair:
            'http://ehall.fzu.edu.cn/ssfw/sys/swmssbxapp/*default/index.do',
        CampusService.reservations: 'https://aiot.fzu.edu.cn/ibs/#/',
        CampusService.libraryReservation: 'https://kjgl.fzu.edu.cn/libseat',
        CampusService.lostAndFound: 'https://app.fzu.edu.cn/appEntry/app/index?redirectUrl=https://app.fzu.edu.cn/appService/lostAndFound/app',
        CampusService.attendance: 'https://yzsxg.fzu.edu.cn/livecloud/project/fzu/attn/oauth2/authorize.action',
        CampusService.electricBike: 'http://doorwxoa.fzu.edu.cn/appCas/index',
        CampusService.yiban: 'https://api.uyiban.com/base/c/rgsid/login',
      };
      for (final entry in originalLinks.entries) {
        expect(entry.key.url, entry.value);
      }
      expect(
        CampusService.values.map((service) => service.url).toSet(),
        hasLength(CampusService.values.length),
        reason:
            'Campus and alumni activities must not duplicate a destination.',
      );
      for (final service in CampusService.values) {
        final uri = Uri.parse(service.url);
        expect(uri.scheme, isIn(['http', 'https']));
        expect(uri.userInfo, isEmpty);
        expect(uri.host, isNotEmpty);
      }
    },
  );

  test('public information pages do not require an SSO session', () {
    expect(
      CampusService.values.where((service) => !service.requiresSso),
      unorderedEquals([
        CampusService.map,
        CampusService.officialNotices,
        CampusService.networkGuide,
        CampusService.lectureReports,
      ]),
    );
    expect(CampusService.map.url, 'https://map.fzu.edu.cn');
    expect(CampusService.officialNotices.url, 'https://info.fzu.edu.cn/');
    expect(
      CampusService.networkGuide.url,
      'https://app.fzu.edu.cn/appService/guidance/app/articleCollapse',
    );
  });

  for (final locale in ['zh', 'en']) {
    for (final size in [const Size(400, 800), const Size(1200, 800)]) {
      testWidgets(
        'every grouped campus service opens the intended web route ($locale, $size)',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final opened = <WebViewArgs>[];
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CampusServicesPage(),
              onGenerateRoute: (route) {
                expect(route.name, AppRoutes.webview);
                opened.add(route.arguments as WebViewArgs);
                return MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(),
                );
              },
            ),
          );
          await tester.pumpAndSettle();
          expect(opened, isEmpty);
          const publicServices = {
            CampusService.map,
            CampusService.officialNotices,
            CampusService.networkGuide,
            CampusService.lectureReports,
          };
          for (final service in CampusService.values) {
            final tileFinder = await _visibleCampusTile(tester, service);
            final tile = tester.widget<ListTile>(tileFinder);
            final title = (tile.title! as Text).data!;
            expect(title, isNotEmpty);
            expect((tile.subtitle! as Text).data, isNotEmpty);
            final previousRouteCount = opened.length;
            await tester.tap(tileFinder);
            await tester.pumpAndSettle();
            expect(
              opened,
              hasLength(previousRouteCount + 1),
              reason: 'Tapping ${service.name} must open a new browser route.',
            );
            final args = opened.last;
            expect(args.url, service.url);
            expect(args.title, title);
            expect(args.injectCookies, isFalse);
            expect(args.injectSsoCookies, !publicServices.contains(service));
            tester.state<NavigatorState>(find.byType(Navigator).first).pop();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(opened, hasLength(CampusService.values.length));
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CampusServicesPage)),
          )!;
          final expectedHeadings = [
            l10n.campusServicesLife,
            l10n.campusServicesBookings,
            l10n.campusServicesGrowth,
            l10n.campusServicesOffice,
            l10n.campusServicesNetwork,
          ];
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          for (final heading in expectedHeadings) {
            await _scrollToHitTestable(tester, find.text(heading));
          }
        },
      );
    }
  }

  testWidgets(
    'listing, scrolling and refreshing never prepare a remote service',
    (tester) async {
      final previousOverrides = HttpOverrides.current;
      final blockedNetwork = _BlockedNetwork();
      HttpOverrides.global = blockedNetwork;
      addTearDown(() => HttpOverrides.global = previousOverrides);
      var routesOpened = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CampusServicesPage(),
          onGenerateRoute: (route) {
            routesOpened++;
            return MaterialPageRoute<void>(builder: (_) => const Scaffold());
          },
        ),
      );
      await tester.pumpAndSettle();
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;
      await _visibleCampusTile(tester, CampusService.networkGuide);
      expect(blockedNetwork.attempts, 0);
      expect(routesOpened, 0);
      expect(find.byType(InAppWebView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing SSO ticket shows app login without creating a native WebView',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'fzu_username': 'student',
        'fzu_password': 'password',
      });
      var loginOpened = false;
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
          onGenerateRoute: (route) {
            expect(route.name, AppRoutes.campusServicesLogin);
            loginOpened = true;
            return MaterialPageRoute<void>(builder: (_) => const Scaffold());
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '统一身份认证登录'), findsOneWidget);
      expect(find.byType(InAppWebView), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, '统一身份认证登录'));
      await tester.pumpAndSettle();
      expect(loginOpened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<Finder> _visibleCampusTile(WidgetTester tester, CampusService service) =>
    _scrollToHitTestable(tester, find.byKey(ValueKey(service)));

Future<Finder> _scrollToHitTestable(WidgetTester tester, Finder target) async {
  final visibleTarget = target.hitTestable();
  final scrollable = find.byType(Scrollable).first;
  final position = tester.state<ScrollableState>(scrollable).position;
  // Scan from the top: cached children of a future sliver do not yet have
  // meaningful screen coordinates for choosing a scroll direction.
  position.jumpTo(0);
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pumpAndSettle();
    if (visibleTarget.evaluate().isNotEmpty) return visibleTarget;
    position.jumpTo(
      (position.pixels + 160)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
    );
  }
  expect(
    visibleTarget,
    findsOneWidget,
    reason:
        '$target must be inside the tappable viewport after scrolling '
        '(${position.pixels}/${position.maxScrollExtent}).',
  );
  return visibleTarget;
}

class _BlockedNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('The campus service directory must not create a client.');
  }
}
