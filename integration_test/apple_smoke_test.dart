import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/general_settings_page.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Apple Keychain stores and deletes login credentials', (
    tester,
  ) async {
    final storage = AuthStorage();
    final previous = await storage.loadCredentials();
    try {
      await storage.saveCredentials('apple-smoke-test', 'test-password');
      expect(await storage.loadCredentials(), (
        username: 'apple-smoke-test',
        password: 'test-password',
      ));
      await storage.clearCredentials();
      expect(await storage.loadCredentials(), isNull);
    } finally {
      if (previous != null) {
        await storage.saveCredentials(previous.username, previous.password);
      } else {
        await storage.clearCredentials();
      }
    }
  }, skip: !Platform.isMacOS && !Platform.isIOS);

  testWidgets('Apple settings load with native preferences and dynamic color', (
    tester,
  ) async {
    final settings = AppSettings();
    await settings.load();
    await settings.initDynamicColor();
    try {
      await tester.pumpWidget(
        AppSettingsProvider(
          settings: settings,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: settings.lightTheme,
            home: const GeneralSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettingsPage), findsOneWidget);
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      settings.dispose();
    }
  }, skip: !Platform.isMacOS && !Platform.isIOS);

  testWidgets('Apple WebView loads HTML and executes JavaScript', (
    tester,
  ) async {
    final loaded = Completer<Object?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InAppWebView(
            initialData: InAppWebViewInitialData(
              data: '<html><body><p id="smoke">FZU Assistant</p></body></html>',
            ),
            onLoadStop: (controller, url) async {
              if (loaded.isCompleted) return;
              try {
                final title = await controller.evaluateJavascript(
                  source: 'document.getElementById("smoke").textContent',
                );
                if (!loaded.isCompleted) loaded.complete(title);
              } catch (error, stack) {
                if (!loaded.isCompleted) loaded.completeError(error, stack);
              }
            },
          ),
        ),
      ),
    );
    final elapsed = Stopwatch()..start();
    while (!loaded.isCompleted &&
        elapsed.elapsed < const Duration(seconds: 30)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      loaded.isCompleted,
      isTrue,
      reason: 'WebView did not finish loading',
    );
    expect(await loaded.future, 'FZU Assistant');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !Platform.isMacOS && !Platform.isIOS);
}
