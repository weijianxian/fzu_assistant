import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_center_widgets.dart';

void main() {
  testWidgets(
    'seat guide paints full screen and protects its controls and image',
    (tester) async {
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
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppScaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLearningSeatGuide(context),
                child: const Text('Open guide'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open guide'));
      await tester.pumpAndSettle();
      final dialog = find.byType(Dialog);
      final scaffold = find.descendant(
        of: dialog,
        matching: find.byType(Scaffold),
      );
      final appBar = find.descendant(of: dialog, matching: find.byType(AppBar));
      final image = find.descendant(
        of: dialog,
        matching: find.byType(InteractiveViewer),
      );
      expect(tester.getRect(scaffold), const Rect.fromLTWH(0, 0, 1200, 600));
      expect(tester.getRect(appBar), const Rect.fromLTWH(0, 0, 1200, 80));
      expect(tester.getRect(image), const Rect.fromLTRB(48, 80, 1168, 566));
      expect(
        tester.getRect(find.byType(ModalBarrier).last),
        const Rect.fromLTWH(0, 0, 1200, 600),
      );
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
