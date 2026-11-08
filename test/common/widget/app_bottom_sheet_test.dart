import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:fzu_assistant/common/widget/sheet/app_bottom_sheet.dart';
import 'package:fzu_assistant/common/widget/sheet/half_screen_sheet.dart';
import 'package:fzu_assistant/common/widget/sheet/sheet_drag_handle.dart';

void main() {
  void viewport(WidgetTester tester, Size size, FakeViewPadding padding) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    addTearDown(tester.view.reset);
  }

  for (final list in [false, true]) {
    testWidgets(
      '${list ? 'list' : 'ordinary'} short content fits its height and can be swiped closed',
      (tester) async {
        viewport(
          tester,
          const Size(400, 800),
          const FakeViewPadding(top: 24, bottom: 34),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    if (list) {
                      showHalfScreenSheet<void>(
                        context,
                        builder: (controller) => AppListView(
                          controller: controller,
                          children: const [
                            ListTile(title: Text('First')),
                            ListTile(title: Text('Second')),
                          ],
                        ),
                      );
                    } else {
                      showAppBottomSheet<void>(
                        context: context,
                        builder: (_) =>
                            const SizedBox(width: double.infinity, height: 100),
                      );
                    }
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final sheet = tester.getRect(find.byType(DraggableScrollableSheet));
        expect(sheet.height, closeTo((list ? 112 : 100) + 20 + 34, 0.01));
        expect(sheet.bottom, 800);
        expect(
          tester.getRect(find.byType(ModalBarrier).last),
          const Rect.fromLTWH(0, 0, 400, 800),
        );
        await tester.drag(find.byType(Scrollable), const Offset(0, 200));
        await tester.pumpAndSettle();
        expect(find.byType(DraggableScrollableSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'long lists start at half height, expand by touch and stay lazy',
    (tester) async {
      viewport(
        tester,
        const Size(400, 800),
        const FakeViewPadding(top: 24, bottom: 34),
      );
      var builtRows = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showHalfScreenSheet<void>(
                  context,
                  builder: (controller) => AppListView.builder(
                    controller: controller,
                    itemExtent: 56,
                    itemCount: 10000,
                    itemBuilder: (_, index) {
                      builtRows++;
                      return ListTile(title: Text('Item $index'));
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final initial = tester.getRect(find.byType(DraggableScrollableSheet));
      expect(initial.height, closeTo((800 - 24) / 2, 0.01));
      expect(builtRows, lessThan(100));
      await tester.drag(find.byType(Scrollable), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DraggableScrollableSheet)).height,
        greaterThan(initial.height + 200),
      );
      expect(builtRows, lessThan(100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short sheet includes its fixed footer once in its natural height',
    (tester) async {
      viewport(
        tester,
        const Size(400, 800),
        const FakeViewPadding(top: 24, bottom: 34),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showHalfScreenSheet<void>(
                  context,
                  builder: (controller) => AppScaffold(
                    body: AppListView(
                      controller: controller,
                      children: const [
                        ListTile(title: Text('First')),
                        ListTile(title: Text('Second')),
                      ],
                    ),
                    bottomNavigationBar: const AppBottomBar(
                      child: SizedBox(height: 48),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(DraggableScrollableSheet));
      expect(sheet.height, closeTo(20 + 112 + 48 + 34, 0.01));
      expect(tester.getRect(find.byType(AppBottomBar)).bottom, 800);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'content changes resize an untouched sheet and keep content state',
    (tester) async {
      viewport(
        tester,
        const Size(400, 800),
        const FakeViewPadding(top: 24, bottom: 34),
      );
      late StateSetter update;
      var height = 80.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppBottomSheet<void>(
                  context: context,
                  builder: (_) => StatefulBuilder(
                    builder: (_, setState) {
                      update = setState;
                      return SizedBox(height: height);
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final contentState = tester.state(find.byType(StatefulBuilder));
      expect(
        tester.getSize(find.byType(DraggableScrollableSheet)).height,
        closeTo(80 + 20 + 34, 0.01),
      );
      update(() => height = 40);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DraggableScrollableSheet)).height,
        closeTo(40 + 20 + 34, 0.01),
      );
      update(() => height = 1000);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DraggableScrollableSheet)).height,
        closeTo((800 - 24) / 2, 0.01),
      );
      update(() => height = 120);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DraggableScrollableSheet)).height,
        closeTo(120 + 20 + 34, 0.01),
      );
      expect(tester.state(find.byType(StatefulBuilder)), same(contentState));
      expect(tester.takeException(), isNull);
    },
  );

  for (final footer in [false, true]) {
    testWidgets(
      'empty content with no bottom inset can close by its handle footer=$footer',
      (tester) async {
        viewport(tester, const Size(400, 800), const FakeViewPadding(top: 24));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    if (footer) {
                      showHalfScreenSheet<void>(
                        context,
                        builder: (controller) => AppScaffold(
                          body: AppListView(
                            controller: controller,
                            children: const [],
                          ),
                          bottomNavigationBar: const AppBottomBar(
                            child: SizedBox(height: 48),
                          ),
                        ),
                      );
                    } else {
                      showAppBottomSheet<void>(
                        context: context,
                        builder: (_) => const SizedBox.shrink(),
                      );
                    }
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(DraggableScrollableSheet)).height,
          closeTo(20 + (footer ? 48 : 0), 0.01),
        );
        await tester.drag(find.byType(SheetDragHandle), const Offset(0, 80));
        await tester.pumpAndSettle();
        expect(find.byType(DraggableScrollableSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'ordinary content reuses the landscape side panel and full-screen scrim',
    (tester) async {
      viewport(
        tester,
        const Size(1200, 600),
        const FakeViewPadding(left: 48, top: 24, right: 32, bottom: 34),
      );
      const contentKey = Key('sheet-content');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAppBottomSheet<void>(
                    context: context,
                    backgroundColor: Colors.amber,
                    builder: (_) => const SizedBox(
                      key: contentKey,
                      height: 1000,
                      width: double.infinity,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(ModalBarrier).last),
        const Rect.fromLTWH(0, 0, 1200, 600),
      );
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final content = tester.getRect(find.byKey(contentKey));
      final surface = find
          .ancestor(of: find.byKey(contentKey), matching: find.byType(Material))
          .first;
      expect(tester.getRect(surface), const Rect.fromLTWH(400, 0, 800, 600));
      expect(tester.widget<Material>(surface).color, Colors.amber);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byType(SheetDragHandle), findsNothing);
      expect(content.left, 448);
      expect(content.right, 1168);
      expect(content.bottom, 566);
      expect(tester.getRect(find.byType(Scrollable)).bottom, 600);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bottom sheet from a nested navigator covers the entire window', (
    tester,
  ) async {
    viewport(
      tester,
      const Size(1200, 600),
      const FakeViewPadding(left: 48, top: 24, right: 32, bottom: 34),
    );
    const contentKey = Key('nested-sheet-content');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                const Expanded(child: SizedBox.expand()),
                Expanded(
                  flex: 2,
                  child: LayoutBuilder(
                    builder: (context, constraints) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(size: constraints.biggest),
                      child: HeroControllerScope.none(
                        child: Navigator(
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (context) => Scaffold(
                              body: Center(
                                child: TextButton(
                                  onPressed: () => showAppBottomSheet<void>(
                                    context: context,
                                    builder: (_) => const SizedBox(
                                      key: contentKey,
                                      width: double.infinity,
                                      height: 1000,
                                    ),
                                  ),
                                  child: const Text('Open nested'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open nested'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(ModalBarrier).last),
      const Rect.fromLTWH(0, 0, 1200, 600),
    );
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final surface = find
        .ancestor(of: find.byKey(contentKey), matching: find.byType(Material))
        .first;
    expect(tester.getRect(surface), const Rect.fromLTWH(400, 0, 800, 600));
    expect(tester.getRect(find.byKey(contentKey)).bottom, 566);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bottom sheet moves above the keyboard and scrolls tall content',
    (tester) async {
      viewport(
        tester,
        const Size(400, 620),
        const FakeViewPadding(top: 24, bottom: 34),
      );
      const actionKey = Key('sheet-action');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppBottomSheet<void>(
                  context: context,
                  builder: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 1000),
                      FilledButton(
                        key: actionKey,
                        onPressed: () {},
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      tester.view.padding = const FakeViewPadding(top: 24);
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).last,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final action = tester.getRect(find.byKey(actionKey));
      expect(action.bottom, lessThanOrEqualTo(380));
      expect(action.top, greaterThanOrEqualTo(24));
      expect(tester.getRect(find.byType(Scrollable).last).bottom, 380);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('portrait half sheet consumes left and right cutouts', (
    tester,
  ) async {
    viewport(
      tester,
      const Size(400, 800),
      const FakeViewPadding(left: 16, top: 24, right: 12, bottom: 34),
    );
    const listKey = Key('half-sheet-list');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showHalfScreenSheet<void>(
                context,
                builder: (controller) => AppListView(
                  key: listKey,
                  controller: controller,
                  children: const [Text('Content')],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final list = tester.getRect(find.byKey(listKey));
    expect(list.left, 16);
    expect(list.right, 388);
    expect(list.bottom, 800);
    expect(
      tester.getRect(find.byType(ModalBarrier).last),
      const Rect.fromLTWH(0, 0, 400, 800),
    );
    expect(tester.takeException(), isNull);
  });

  for (final landscape in [true, false]) {
    testWidgets(
      'half sheet scrolls through the gesture area and fully shows item 20 in ${landscape ? 'landscape' : 'portrait'}',
      (tester) async {
        final size = landscape ? const Size(1200, 600) : const Size(400, 800);
        final padding = landscape
            ? const FakeViewPadding(left: 48, top: 24, right: 32, bottom: 34)
            : const FakeViewPadding(left: 16, top: 24, right: 12, bottom: 34);
        viewport(tester, size, padding);
        const surfaceKey = Key('half-sheet-surface');
        const listKey = Key('half-sheet-items');
        await tester.pumpWidget(
          RepaintBoundary(
            key: surfaceKey,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showHalfScreenSheet<void>(
                      context,
                      builder: (controller) => AppListView.builder(
                        key: listKey,
                        controller: controller,
                        itemCount: 20,
                        itemBuilder: (_, i) => ColoredBox(
                          color: Colors.red,
                          child: ListTile(title: Text('Item ${i + 1}')),
                        ),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final nativeList = find.descendant(
          of: find.byKey(listKey),
          matching: find.byType(ListView),
        );
        final bounds = tester.getRect(nativeList);
        expect(bounds.bottom, size.height);
        expect(bounds.top, greaterThanOrEqualTo(padding.top));
        expect(bounds.left, greaterThanOrEqualTo(padding.left));
        expect(bounds.right, size.width - padding.right);
        expect(
          tester.getRect(find.byType(ModalBarrier).last),
          Offset.zero & size,
        );
        final scroll = tester.state<ScrollableState>(
          find.descendant(of: nativeList, matching: find.byType(Scrollable)),
        );
        scroll.position.jumpTo(200);
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(surfaceKey),
        );
        final pixels = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return bytes!;
        });
        final x = bounds.right.toInt() - 8;
        final y = size.height.toInt() - 8;
        final offset = (y * size.width.toInt() + x) * 4;
        final pixel = Color.fromARGB(
          pixels!.getUint8(offset + 3),
          pixels.getUint8(offset),
          pixels.getUint8(offset + 1),
          pixels.getUint8(offset + 2),
        );
        expect(pixel.toARGB32(), Colors.red.toARGB32());
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final lastItem = tester.getRect(find.text('Item 20'));
        expect(lastItem.top, greaterThanOrEqualTo(bounds.top));
        expect(
          lastItem.bottom,
          lessThanOrEqualTo(size.height - padding.bottom),
        );
        expect(lastItem.left, greaterThanOrEqualTo(bounds.left));
        expect(lastItem.right, lessThanOrEqualTo(bounds.right));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'side sheet keeps two thirds width and symmetric content margins in large and small windows',
    (tester) async {
      for (final size in [
        const Size(1200, 600),
        const Size(500, 300),
        const Size(280, 200),
      ]) {
        viewport(
          tester,
          size,
          const FakeViewPadding(left: 48, top: 24, right: 20, bottom: 34),
        );
        const pageKey = Key('side-sheet-page');
        const bodyKey = Key('side-sheet-body');
        const finalBodyKey = Key('side-sheet-final-body');
        const actionKey = Key('side-sheet-action');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showHalfScreenSheet<void>(
                    context,
                    builder: (controller) => AppScaffold(
                      key: pageKey,
                      body: AppListView(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: const [
                          SizedBox(key: bodyKey, height: 1000),
                          SizedBox(key: finalBodyKey, height: 48),
                        ],
                      ),
                      bottomNavigationBar: AppBottomBar(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: SizedBox(
                            key: actionKey,
                            height: 40,
                            child: FilledButton(
                              onPressed: () {},
                              child: const Icon(Icons.done),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final side = tester.getRect(
          find
              .ancestor(
                of: find.byKey(pageKey),
                matching: find.byType(Material),
              )
              .first,
        );
        final page = tester.getRect(
          find.descendant(
            of: find.byKey(pageKey),
            matching: find.byType(Scaffold),
          ),
        );
        final close = tester.getRect(
          find.widgetWithIcon(IconButton, Icons.chevron_right),
        );
        expect(close.width, greaterThanOrEqualTo(48));
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.chevron_right),
              )
              .tooltip,
          MaterialLocalizations.of(
            tester.element(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            ),
          ).closeButtonTooltip,
        );
        final list = tester.getRect(find.byType(ListView));
        final body = tester.getRect(find.byKey(bodyKey));
        final action = tester.getRect(find.byKey(actionKey));
        final footer = tester.getRect(find.byType(AppBottomBar));
        expect(side.width, closeTo(size.width * 2 / 3, 0.001));
        expect(side.right, size.width);
        expect(close.left, side.left);
        expect(page.left, close.right);
        expect(page.right, size.width - 20);
        expect(page.bottom, size.height);
        expect(list.left, page.left);
        expect(list.right, page.right);
        expect(list.bottom, footer.top);
        expect(body.left - page.left, closeTo(12, 0.001));
        expect(page.right - body.right, closeTo(12, 0.001));
        expect(action.left, closeTo(body.left, 0.001));
        expect(action.right, closeTo(body.right, 0.001));
        expect(footer.bottom, size.height);
        expect(action.bottom, size.height - 34 - 8);
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(finalBodyKey)).bottom, list.bottom);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'portrait and standard sheets use one centered handle with equal vertical gaps',
    (tester) async {
      viewport(
        tester,
        const Size(400, 800),
        const FakeViewPadding(top: 24, bottom: 34),
      );
      for (final half in [true, false]) {
        const contentKey = Key('handle-content');
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              bottomSheetTheme: const BottomSheetThemeData(
                showDragHandle: true,
              ),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    if (half) {
                      showHalfScreenSheet<void>(
                        context,
                        builder: (controller) => AppListView(
                          key: contentKey,
                          controller: controller,
                          children: const [Text('Content')],
                        ),
                      );
                    } else {
                      showAppBottomSheet<void>(
                        context: context,
                        builder: (_) =>
                            const SizedBox(key: contentKey, height: 100),
                      );
                    }
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(SheetDragHandle), findsOneWidget);
        final handle = tester.getRect(find.byType(SheetDragHandle));
        final bar = tester.getRect(
          find.descendant(
            of: find.byType(SheetDragHandle),
            matching: find.byType(Container),
          ),
        );
        expect(bar.size, const Size(40, 4));
        expect(bar.top - handle.top, 8);
        expect(handle.bottom - bar.bottom, 8);
        expect(bar.center.dx, handle.center.dx);
        expect(tester.getRect(find.byKey(contentKey)).top, handle.bottom);
        final surface = tester.getRect(find.byType(DraggableScrollableSheet));
        expect(handle.top, surface.top);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
}
