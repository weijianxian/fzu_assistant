import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/guest/editor_page.dart';
import 'package:fzu_assistant/screen/guest/webview_page.dart';
import 'package:fzu_assistant/screen/home/home_screen.dart';
import 'package:fzu_assistant/service/app_themes.dart';

const _argumentFreeRoutes = [
  AppRoutes.login,
  AppRoutes.home,
  AppRoutes.gpa,
  AppRoutes.marks,
  AppRoutes.credit,
  AppRoutes.unifiedExam,
  AppRoutes.examRoom,
  AppRoutes.emptyRoom,
  AppRoutes.notice,
  AppRoutes.evaluation,
  AppRoutes.learningCenter,
  AppRoutes.learningSeats,
  AppRoutes.learningAppointments,
  AppRoutes.ssoLogin,
  AppRoutes.devLearningCenter,
  AppRoutes.calendar,
  AppRoutes.profile,
  AppRoutes.settings,
  AppRoutes.courseReminderSettings,
  AppRoutes.androidPermissions,
  AppRoutes.homeSettings,
  AppRoutes.generalSettings,
  AppRoutes.advancedSettings,
  AppRoutes.themeSettings,
  AppRoutes.about,
  AppRoutes.dev,
  AppRoutes.devSharedPrefs,
  AppRoutes.devSecureStorage,
];

void main() {
  for (final style in InterfaceStyle.values) {
    testWidgets(
      '$style page shell consumes cutout padding while backgrounds and barriers stay full screen',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 600);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(
          left: 48,
          top: 24,
          right: 32,
          bottom: 34,
        );
        tester.view.viewPadding = tester.view.padding;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(Colors.blue, interfaceStyle: style),
            initialRoute: AppRoutes.dev,
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(Scaffold)).left, 0);
        expect(tester.getRect(find.byType(Scaffold)).width, 1200);
        expect(tester.getRect(find.byType(AppBar)).left, 0);
        expect(tester.getRect(find.byType(AppBar)).width, 1200);
        expect(tester.getRect(find.byType(ListView)).bottom, 600);
        final debugTile = find.widgetWithText(
          ListTile,
          'Learning Center API Debug',
        );
        await _scrollUntilHittable(tester, debugTile);
        final leading = tester.widget<ListTile>(debugTile).leading;
        expect(leading, isNotNull);
        expect(
          tester
              .getTopLeft(
                find.descendant(
                  of: debugTile,
                  matching: find.byWidget(leading!),
                ),
              )
              .dx,
          48 + 16 + (style.isCard ? 16 : 0),
        );
        final sheetTile = find.widgetWithText(ListTile, 'Native BottomSheet');
        await _scrollUntilHittable(tester, sheetTile);
        await tester.tap(sheetTile);
        await tester.pumpAndSettle();
        final barrier = find.byType(ModalBarrier).last;
        expect(tester.getRect(barrier).left, 0);
        expect(tester.getRect(barrier).width, 1200);
        tester.view.physicalSize = const Size(600, 1200);
        tester.view.padding = const FakeViewPadding(top: 48);
        tester.view.viewPadding = const FakeViewPadding(top: 48);
        await tester.pumpAndSettle();
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('resolves every argument-free route', () {
    for (final name in _argumentFreeRoutes) {
      final route = AppRouter.onGenerateRoute(RouteSettings(name: name));
      expect(route, isA<MaterialPageRoute<dynamic>>(), reason: name);
      expect(route!.settings.name, name);
    }
  });

  test('route names are unique', () {
    const routes = [
      ..._argumentFreeRoutes,
      AppRoutes.webview,
      AppRoutes.editor,
    ];

    expect(routes.toSet(), hasLength(routes.length));
  });

  test('resolves routes with typed arguments', () {
    final webview = AppRouter.onGenerateRoute(
      const RouteSettings(
        name: AppRoutes.webview,
        arguments: WebViewArgs(url: 'https://example.com'),
      ),
    );
    final editor = AppRouter.onGenerateRoute(
      RouteSettings(
        name: AppRoutes.editor,
        arguments: EditorArgs(
          title: 'Test',
          initialValue: '{}',
          onSave: (_) async => true,
        ),
      ),
    );

    expect(webview, isA<MaterialPageRoute<dynamic>>());
    expect(editor, isA<MaterialPageRoute<dynamic>>());
  });

  testWidgets('maps typed arguments onto destination pages', (tester) async {
    const webViewArgs = WebViewArgs(
      url: 'https://example.com/path',
      title: 'Example',
      injectCookies: false,
    );
    Future<bool> onSave(String _) async => true;
    final editorArgs = EditorArgs(
      title: 'JSON',
      initialValue: '{"ok":true}',
      onSave: onSave,
    );

    final webViewPage = await _buildRoutePage<WebViewPage>(
      tester,
      AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.webview, arguments: webViewArgs),
      )!,
    );
    final editorPage = await _buildRoutePage<EditorPage>(
      tester,
      AppRouter.onGenerateRoute(
        RouteSettings(name: AppRoutes.editor, arguments: editorArgs),
      )!,
    );

    expect(webViewPage.url, webViewArgs.url);
    expect(webViewPage.title, webViewArgs.title);
    expect(webViewPage.injectCookies, isFalse);
    expect(editorPage.title, editorArgs.title);
    expect(editorPage.initialValue, editorArgs.initialValue);
    expect(editorPage.onSave, same(onSave));
  });

  testWidgets('home route builds the extracted home shell', (tester) async {
    final page = await _buildRoutePage<HomeScreen>(
      tester,
      AppRouter.onGenerateRoute(const RouteSettings(name: AppRoutes.home))!,
    );

    expect(page, isA<HomeScreen>());
  });

  test('rejects missing arguments for parameterized routes', () {
    expect(
      () => AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.webview),
      ),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.editor),
      ),
      throwsA(isA<TypeError>()),
    );
  });

  test('returns null for unknown routes', () {
    expect(
      AppRouter.onGenerateRoute(const RouteSettings(name: '/unknown')),
      isNull,
    );
  });
}

Future<void> _scrollUntilHittable(WidgetTester tester, Finder tile) async {
  final scrollable = find.byType(Scrollable).first;
  for (
    var attempt = 0;
    attempt < 20 && tile.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    // Timed touch movement gives lazy rows and gesture recognition a frame.
    await tester.timedDrag(
      scrollable,
      const Offset(0, -200),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
  }
  expect(tile.hitTestable(), findsOneWidget);
}

Future<T> _buildRoutePage<T>(WidgetTester tester, Route<dynamic> route) async {
  late final Widget page;
  final materialRoute = route as MaterialPageRoute<dynamic>;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          page = materialRoute.builder(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  return page as T;
}
