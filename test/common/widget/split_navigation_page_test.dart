import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/split_navigation_page.dart';
import 'package:fzu_assistant/router/app_routes.dart';

const _sections = [
  NavigationPaneSection(
    title: 'Features',
    destinations: [
      NavigationPaneDestination(
        icon: Icons.school_outlined,
        title: 'First',
        route: '/first',
      ),
      NavigationPaneDestination(
        icon: Icons.settings_outlined,
        title: 'Second',
        route: '/second',
      ),
    ],
  ),
];

Route<dynamic>? _route(RouteSettings settings) => MaterialPageRoute<void>(
  settings: settings,
  builder: (context) => Scaffold(
    appBar: AppBar(title: Text('Detail ${settings.name}')),
    body: Column(
      children: [
        const Hero(tag: 'detail-icon', child: Icon(Icons.school)),
        TextButton(
          onPressed: () => context.pushNamed('/child'),
          child: const Text('Open child'),
        ),
      ],
    ),
  ),
);

Widget _app(GlobalKey<NavigatorState> root, {bool isActive = true}) =>
    MaterialApp(
      navigatorKey: root,
      home: SplitNavigationPage(
        title: 'Panel',
        sections: _sections,
        initialRoute: '/first',
        onGenerateRoute: _route,
        isActive: isActive,
      ),
    );

void main() {
  testWidgets('panes use a 1:2 width ratio', (tester) async {
    final root = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(root));
    await tester.pumpAndSettle();

    final left = tester.getSize(find.widgetWithText(AppBar, 'Panel')).width;
    final right = tester
        .getSize(find.widgetWithText(AppBar, 'Detail /first'))
        .width;
    expect(right, closeTo(left * 2, 0.01));
    expect(root.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a feature replaces only the detail navigator', (
    tester,
  ) async {
    final root = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(root));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Second'));
    await tester.pumpAndSettle();

    expect(find.text('Detail /second'), findsOneWidget);
    expect(find.text('Detail /first'), findsNothing);
    expect(find.text('Panel'), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Second')).selected,
      isTrue,
    );
    expect(root.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('child navigation and system back stay in the detail pane', (
    tester,
  ) async {
    final root = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(root));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();

    expect(find.text('Detail /child'), findsOneWidget);
    expect(find.text('Panel'), findsOneWidget);
    await root.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Detail /first'), findsOneWidget);
    expect(find.text('Detail /child'), findsNothing);
    expect(root.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting the current feature returns to its first page', (
    tester,
  ) async {
    final root = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(root));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'First'));
    await tester.pumpAndSettle();

    expect(find.text('Detail /first'), findsOneWidget);
    expect(find.text('Detail /child'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an inactive pane does not consume system back', (tester) async {
    final root = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(root, isActive: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    await root.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Detail /child'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
