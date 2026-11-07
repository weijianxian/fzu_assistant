import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:fzu_assistant/common/widget/layout/app_top_banner.dart';
import 'package:fzu_assistant/common/widget/layout/split_navigation_page.dart';

const _surfaceKey = Key('shell-surface');
const _bodyKey = Key('shell-page-body');
const _pageTitleKey = Key('shell-page-title');
const _bannerTextKey = Key('shell-banner-text');

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 600);
  tester.view.padding = const FakeViewPadding(
    left: 48,
    top: 24,
    right: 32,
    bottom: 34,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
}

Widget _app(TextDirection direction, Widget child) => RepaintBoundary(
  key: _surfaceKey,
  child: MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      bannerTheme: const MaterialBannerThemeData(
        backgroundColor: Colors.orange,
      ),
    ),
    builder: (context, child) =>
        Directionality(textDirection: direction, child: child!),
    home: child,
  ),
);

NavigationRail _rail() => NavigationRail(
  backgroundColor: Colors.red,
  selectedIndex: 0,
  destinations: const [
    NavigationRailDestination(icon: Icon(Icons.home), label: Text('Home')),
    NavigationRailDestination(icon: Icon(Icons.person), label: Text('My')),
  ],
);

Widget _page() => AppScaffold(
  backgroundColor: Colors.green,
  appBar: AppBar(
    title: const Text('Page', key: _pageTitleKey),
    backgroundColor: Colors.blue,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
  body: const AppSafeContent(child: SizedBox.expand(key: _bodyKey)),
);

Future<void> _expectPixels(
  WidgetTester tester,
  List<(Offset, Color)> samples,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_surfaceKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!;
  });
  final pixels = bytes!;
  for (final (point, expected) in samples) {
    final offset = (point.dy.toInt() * 1200 + point.dx.toInt()) * 4;
    final color = Color.fromARGB(
      pixels.getUint8(offset + 3),
      pixels.getUint8(offset),
      pixels.getUint8(offset + 1),
      pixels.getUint8(offset + 2),
    );
    expect(color.toARGB32(), expected.toARGB32(), reason: 'surface at $point');
  }
}

void main() {
  for (final direction in TextDirection.values) {
    for (final cached in [false, true]) {
      testWidgets(
        'rail and page paint their own system edges in $direction cached=$cached',
        (tester) async {
          _viewport(tester);
          await tester.pumpWidget(
            _app(
              direction,
              AppScaffold.shell(
                backgroundColor: Colors.yellow,
                navigationRail: _rail(),
                topBanner: cached
                    ? AppTopBanner(
                        content: const Text('Cached', key: _bannerTextKey),
                        actions: [
                          TextButton(
                            onPressed: () {},
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : null,
                body: _page(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final rtl = direction == TextDirection.rtl;
          final rail = tester.getRect(find.byType(NavigationRail));
          final pageBar = tester.getRect(find.byType(AppBar));
          final body = tester.getRect(find.byKey(_bodyKey));
          expect(rail.top, 0);
          expect(rail.bottom, 600);
          if (rtl) {
            expect(rail.right, 1200);
            expect(pageBar.left, 0);
            expect(pageBar.right, rail.left);
            expect(body.left, 48);
            expect(body.right, rail.left);
          } else {
            expect(rail.left, 0);
            expect(pageBar.left, rail.right);
            expect(pageBar.right, 1200);
            expect(body.left, rail.right);
            expect(body.right, 1168);
          }
          expect(body.bottom, 566);
          expect(body.top, pageBar.bottom);
          if (cached) {
            final banner = tester.getRect(find.byType(MaterialBanner));
            expect(banner.top, 0);
            expect(banner.left, pageBar.left);
            expect(banner.right, pageBar.right);
            expect(pageBar.top, banner.bottom);
            expect(pageBar.height, kToolbarHeight);
            expect(
              tester.getRect(find.byKey(_bannerTextKey)).top,
              greaterThanOrEqualTo(24),
            );
          } else {
            expect(pageBar.top, 0);
            expect(pageBar.height, 24 + kToolbarHeight);
          }
          await _expectPixels(tester, [
            (Offset(rail.center.dx, 4), Colors.red),
            (
              Offset(pageBar.center.dx, 4),
              cached ? Colors.orange : Colors.blue,
            ),
            (Offset(rail.center.dx, 596), Colors.red),
            (Offset(pageBar.center.dx, 596), Colors.green),
            (Offset(rtl ? 4 : 1196, 4), cached ? Colors.orange : Colors.blue),
          ]);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'split panes consume only their outer screen edges in $direction',
      (tester) async {
        _viewport(tester);
        await tester.pumpWidget(
          _app(
            direction,
            AppScaffold.shell(
              navigationRail: _rail(),
              body: SplitNavigationPage(
                title: 'Tools',
                sections: const [
                  NavigationPaneSection(
                    destinations: [
                      NavigationPaneDestination(
                        icon: Icons.school,
                        title: 'Detail',
                        route: '/detail',
                      ),
                    ],
                  ),
                ],
                initialRoute: '/detail',
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => _page(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rail = tester.getRect(find.byType(NavigationRail));
        final body = tester.getRect(find.byKey(_bodyKey));
        final detailBar = tester.getRect(
          find.ancestor(
            of: find.byKey(_pageTitleKey),
            matching: find.byType(AppBar),
          ),
        );
        final menuList = tester.getRect(
          find.descendant(
            of: find.byType(AppCustomScrollView),
            matching: find.byType(Scrollable),
          ),
        );
        expect(detailBar.top, 0);
        expect(detailBar.height, 80);
        expect(body.top, 80);
        expect(body.bottom, 566);
        expect(menuList.top, 80);
        expect(menuList.bottom, 600);
        if (direction == TextDirection.rtl) {
          expect(detailBar.left, 0);
          expect(body.left, 48);
          expect(body.right, detailBar.right);
          expect(menuList.right, rail.left);
        } else {
          expect(detailBar.right, 1200);
          expect(body.right, 1168);
          expect(body.left, detailBar.left);
          expect(menuList.left, rail.right);
        }
        await _expectPixels(tester, [
          (Offset(detailBar.center.dx, 4), Colors.blue),
          (Offset(direction == TextDirection.rtl ? 4 : 1196, 4), Colors.blue),
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
