import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/tool_page_wrapper.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/app_themes.dart';

const _bodyKey = Key('body');
const _surfaceKey = Key('surface');

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

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  for (final brightness in Brightness.values) {
    for (final (seedName, seed) in [
      ('purple', Colors.deepPurple),
      ('teal', Colors.teal),
    ]) {
      testWidgets(
        'shell lets the status area follow the scrolling page bar for $brightness $seedName',
        (tester) async {
          _viewport(tester);
          final scheme = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: brightness,
          );
          final controller = PageController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            RepaintBoundary(
              key: _surfaceKey,
              child: MaterialApp(
                theme: buildThemeFromScheme(scheme),
                home: AppScaffold.shell(
                  body: AppScaffold(
                    appBar: AppBar(title: const Text('Campus code')),
                    body: PageView(
                      controller: controller,
                      scrollDirection: Axis.vertical,
                      children: const [
                        Center(child: Text('Payment code')),
                        Center(child: Text('Library code')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          Material appBarSurface() => tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(AppBar),
                  matching: find.byType(Material),
                )
                .first,
          );
          Future<void> expectSurfacePixels(Color expected) async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(_surfaceKey),
            );
            final pixels = await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              image.dispose();
              return bytes!;
            });
            for (final y in [12, 40]) {
              final offset = (y * 400 + 8) * 4;
              final pixel = Color.fromARGB(
                pixels!.getUint8(offset + 3),
                pixels.getUint8(offset),
                pixels.getUint8(offset + 1),
                pixels.getUint8(offset + 2),
              );
              expect(
                pixel.toARGB32(),
                expected.toARGB32(),
                reason: 'surface pixel at y=$y',
              );
            }
          }

          expect(
            tester.getRect(find.byType(AppBar)),
            const Rect.fromLTWH(0, 0, 400, 80),
          );
          expect(appBarSurface().color, scheme.surface);
          await expectSurfacePixels(appBarSurface().color!);
          await tester.drag(find.byType(PageView), const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(controller.page, 1);
          expect(appBarSurface().color, scheme.surfaceContainer);
          await expectSurfacePixels(appBarSurface().color!);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'page without chrome avoids every inset and clears consumed padding',
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
      late EdgeInsets childPadding;
      await tester.pumpWidget(
        _app(
          AppScaffold(
            backgroundColor: Colors.red,
            body: AppSafeContent(
              child: Builder(
                builder: (context) {
                  childPadding = MediaQuery.paddingOf(context);
                  return const SizedBox.expand(key: _bodyKey);
                },
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getRect(find.byKey(_bodyKey)),
        const Rect.fromLTRB(48, 24, 1168, 566),
      );
      expect(childPadding, EdgeInsets.zero);
      expect(
        tester.getRect(find.byType(Scaffold)),
        const Rect.fromLTWH(0, 0, 1200, 600),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.red,
      );
    },
  );

  testWidgets('app bar paints across the cutout while body avoids it once', (
    tester,
  ) async {
    _viewport(
      tester,
      size: const Size(1200, 600),
      padding: const FakeViewPadding(left: 48, top: 24, right: 32, bottom: 34),
    );
    await tester.pumpWidget(
      _app(
        AppScaffold(
          appBar: AppBar(
            leading: const Icon(Icons.menu),
            title: const Text('Title'),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
            ],
          ),
          body: const AppSafeContent(child: SizedBox.expand(key: _bodyKey)),
        ),
      ),
    );
    expect(
      tester.getRect(find.byType(AppBar)),
      const Rect.fromLTWH(0, 0, 1200, 80),
    );
    expect(
      tester.getCenter(find.byIcon(Icons.menu)).dx,
      48 + kToolbarHeight / 2,
    );
    expect(tester.getCenter(find.byIcon(Icons.add)).dx, lessThan(1168));
    expect(
      tester.getRect(find.byKey(_bodyKey)),
      const Rect.fromLTRB(48, 80, 1168, 566),
    );
  });

  testWidgets('nested page and bottom navigation consume system insets once', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(
      _app(
        AppScaffold.shell(
          body: AppScaffold(
            appBar: AppBar(title: const Text('Nested page')),
            body: const SizedBox.expand(key: _bodyKey),
          ),
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.person), label: 'My'),
            ],
          ),
        ),
      ),
    );
    final navigation = tester.getRect(find.byType(NavigationBar));
    final body = tester.getRect(find.byKey(_bodyKey));
    expect(navigation.bottom, 620);
    expect(navigation.height, 80 + 34);
    expect(
      tester.getRect(find.byType(AppBar)),
      const Rect.fromLTWH(0, 0, 400, 80),
    );
    expect(body.top, 80);
    expect(body.bottom, navigation.top);
    expect(tester.getRect(find.text('Home')).bottom, lessThanOrEqualTo(586));
  });

  testWidgets(
    'keyboard consumes its height once without retaining gesture padding',
    (tester) async {
      _viewport(tester, keyboard: 200);
      await tester.pumpWidget(
        _app(
          AppScaffold.shell(
            body: AppScaffold(
              appBar: AppBar(title: const Text('Keyboard')),
              body: const SizedBox.expand(key: _bodyKey),
            ),
          ),
        ),
      );
      expect(
        tester.getRect(find.byKey(_bodyKey)),
        const Rect.fromLTRB(0, 80, 400, 420),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tool page footer has the same safe bounds for lists and slivers',
    (tester) async {
      _viewport(tester);
      Rect? expectedFooter;
      for (final mode in ['list', 'paddedList', 'slivers']) {
        final content = [const SizedBox(height: 1000)];
        await tester.pumpWidget(
          _app(
            AppScaffold(
              appBar: AppBar(title: const Text('Tool')),
              body: ToolPageWrapper(
                onRefresh: () async {},
                loading: false,
                emptyText: 'Empty',
                refreshTime: DateTime(2026),
                slivers: mode == 'slivers'
                    ? [
                        for (final child in content)
                          SliverToBoxAdapter(child: child),
                      ]
                    : null,
                child: mode == 'slivers'
                    ? null
                    : ListView(
                        padding: mode == 'paddedList' ? EdgeInsets.zero : null,
                        children: content,
                      ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final footer = tester.getRect(find.textContaining('2026'));
        expect(footer.bottom, lessThanOrEqualTo(586), reason: mode);
        expectedFooter ??= footer;
        expect(footer, expectedFooter, reason: mode);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
