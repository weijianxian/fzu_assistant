import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widgets.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('展开与收起在 $brightness 下均不绘制主题边框', (tester) async {
      const capture = ValueKey('capture');
      final changes = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            dividerColor: const Color(0xffff00ff),
            expansionTileTheme: const ExpansionTileThemeData(
              shape: Border(
                top: BorderSide(color: Color(0xffff00ff), width: 3),
                bottom: BorderSide(color: Color(0xffff00ff), width: 3),
              ),
            ),
          ),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: capture,
                child: SizedBox(
                  width: 320,
                  child: AppExpansionTile(
                    title: const Text('Details'),
                    onExpansionChanged: changes.add,
                    children: const [Text('Expanded content')],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var state = 0; state < 3; state++) {
        if (state != 0) {
          await tester.tap(find.text('Details'));
          await tester.pumpAndSettle();
        }
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        final borderPixels = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final bytes = data!.buffer.asUint8List();
          var count = 0;
          for (var i = 0; i < bytes.length; i += 4) {
            if (bytes[i] == 255 && bytes[i + 1] == 0 && bytes[i + 2] == 255) {
              count++;
            }
          }
          image.dispose();
          return count;
        });
        expect(borderPixels, 0);
      }
      expect(changes, [true, false]);
    });
  }
  testWidgets('共享包装保留 PageStorage 的展开状态', (tester) async {
    final bucket = PageStorageBucket();
    Widget app(bool show) => MaterialApp(
      home: Scaffold(
        body: PageStorage(
          bucket: bucket,
          child: show
              ? const AppExpansionTile(
                  key: PageStorageKey('details'),
                  title: Text('Details'),
                  children: [Text('Expanded content')],
                )
              : const SizedBox(),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Expanded content'), findsOneWidget);
    await tester.pumpWidget(app(false));
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(find.text('Expanded content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
