import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/screen/toolbox/paper/paper_file_actions.dart';

void main() {
  test('opening preserves platform success and failure results', () async {
    for (final result in [true, false]) {
      String? requested;
      expect(
        await openPaperFile(
          '/papers/数学.pdf',
          open: (path) async {
            requested = path;
            return result;
          },
        ),
        result,
      );
      expect(requested, '/papers/数学.pdf');
    }
  });

  test(
    'platform exceptions leave file actions available for fallback',
    () async {
      expect(
        await openPaperFile(
          '/papers/数学.pdf',
          open: (_) async => throw StateError('no associated application'),
        ),
        isFalse,
      );
    },
  );

  test('synchronous platform exceptions also allow fallback', () async {
    expect(
      await openPaperFile(
        '/papers/数学.pdf',
        open: (_) => throw StateError('no associated application'),
      ),
      isFalse,
    );
  });

  test(
    'a missing native callback times out and late completion is harmless',
    () async {
      final nativeResult = Completer<bool>();
      expect(
        await openPaperFile(
          '/papers/数学.pdf',
          timeout: Duration.zero,
          open: (_) => nativeResult.future,
        ),
        isFalse,
      );
      nativeResult.complete(true);
      await nativeResult.future;
    },
  );

  test('a native error after timeout is still handled', () async {
    final nativeResult = Completer<bool>();
    expect(
      await openPaperFile(
        '/papers/数学.pdf',
        timeout: Duration.zero,
        open: (_) => nativeResult.future,
      ),
      isFalse,
    );
    nativeResult.completeError(StateError('late platform failure'));
    await Future<void>.delayed(Duration.zero);
  });
}
