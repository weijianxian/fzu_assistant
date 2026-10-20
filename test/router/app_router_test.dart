import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/guest/editor_page.dart';
import 'package:fzu_assistant/screen/guest/webview_page.dart';
import 'package:fzu_assistant/screen/home/home_screen.dart';

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
  testWidgets(
    'page content consumes cutout padding once while barriers stay full screen',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(left: 48, top: 24);
      tester.view.viewPadding = const FakeViewPadding(left: 48, top: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: AppRoutes.dev,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byIcon(Icons.science_outlined)).dx, 64);
      await tester.tap(find.text('Native BottomSheet'));
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
