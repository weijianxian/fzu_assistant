import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/my/account_management_page.dart';
import 'package:fzu_assistant/service/account_service.dart';

class _Accounts extends AccountService {
  bool signedIn = true;
  int logoutCalls = 0;
  @override
  Future<AccountStatus> loadStatus() async =>
      (academicAccount: 'academic-a', ssoSignedIn: signedIn);
  @override
  Future<void> logoutSso() async {
    logoutCalls++;
    signedIn = false;
  }
}

void main() {
  for (final size in [const Size(400, 800), const Size(800, 300)]) {
    testWidgets(
      'SSO logout confirms and updates independently of academic credentials at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _Accounts();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountManagementPage(service: service),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.widgetWithText(ListTile, '统一身份认证（SSO）');
        final logout = find.descendant(
          of: row,
          matching: find.byType(TextButton),
        );
        await tester.tap(logout);
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(service.logoutCalls, 0);
        await tester.tap(logout);
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        expect(service.logoutCalls, 1);
        expect(find.text('academic-a'), findsOneWidget);
        expect(tester.widget<TextButton>(logout).onPressed, isNull);
        expect(find.text('未登录'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
