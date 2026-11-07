import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a lazy row before revealing it for an interaction or layout check.
Future<void> revealWidget(WidgetTester tester, Finder finder) async {
  final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
  if (finder.evaluate().isEmpty) {
    scroll.position.jumpTo(scroll.position.minScrollExtent);
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 30 && finder.evaluate().isEmpty;
      attempt++
    ) {
      final position = scroll.position;
      position.jumpTo(
        (position.pixels + 200).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await tester.pumpAndSettle();
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}
