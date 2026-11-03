import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_top_banner.dart';

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(
      left: 40,
      top: 48,
      right: 12,
      bottom: 34,
    );
    tester.view.viewPadding = tester.view.padding;
    addTearDown(tester.view.reset);
  }

  testWidgets('native banner surface covers the status bar using its theme', (
    tester,
  ) async {
    viewport(tester, const Size(600, 800));
    const bannerColor = Color(0xFF765432);
    const contentKey = Key('banner-content');
    const actionKey = Key('banner-action');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          bannerTheme: const MaterialBannerThemeData(
            backgroundColor: bannerColor,
          ),
        ),
        home: Scaffold(
          body: AppTopBanner(
            content: const Text(
              'A cached session is being displayed.',
              key: contentKey,
            ),
            actions: [
              TextButton(
                key: actionKey,
                onPressed: () {},
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final material = find
        .ancestor(of: find.byKey(contentKey), matching: find.byType(Material))
        .first;
    expect(tester.widget<Material>(material).color, bannerColor);
    final surface = tester.getRect(material);
    expect(surface.top, 0);
    expect(surface.left, 0);
    expect(surface.right, 600);
    expect(
      tester.getRect(find.byKey(contentKey)).top,
      greaterThanOrEqualTo(48),
    );
    expect(tester.getRect(find.byKey(actionKey)).top, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    for (final multipleActions in [false, true]) {
      testWidgets(
        'banner respects asymmetric system edges in $direction with multi=$multipleActions',
        (tester) async {
          viewport(tester, const Size(400, 800));
          const contentKey = Key('banner-content');
          const actionKeys = [Key('retry-action'), Key('dismiss-action')];
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: AppTopBanner(
                    content: const Text(
                      'A long message explaining that historical cached data is being displayed while the academic server cannot be reached.',
                      key: contentKey,
                    ),
                    actions: [
                      TextButton(
                        key: actionKeys[0],
                        onPressed: () {},
                        child: const Text('Retry'),
                      ),
                      if (multipleActions)
                        TextButton(
                          key: actionKeys[1],
                          onPressed: () {},
                          child: const Text('Dismiss'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final key in [
            contentKey,
            actionKeys[0],
            if (multipleActions) actionKeys[1],
          ]) {
            final rect = tester.getRect(find.byKey(key));
            expect(rect.top, greaterThanOrEqualTo(48));
            expect(rect.left, greaterThanOrEqualTo(40));
            expect(rect.right, lessThanOrEqualTo(388));
          }
          final padding = tester
              .widget<MaterialBanner>(find.byType(MaterialBanner))
              .padding!
              .resolve(direction);
          expect(padding.top, multipleActions ? 72 : 50);
          expect(
            padding.left,
            40 + (direction == TextDirection.ltr || multipleActions ? 16 : 0),
          );
          expect(
            padding.right,
            12 + (direction == TextDirection.rtl || multipleActions ? 16 : 0),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('banner preserves directional padding from its theme', (
    tester,
  ) async {
    viewport(tester, const Size(600, 800));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          bannerTheme: const MaterialBannerThemeData(
            padding: EdgeInsetsDirectional.fromSTEB(7, 9, 11, 13),
          ),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AppTopBanner(
              content: const Text('Content'),
              actions: [
                TextButton(onPressed: () {}, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final banner = tester.widget<MaterialBanner>(find.byType(MaterialBanner));
    expect(banner.padding, const EdgeInsets.fromLTRB(51, 57, 19, 13));
    expect(tester.takeException(), isNull);
  });
}
