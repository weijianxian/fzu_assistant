import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/desktop_window_frame.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/desktop_window.dart';
import 'package:window_manager/window_manager.dart';

class _CloseRequest extends Fake implements EventRequest {
  bool cancelled = false;

  @override
  bool cancel() => cancelled = true;
}

class _Window extends Fake implements Window {
  final calls = <String>[];
  FutureOr<void> Function(WindowEvent)? listener;
  final closeRequest = _CloseRequest();

  @override
  bool isFocused = true;
  @override
  bool isMaximized = false;
  @override
  bool isFullScreen = false;

  @override
  ListenerId addListener(FutureOr<void> Function(WindowEvent) callback) {
    listener = callback;
    return 1;
  }

  @override
  bool removeListener(ListenerId listenerId) {
    listener = null;
    return true;
  }

  @override
  void minimize() => calls.add('minimize');

  @override
  void maximize() {
    calls.add('maximize');
    isMaximized = true;
    listener?.call(const WindowMaximizedEvent(windowId: 1));
  }

  @override
  void unmaximize() {
    calls.add('unmaximize');
    isMaximized = false;
    listener?.call(const WindowRestoredEvent(windowId: 1));
  }

  @override
  bool close() {
    listener?.call(
      WindowCloseRequestedEvent(windowId: 1, request: closeRequest),
    );
    return !closeRequest.cancelled;
  }
}

Widget _app({
  required DesktopWindow window,
  GlobalKey<NavigatorState>? navigatorKey,
  Widget? home,
}) => MaterialApp(
  navigatorKey: navigatorKey,
  theme: buildTheme(Colors.deepPurple),
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) =>
      DesktopWindowFrame(window: window, child: child!),
  home: home ?? const Scaffold(body: Text('Content')),
);

Future<List<int>> _sampleFrame(WidgetTester tester, GlobalKey key) async {
  return (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      return [
        pixels.getUint32((35 * image.width + 400) * 4),
        pixels.getUint32((50 * image.width + 400) * 4),
      ];
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);
  const channel = MethodChannel('window_control');
  final calls = <MethodCall>[];
  late _Window nativeWindow;
  late DesktopWindow window;

  setUp(() {
    nativeWindow = _Window();
    window = DesktopWindow.forTesting(nativeWindow);
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    window.dispose();
    expect(nativeWindow.listener, isNull);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('caption tooltip can appear outside the route navigator', (
    tester,
  ) async {
    await tester.pumpWidget(_app(window: window));
    expect(tester.takeException(), isNull);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byTooltip('最小化')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('最小化'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('route transition painting stays below the title bar', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: _app(window: window, navigatorKey: navigatorKey),
      ),
    );
    await tester.pumpAndSettle();
    final before = await _sampleFrame(tester, boundaryKey);

    navigatorKey.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(seconds: 1),
        pageBuilder: (_, _, _) => const ColoredBox(color: Colors.red),
        transitionsBuilder: (_, animation, _, child) => Transform.translate(
          offset: Offset(0, -16 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final during = await _sampleFrame(tester, boundaryKey);

    expect(during[0], before[0], reason: '标题栏不能被页面过渡覆盖');
    expect(during[1], isNot(before[1]), reason: '确认采样时页面已经开始绘制');
    expect(find.byTooltip('关闭窗口'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  }, variant: windows);

  testWidgets(
    'caption buttons follow native maximize state and call window controls',
    (tester) async {
      await tester.pumpWidget(_app(window: window));
      await tester.tap(find.byTooltip('最小化'));
      await tester.pump();
      expect(nativeWindow.calls, contains('minimize'));

      await tester.tap(find.byTooltip('最大化'));
      await tester.pump();
      expect(nativeWindow.calls, contains('maximize'));

      expect(find.byTooltip('还原窗口'), findsOneWidget);
      await tester.tap(find.byTooltip('还原窗口'));
      await tester.pump();
      expect(nativeWindow.calls, contains('unmaximize'));
      expect(find.byTooltip('最大化'), findsOneWidget);

      await tester.tap(find.byTooltip('关闭窗口'));
      await tester.pump();
      expect(nativeWindow.closeRequest.cancelled, isTrue);
      expect(calls.single.method, 'closeWindow');
      expect(tester.takeException(), isNull);
    },
    variant: windows,
  );

  testWidgets('other platforms keep the original page without a title bar', (
    tester,
  ) async {
    await tester.pumpWidget(_app(window: window));
    expect(find.text('Content'), findsOneWidget);
    expect(find.byTooltip('关闭窗口'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
