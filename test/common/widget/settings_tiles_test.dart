import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/chevron_list_tile.dart';
import 'package:fzu_assistant/common/widget/setting_switch_tile.dart';

void main() {
  testWidgets('SettingSwitchTile writes changes back to notifier', (
    tester,
  ) async {
    final notifier = ValueNotifier(false);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingSwitchTile(
            notifier: notifier,
            title: const Text('Enable feature'),
          ),
        ),
      ),
    );

    expect(notifier.value, isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(notifier.value, isTrue);
  });

  testWidgets('ChevronListTile renders trailing chevron and handles tap', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChevronListTile(
            title: const Text('Details'),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Details'));

    expect(tapped, isTrue);
  });
}
