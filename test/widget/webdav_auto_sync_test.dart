import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/webdav_auto_sync.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';

class _Service extends WebDavSyncService {
  int calls = 0;
  WebDavAutoSyncResult result = WebDavAutoSyncResult.unchanged;
  Completer<WebDavAutoSyncResult>? pending;
  bool fail = false;

  @override
  Future<WebDavAutoSyncResult> autoSync({
    required void Function(WebDavSnapshot) apply,
  }) async {
    calls++;
    if (fail) throw Exception('private connection details');
    return pending?.future ?? result;
  }
}

Widget _app({
  required AppSettings settings,
  required Future<void> ready,
  required _Service service,
  Locale locale = const Locale('zh'),
  double textScale = 1,
  bool withNavigation = false,
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  return MaterialApp(
    navigatorKey: navigatorKey,
    scaffoldMessengerKey: messengerKey,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {
      AppRoutes.webDavSettings: (_) =>
          const Scaffold(body: Text('WebDAV settings destination')),
    },
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: WebDavAutoSync(
        settings: settings,
        ready: ready,
        navigatorKey: navigatorKey,
        messengerKey: messengerKey,
        service: service,
        child: child!,
      ),
    ),
    home: withNavigation
        ? AppScaffold.shell(
            body: const AppScaffold(body: Center(child: Text('Home'))),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Home tab',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person),
                  label: 'Profile tab',
                ),
              ],
            ),
          )
        : const Scaffold(body: Text('Home')),
  );
}

void main() {
  testWidgets(
    'waits for settings and syncs only when truly reopening the app',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final settings = AppSettings();
      final service = _Service();
      final ready = Completer<void>();
      addTearDown(settings.dispose);
      addTearDown(() => service.dio.close(force: true));

      await tester.pumpWidget(
        _app(settings: settings, ready: ready.future, service: service),
      );
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      expect(service.calls, 0);

      ready.complete();
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(find.byType(SnackBar), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.calls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.calls, 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.calls, 3);
    },
  );

  testWidgets(
    'reopening during a pending sync does not start another request',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final settings = AppSettings();
      final service = _Service()..pending = Completer<WebDavAutoSyncResult>();
      addTearDown(settings.dispose);
      addTearDown(() => service.dio.close(force: true));
      await tester.pumpWidget(
        _app(settings: settings, ready: Future.value(), service: service),
      );
      await tester.pump();
      expect(service.calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.calls, 1);
      service.pending!.complete(WebDavAutoSyncResult.downloaded);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('conflicts offer a working route to manual WebDAV settings', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final settings = AppSettings();
    final service = _Service()..result = WebDavAutoSyncResult.conflict;
    addTearDown(settings.dispose);
    addTearDown(() => service.dio.close(force: true));
    await tester.pumpWidget(
      _app(settings: settings, ready: Future.value(), service: service),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.text('Home')))!;
    expect(find.text(l10n.webdavAutoSyncConflict), findsOneWidget);
    await tester.tap(find.text(l10n.settings));
    await tester.pumpAndSettle();
    expect(find.text('WebDAV settings destination'), findsOneWidget);
    expect(service.calls, 1);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    for (final size in [const Size(320, 900), const Size(900, 400)]) {
      testWidgets(
        'sync notice keeps its action beside text above navigation in ${locale.languageCode} at $size with larger text',
        (tester) async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          final landscape = size.width > size.height;
          final insets = landscape
              ? const FakeViewPadding(left: 48, top: 24, right: 20, bottom: 34)
              : const FakeViewPadding(top: 32, bottom: 34);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = insets;
          tester.view.viewPadding = insets;
          addTearDown(tester.view.reset);
          final settings = AppSettings();
          final service = _Service()..result = WebDavAutoSyncResult.conflict;
          addTearDown(settings.dispose);
          addTearDown(() => service.dio.close(force: true));
          await tester.pumpWidget(
            _app(
              settings: settings,
              ready: Future.value(),
              service: service,
              locale: locale,
              textScale: 1.4,
              withNavigation: true,
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(tester.element(find.text('Home')))!;
          final message = tester.getRect(
            find.text(l10n.webdavAutoSyncConflict),
          );
          final action = tester.getRect(
            find.widgetWithText(SnackBarAction, l10n.settings),
          );
          final bar = tester.getRect(find.byType(SnackBar));
          final navigation = tester.getRect(find.byType(NavigationBar));
          expect(action.top, lessThan(message.bottom));
          expect(action.bottom, greaterThan(message.top));
          expect(action.left, greaterThanOrEqualTo(message.right));
          expect(bar.bottom, closeTo(navigation.top, 0.001));
          expect(navigation.bottom, size.height);
          expect(message.left, greaterThanOrEqualTo(insets.left));
          expect(action.right, lessThanOrEqualTo(size.width - insets.right));
          expect(service.calls, 1);
          await tester.tap(find.widgetWithText(SnackBarAction, l10n.settings));
          await tester.pumpAndSettle();
          expect(find.text('WebDAV settings destination'), findsOneWidget);
          expect(service.calls, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('connection failures show one localized sentence', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final settings = AppSettings();
    final service = _Service()..fail = true;
    addTearDown(settings.dispose);
    addTearDown(() => service.dio.close(force: true));
    await tester.pumpWidget(
      _app(settings: settings, ready: Future.value(), service: service),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.text('Home')))!;
    expect(find.text(l10n.webdavAutoSyncFailed), findsOneWidget);
    expect(find.textContaining('private connection details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing while settings load does not start synchronization', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final settings = AppSettings();
    final service = _Service();
    final ready = Completer<void>();
    addTearDown(settings.dispose);
    addTearDown(() => service.dio.close(force: true));
    await tester.pumpWidget(
      _app(settings: settings, ready: ready.future, service: service),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    ready.complete();
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(tester.takeException(), isNull);
  });
}
