import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/campus_service.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/guest/webview_page.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';

void main() {
  final platform = _BrowserPlatform();
  final previousGeolocator = GeolocatorPlatform.instance;
  final locations = _Locations();
  setUpAll(() {
    InAppWebViewPlatform.instance = platform;
    GeolocatorPlatform.instance = locations;
  });
  tearDownAll(() => GeolocatorPlatform.instance = previousGeolocator);
  setUp(() {
    platform.cookies
      ..saved = null
      ..acceptCookie = true
      ..retainCookie = true;
    platform.views.clear();
    FlutterSecureStorage.setMockInitialValues({
      'fzu_username': 'student',
      'fzu_password': 'unused',
      'fzu_sso_student_cookie': 'shared-sso-ticket',
    });
  });

  Widget app(CampusService service, {RouteFactory? onGenerateRoute}) =>
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: onGenerateRoute,
        home: WebViewPage(
          url: service.url,
          injectCookies: false,
          injectSsoCookies: service.requiresSso,
        ),
      );

  final loginPrompt = find.widgetWithText(FilledButton, '统一身份认证登录');
  // The production cookie queue is shared across browser instances. Keep the
  // complete browser lifecycle in one fake-async zone, including logout.
  testWidgets(
    'campus SSO reuse, redirects, re-login, native failures and logout',
    (tester) async {
      for (final service in [
        CampusService.attendance,
        CampusService.dormRepair,
        CampusService.mailbox,
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        platform.views.clear();
        await tester.pumpWidget(app(service));
        await tester.pumpAndSettle();
        expect(find.byType(InAppWebView), findsOneWidget);
        expect(loginPrompt, findsNothing);
        expect(platform.cookies.saved, (
          url: SsoService.loginUrl,
          name: 'SOURCEID_TGC',
          value: 'shared-sso-ticket',
          domain: null,
          secure: true,
          httpOnly: true,
          sameSite: HTTPCookieSameSitePolicy.NONE,
        ));
        expect(await SsoService.instance.loadStudyToken(), isNull);
        expect(await SsoService.instance.loadCampusToken(), isNull);

        final view =
            tester.widget<InAppWebView>(find.byType(InAppWebView)).platform
                as _BrowserView;
        expect(view.params.initialSettings?.thirdPartyCookiesEnabled, isTrue);
        // Native WebViews may report the completion of an intermediate login
        // redirect after the document has advanced to the service callback.
        view.controller.loginForm = false;
        view.finish(SsoService.loginUrl);
        await tester.pumpAndSettle();
        expect(find.byType(InAppWebView), findsOneWidget);
        expect(loginPrompt, findsNothing);
        expect(view.controller.scripts.single, contains('location.origin'));
        expect(view.controller.scripts.single, contains('login-page-flowkey'));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        app(
          CampusService.attendance,
          onGenerateRoute: (route) {
            expect(route.name, AppRoutes.campusServicesLogin);
            return MaterialPageRoute<bool>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('complete-login'),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final view =
          tester.widget<InAppWebView>(find.byType(InAppWebView)).platform
              as _BrowserView;
      final nativeController = view
          .controllerFromPlatform<InAppWebViewController>(view.controller);
      final protocol = NavigationAction(
        request: URLRequest(
          url: WebUri(
            'kysk-fdxy-app://native?type=permission&biz=location'
            '&action=0&function=nativePermissionFunKysk',
          ),
        ),
        isForMainFrame: true,
      );
      view.controller.url = WebUri('https://example.com/');
      expect(
        await view.params.shouldOverrideUrlLoading!(nativeController, protocol),
        NavigationActionPolicy.CANCEL,
      );
      expect(locations.checks, 0);
      expect(view.controller.scripts, isEmpty);
      view.controller.url = WebUri(
        'https://yzsxg.fzu.edu.cn/plug-in/livecloud/project/fzu/attn/index.action',
      );
      expect(
        await view.params.shouldOverrideUrlLoading!(nativeController, protocol),
        NavigationActionPolicy.CANCEL,
      );
      expect(locations.checks, 1);
      expect(locations.requests, 0);
      expect(
        view.controller.scripts.single,
        contains('nativePermissionFunKysk'),
      );
      for (final origin in ['https://example.com', 'null']) {
        final permission = await view
            .params
            .onGeolocationPermissionsShowPrompt!(nativeController, origin);
        expect(permission?.allow, isFalse);
      }
      final permission = await view.params.onGeolocationPermissionsShowPrompt!(
        nativeController,
        'https://yzsxg.fzu.edu.cn',
      );
      expect(permission?.allow, isTrue);
      expect(permission?.retain, isFalse);
      expect(locations.requests, 0);
      view.controller.scripts.clear();
      view.controller.loginForm = true;
      view.finish(SsoService.loginUrl);
      await tester.pumpAndSettle();
      expect(loginPrompt, findsOneWidget);
      expect(find.byType(InAppWebView), findsNothing);
      await tester.tap(loginPrompt);
      await tester.pumpAndSettle();
      await tester.tap(find.text('complete-login'));
      await tester.pumpAndSettle();
      expect(loginPrompt, findsNothing);
      expect(find.byType(InAppWebView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      platform.cookies.acceptCookie = false;
      await tester.pumpWidget(app(CampusService.attendance));
      await tester.pumpAndSettle();
      expect(find.textContaining('无法设置统一认证登录状态'), findsOneWidget);
      expect(loginPrompt, findsNothing);
      expect(find.byType(InAppWebView), findsNothing);
      platform.cookies.acceptCookie = true;
      await tester.tap(find.widgetWithText(FilledButton, '重试'));
      await tester.pumpAndSettle();
      expect(find.byType(InAppWebView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      platform.cookies.retainCookie = false;
      await tester.pumpWidget(app(CampusService.attendance));
      await tester.pumpAndSettle();
      expect(find.textContaining('无法设置统一认证登录状态'), findsOneWidget);
      expect(loginPrompt, findsNothing);
      expect(find.byType(InAppWebView), findsNothing);
      platform.cookies.retainCookie = true;
      await tester.tap(find.widgetWithText(FilledButton, '重试'));
      await tester.pumpAndSettle();
      expect(find.byType(InAppWebView), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(CampusService.attendance));
      await tester.pumpAndSettle();
      final logoutView =
          tester.widget<InAppWebView>(find.byType(InAppWebView)).platform
              as _BrowserView;
      final document = Completer<Object?>();
      logoutView.controller.document = document;
      logoutView.finish(SsoService.loginUrl);
      await tester.pump();
      await SsoService.instance.logout();
      document.complete(true);
      await tester.pumpAndSettle();
      expect(loginPrompt, findsOneWidget);
      expect(find.byType(InAppWebView), findsNothing);
      expect(await SsoService.instance.hasSession(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

class _BrowserPlatform extends InAppWebViewPlatform {
  final cookies = _Cookies();
  final views = <_BrowserView>[];

  @override
  PlatformCookieManager createPlatformCookieManager(
    PlatformCookieManagerCreationParams params,
  ) => cookies;

  @override
  PlatformCookieManager createPlatformCookieManagerStatic() => cookies;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    final view = _BrowserView(params);
    views.add(view);
    return view;
  }
}

class _Cookies extends PlatformCookieManager {
  _Cookies()
    : super.implementation(const PlatformCookieManagerCreationParams());
  bool acceptCookie = true;
  bool retainCookie = true;
  Object? saved;
  Cookie? cookie;

  @override
  Future<bool> deleteAllCookies() async {
    saved = null;
    cookie = null;
    return true;
  }

  @override
  Future<List<Cookie>> getCookies({
    required WebUri url,
    PlatformInAppWebViewController? iosBelow11WebViewController,
    PlatformInAppWebViewController? webViewController,
  }) async => [if (retainCookie && cookie != null) cookie!];

  @override
  Future<bool> setCookie({
    required WebUri url,
    required String name,
    required String value,
    String path = '/',
    String? domain,
    int? expiresDate,
    int? maxAge,
    bool? isSecure,
    bool? isHttpOnly,
    HTTPCookieSameSitePolicy? sameSite,
    PlatformInAppWebViewController? iosBelow11WebViewController,
    PlatformInAppWebViewController? webViewController,
  }) async {
    saved = (
      url: url.toString(),
      name: name,
      value: value,
      domain: domain,
      secure: isSecure,
      httpOnly: isHttpOnly,
      sameSite: sameSite,
    );
    cookie = Cookie(name: name, value: value);
    return acceptCookie;
  }
}

class _BrowserView extends PlatformInAppWebViewWidget {
  _BrowserView(super.params) : super.implementation();
  final controller = _Controller();
  bool created = false;

  @override
  Widget build(BuildContext context) {
    if (!created) {
      created = true;
      params.onWebViewCreated?.call(controllerFromPlatform(controller));
    }
    return const Text('native-browser');
  }

  void finish(String url) =>
      params.onLoadStop?.call(controllerFromPlatform(controller), WebUri(url));

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

class _Controller extends PlatformInAppWebViewController {
  _Controller()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 'mock-browser'),
      );
  Object? loginForm = false;
  WebUri? url;
  Completer<Object?>? document;
  final scripts = <String>[];

  @override
  Future<WebUri?> getUrl() async => url;

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    scripts.add(source);
    return document == null ? loginForm : await document!.future;
  }

  @override
  Future<void> stopLoading() async {}

  @override
  void dispose({bool isKeepAlive = false}) {}
}

class _Locations extends GeolocatorPlatform {
  int checks = 0;
  int requests = 0;

  @override
  Future<LocationPermission> checkPermission() async {
    checks++;
    return LocationPermission.whileInUse;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return LocationPermission.whileInUse;
  }
}
