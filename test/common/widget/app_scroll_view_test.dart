import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:fzu_assistant/common/widget/layout/split_navigation_page.dart';

const _surfaceKey = Key('scroll-surface');
const _lastActionKey = Key('last-action');

void _viewport(
  WidgetTester tester, {
  Size size = const Size(400, 620),
  FakeViewPadding padding = const FakeViewPadding(top: 24, bottom: 34),
  double keyboard = 0,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewPadding = padding;
  tester.view.padding = FakeViewPadding(
    left: padding.left,
    top: padding.top,
    right: padding.right,
    bottom: keyboard == 0 ? padding.bottom : 0,
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

Future<int> _pixelAt(WidgetTester tester, int x, int y) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_surfaceKey),
  );
  final pixels = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final width = image.width;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return (bytes!, width);
  });
  final (bytes, width) = pixels!;
  final offset = (y * width + x) * 4;
  return Color.fromARGB(
    bytes.getUint8(offset + 3),
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  ).toARGB32();
}

Widget _scrollContent(
  String mode,
  ScrollController controller,
  EdgeInsets padding,
) {
  final children = [
    const SizedBox(
      height: 1400,
      width: double.infinity,
      child: ColoredBox(color: Colors.red),
    ),
    SizedBox(
      key: _lastActionKey,
      height: 48,
      child: FilledButton(onPressed: () {}, child: const Text('Last action')),
    ),
  ];
  return switch (mode) {
    'list' => AppListView(
      controller: controller,
      padding: padding == EdgeInsets.zero ? null : padding,
      children: children,
    ),
    'slivers' => AppCustomScrollView(
      controller: controller,
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList.list(children: children),
        ),
      ],
    ),
    _ => AppSingleChildScrollView(
      controller: controller,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  };
}

void main() {
  for (final mode in ['list', 'slivers', 'single']) {
    for (final designPadding in [0.0, 16.0]) {
      testWidgets(
        '$mode paints through the gesture area and insets its final action with padding $designPadding',
        (tester) async {
          _viewport(tester);
          final controller = ScrollController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            RepaintBoundary(
              key: _surfaceKey,
              child: MaterialApp(
                home: AppScaffold(
                  appBar: AppBar(title: const Text('Scrolling page')),
                  body: _scrollContent(
                    mode,
                    controller,
                    EdgeInsets.all(designPadding),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final viewport = tester.getRect(find.byType(Scrollable));
          expect(viewport.top, 80);
          expect(viewport.bottom, 620);
          controller.jumpTo(200);
          await tester.pumpAndSettle();
          expect(await _pixelAt(tester, 200, 610), Colors.red.toARGB32());
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(_lastActionKey)).bottom,
            586 - designPadding,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('nested scrolling content reserves the gesture padding once', (
    tester,
  ) async {
    _viewport(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AppScaffold(
          appBar: AppBar(title: const Text('Nested list')),
          body: AppSingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                const SizedBox(height: 1000),
                AppListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [SizedBox(key: _lastActionKey, height: 48)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_lastActionKey)).bottom, 586);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard reduces the viewport once and adds no gesture padding',
    (tester) async {
      _viewport(tester, keyboard: 200);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold.shell(
            body: AppScaffold(
              appBar: AppBar(title: const Text('Keyboard')),
              body: _scrollContent(
                'list',
                controller,
                const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(Scrollable)).bottom, 420);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_lastActionKey)).bottom, 404);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fixed bottom actions own the gesture area without padding the list twice',
    (tester) async {
      _viewport(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final theme = ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal);
      await tester.pumpWidget(
        RepaintBoundary(
          key: _surfaceKey,
          child: MaterialApp(
            theme: theme,
            home: AppScaffold(
              appBar: AppBar(title: const Text('Fixed action')),
              body: _scrollContent('list', controller, EdgeInsets.zero),
              bottomNavigationBar: AppBottomBar(
                child: SizedBox(
                  key: const Key('fixed-action'),
                  height: 48,
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Submit'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byType(AppBottomBar));
      expect(bar.bottom, 620);
      expect(bar.height, 48 + 34);
      expect(tester.getRect(find.byKey(const Key('fixed-action'))).bottom, 586);
      expect(tester.getRect(find.byType(Scrollable)).bottom, bar.top);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_lastActionKey)).bottom, bar.top);
      expect(await _pixelAt(tester, 200, 610), theme.canvasColor.toARGB32());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landscape navigation and detail lists both paint to the bottom',
    (tester) async {
      _viewport(
        tester,
        size: const Size(1200, 600),
        padding: const FakeViewPadding(
          left: 48,
          top: 24,
          right: 32,
          bottom: 34,
        ),
      );
      final detailController = ScrollController();
      addTearDown(detailController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SplitNavigationPage(
            title: 'Features',
            initialRoute: '/first',
            sections: [
              NavigationPaneSection(
                destinations: [
                  for (var i = 0; i < 20; i++)
                    NavigationPaneDestination(
                      icon: Icons.school,
                      title: 'Feature $i',
                      route: i == 0 ? '/first' : '/feature-$i',
                    ),
                ],
              ),
            ],
            footer: const SizedBox(
              key: Key('left-last'),
              height: 48,
              child: Text('Last feature'),
            ),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => AppScaffold(
                appBar: AppBar(title: const Text('Detail')),
                body: _scrollContent('list', detailController, EdgeInsets.zero),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lists = find.byType(Scrollable);
      expect(lists, findsNWidgets(2));
      final leftViewport = tester.getRect(lists.at(0));
      final rightViewport = tester.getRect(lists.at(1));
      expect(leftViewport.bottom, 600);
      expect(rightViewport.bottom, 600);
      expect(leftViewport.left, 48);
      expect(rightViewport.left, greaterThanOrEqualTo(leftViewport.right));
      expect(rightViewport.right, 1168);
      // Lazy delegates refine the final extent as the last rows are laid out.
      for (var pass = 0; pass < 3; pass++) {
        for (final list in lists.evaluate()) {
          final scroll = tester.state<ScrollableState>(
            find.byWidget(list.widget),
          );
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
        }
        await tester.pumpAndSettle();
      }
      expect(tester.getRect(find.byKey(const Key('left-last'))).bottom, 550);
      expect(tester.getRect(find.byKey(_lastActionKey)).bottom, 566);
      expect(tester.takeException(), isNull);
    },
  );
}
