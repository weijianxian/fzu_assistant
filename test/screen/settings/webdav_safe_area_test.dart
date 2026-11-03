import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('WebDAV keeps the final action above the gesture area', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 620);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
    addTearDown(tester.view.reset);
    final settings = AppSettings();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          initialRoute: AppRoutes.webDavSettings,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final download = find.ancestor(
      of: find.byIcon(Icons.cloud_download_outlined),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.getRect(find.byType(ListView)).bottom, 620);
    expect(tester.getRect(download).bottom, lessThanOrEqualTo(586));
    expect(tester.takeException(), isNull);
  });
}
