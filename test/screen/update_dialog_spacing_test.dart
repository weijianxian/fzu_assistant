import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/github_release.dart';
import 'package:fzu_assistant/screen/my/about/widgets/update_dialog.dart';

void main() {
  for (final (landscape, keyboard) in [
    (true, 0.0),
    (false, 0.0),
    (false, 200.0),
  ]) {
    testWidgets(
      'update sheet shares bottom insets with its fixed action in ${landscape ? 'landscape' : 'portrait'} keyboard=$keyboard',
      (tester) async {
        final size = landscape ? const Size(1200, 600) : const Size(400, 800);
        final padding = landscape
            ? const FakeViewPadding(left: 48, top: 24, right: 32, bottom: 34)
            : const FakeViewPadding(left: 16, top: 24, right: 12, bottom: 34);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = FakeViewPadding(
          left: padding.left,
          top: padding.top,
          right: padding.right,
          bottom: keyboard == 0 ? padding.bottom : 0,
        );
        tester.view.viewPadding = padding;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.reset);
        final release = GitHubRelease(
          tagName: 'v99.0.0',
          version: '99.0.0',
          body: List.generate(30, (i) => '- Release note ${i + 1}').join('\n'),
          htmlUrl: 'https://example.invalid/release',
          publishedAt: '2026-11-03T00:00:00Z',
          prerelease: false,
          assets: const [],
        );
        var skips = 0;
        var permanentSkips = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showUpdateSheet(
                    context,
                    release: release,
                    onSkip: () => skips++,
                    onSkipForever: () => permanentSkips++,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final list = find.byType(ListView);
        final footer = tester.getRect(find.byType(AppBottomBar));
        final listBounds = tester.getRect(list);
        final nativeList = tester.widget<ListView>(list);
        final button = tester.getRect(find.byType(FilledButton));
        expect(footer.bottom, size.height - keyboard);
        expect(listBounds.bottom, footer.top);
        expect(nativeList.padding!.resolve(TextDirection.ltr).bottom, 8);
        expect(
          button.bottom,
          size.height - keyboard - (keyboard == 0 ? padding.bottom : 0) - 8,
        );
        expect(button.top, greaterThanOrEqualTo(footer.top));
        expect(button.left, greaterThanOrEqualTo(padding.left));
        expect(button.right, lessThanOrEqualTo(size.width - padding.right));
        final scroll = tester.state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        );
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        for (final label in ['跳过此版本', '永久跳过', '在浏览器中打开']) {
          final action = tester.getRect(find.text(label));
          expect(
            action.top,
            greaterThanOrEqualTo(listBounds.top),
            reason: label,
          );
          expect(
            action.bottom,
            lessThanOrEqualTo(listBounds.bottom),
            reason: label,
          );
        }
        expect(tester.getRect(find.byType(FilledButton)), button);
        expect(skips, 0);
        expect(permanentSkips, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
