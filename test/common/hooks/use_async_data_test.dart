import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';

void main() {
  testWidgets('初次加载、刷新失败和恢复保留正确的数据及更新时间', (tester) async {
    final requests = List.generate(3, (_) => Completer<String>());
    var calls = 0;
    late AsyncData<String> result;
    await tester.pumpWidget(
      HookBuilder(
        builder: (_) {
          result = useAsyncData(() => requests[calls++].future);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(calls, 1);
    expect(result.loading, isTrue);
    expect(result.data, isNull);
    requests[0].complete('first');
    await tester.pumpAndSettle();
    final updatedAt = result.updatedAt;
    expect(result.data, 'first');
    expect(result.loading, isFalse);
    expect(updatedAt, isNotNull);

    final failed = result.refresh();
    await tester.pump();
    expect(result.data, 'first');
    expect(result.loading, isFalse);
    requests[1].completeError(StateError('offline'));
    await failed;
    await tester.pump();
    expect(result.data, 'first');
    expect(result.updatedAt, updatedAt);
    expect(result.error, contains('offline'));

    final recovered = result.refresh();
    requests[2].complete('recovered');
    await recovered;
    await tester.pump();
    expect(result.data, 'recovered');
    expect(result.error, isNull);
    expect(calls, 3); // 重建不会再次自动请求。
  });

  testWidgets('旧请求失败不覆盖最新结果或触发成功回调', (tester) async {
    final first = Completer<String>();
    final second = Completer<String>();
    var calls = 0;
    final loaded = <String>[];
    late AsyncData<String> result;
    await tester.pumpWidget(
      HookBuilder(
        builder: (_) {
          result = useAsyncData(
            () => calls++ == 0 ? first.future : second.future,
            onLoaded: loaded.add,
          );
          return const SizedBox.shrink();
        },
      ),
    );
    final latest = result.refresh();
    second.complete('latest');
    await latest;
    await tester.pump();
    first.completeError(StateError('stale'));
    await tester.pump();
    expect(result.data, 'latest');
    expect(result.error, isNull);
    expect(result.loading, isFalse);
    expect(loaded, ['latest']);
  });

  for (final fails in [false, true]) {
    testWidgets('页面卸载后查询结束不更新状态（失败=$fails）', (tester) async {
      final request = Completer<String>();
      var loaded = false;
      await tester.pumpWidget(
        HookBuilder(
          builder: (_) {
            useAsyncData(() => request.future, onLoaded: (_) => loaded = true);
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      if (fails) {
        request.completeError(StateError('offline'));
      } else {
        request.complete('late');
      }
      await tester.pump();
      expect(loaded, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
