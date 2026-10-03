import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/split_navigation_page.dart';
import 'package:fzu_assistant/common/widget/navigation/chevron_list_tile.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/my/my.dart';
import 'package:fzu_assistant/screen/settings/general_settings_page.dart';
import 'package:fzu_assistant/screen/settings/settings_page.dart';
import 'package:fzu_assistant/screen/toolbox/gpa/gpa_page.dart';
import 'package:fzu_assistant/screen/toolbox/marks/marks_page.dart';
import 'package:fzu_assistant/screen/toolbox/toolbox.dart';
import 'package:fzu_assistant/screen/toolbox/empty_room/empty_room_page.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(
  AppSettings settings,
  Widget home,
  GlobalKey<NavigatorState> root, {
  RouteFactory? routeFactory,
}) => AppSettingsProvider(
  settings: settings,
  child: MaterialApp(
    navigatorKey: root,
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    onGenerateRoute: routeFactory ?? AppRouter.onGenerateRoute,
    home: home,
  ),
);

void main() {
  testWidgets('空教室横屏矮窗口查询条件可滚动且不溢出', (tester) async {
    tester.view.physicalSize = const Size(640, 280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EmptyRoomPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, '查询').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await ApiClient.instance.clearSession();
  });

  testWidgets('landscape toolbox switches tools inside the right pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final root = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(settings, const ToolboxPage(), root));
    await tester.pumpAndSettle();

    expect(find.byType(SplitNavigationPage), findsOneWidget);
    expect(find.byType(GpaPage), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, '成绩查询'));
    await tester.pumpAndSettle();

    expect(find.byType(MarksPage), findsOneWidget);
    expect(root.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape my page keeps settings subpages in the right pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final root = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(settings, const MyPage(), root));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    await tester.tap(find.widgetWithIcon(ChevronListTile, Icons.tune));
    await tester.pumpAndSettle();

    expect(find.byType(GeneralSettingsPage), findsOneWidget);
    expect(find.byType(SplitNavigationPage), findsOneWidget);
    expect(root.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape logout replaces the entire app session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final root = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(
        settings,
        const MyPage(),
        root,
        routeFactory: (route) => route.name == AppRoutes.login
            ? MaterialPageRoute<void>(
                settings: route,
                builder: (_) => const Scaffold(body: Text('Signed out')),
              )
            : AppRouter.onGenerateRoute(route),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '退出登录'));
    await tester.pumpAndSettle();

    expect(find.text('Signed out'), findsOneWidget);
    expect(find.byType(MyPage), findsNothing);
    expect(find.byType(SplitNavigationPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait toolbox keeps full-page route navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final root = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(settings, const ToolboxPage(), root));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(ListTile, Icons.school_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(SplitNavigationPage), findsNothing);
    expect(find.byType(GpaPage), findsOneWidget);
    expect(root.currentState!.canPop(), isTrue);
    expect(tester.takeException(), isNull);
  });
}
