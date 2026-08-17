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
  AppRoutes.calendar,
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
