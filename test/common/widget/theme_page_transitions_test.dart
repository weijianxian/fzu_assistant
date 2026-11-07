import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/app_theme_background.dart';
import 'package:fzu_assistant/common/widget/layout/theme_page_transitions.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';
import 'package:image/image.dart' as image;

const _size = Size(320, 480);
const _capture = ValueKey('wallpaper-frame');
const _firstPage = ValueKey('first-page');
const _secondPage = ValueKey('second-page');
const _left = Color(0xffcc2244);
const _right = Color(0xff1155bb);
const _codec = StandardMethodCodec();

class _Frame {
  const _Frame(this.width, this.height, this.bytes);
  final int width, height;
  final Uint8List bytes;

  Color pixel(int x, int y) {
    final index = (y * width + x) * 4;
    return Color.fromARGB(
      bytes[index + 3],
      bytes[index],
      bytes[index + 1],
      bytes[index + 2],
    );
  }
}

Future<_Frame> _frame(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  return (await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await picture.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      return _Frame(
        picture.width,
        picture.height,
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      picture.dispose();
    }
  }))!;
}

void _expectWallpaper(_Frame frame, String phase) {
  // Both halves of the real PNG have G <= 85. Fades between the two photos and
  // native shadows can only keep or lower this bound. A white surface scrim,
  // even briefly, increases G and is detected across the viewport.
  for (var y = 12; y < frame.height - 12; y += 24) {
    for (var x = 12; x < frame.width - 12; x += 24) {
      final argb = frame.pixel(x, y).toARGB32();
      expect(
        (argb >> 8) & 0xff,
        lessThanOrEqualTo(100),
        reason:
            '$phase: surface flash at ($x, $y), '
            '#${argb.toRadixString(16).padLeft(8, '0')}',
      );
      expect(
        argb >> 24,
        255,
        reason: '$phase: wallpaper left a transparent gap',
      );
    }
  }
}

void _expectColor(Color actual, Color expected, String reason) {
  for (final shift in [0, 8, 16, 24]) {
    expect(
      (actual.toARGB32() >> shift) & 0xff,
      closeTo((expected.toARGB32() >> shift) & 0xff, 3),
      reason: reason,
    );
  }
}

Future<int> _transitionFrames(WidgetTester tester, String phase) async {
  for (var frame = 0; frame < 80; frame++) {
    await tester.pump(
      frame == 0 ? Duration.zero : const Duration(milliseconds: 16),
    );
    _expectWallpaper(await _frame(tester), '$phase frame $frame');
    if (frame > 0 && !tester.binding.hasScheduledFrame) return frame + 1;
  }
  fail('$phase did not settle within 80 animation frames');
}

Future<void> _firstDecode(WidgetTester tester) async {
  final finder = find.byType(Image).first;
  final widget = tester.widget<Image>(finder);
  final configuration = createLocalImageConfiguration(tester.element(finder));
  await tester.runAsync(() async {
    final ready = Completer<void>();
    final stream = widget.image.resolve(configuration);
    final listener = ImageStreamListener(
      (info, _) {
        info.dispose();
        if (!ready.isCompleted) ready.complete();
      },
      onError: (Object error, StackTrace? stack) {
        if (!ready.isCompleted) ready.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    try {
      await ready.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('The wallpaper did not decode'),
      );
    } finally {
      stream.removeListener(listener);
    }
  });
  await tester.pumpAndSettle();
  final firstFrame = await _frame(tester);
  _expectColor(
    firstFrame.pixel(80, 240),
    _left,
    'cold image decode paints the actual left half',
  );
  _expectColor(
    firstFrame.pixel(240, 240),
    _right,
    'cold image decode paints the actual right half',
  );
}

class _Scene {
  final root = GlobalKey<NavigatorState>();
  final nested = GlobalKey<NavigatorState>();

  Future<void> mount(
    WidgetTester tester,
    File wallpaper, {
    bool withNestedNavigator = false,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = _size;
    addTearDown(tester.view.reset);
    final theme = buildThemeFromScheme(
      ColorScheme.fromSeed(seedColor: Colors.teal)
          .copyWith(surface: Colors.white),
      visuals: ThemeVisuals(backgroundImage: wallpaper.path),
    );
    // FileImage starts asynchronous I/O while mounting. Start that work in the
    // real async zone too, so its continuation is not stranded in FakeAsync
    // while _firstDecode waits for the codec.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: root,
          theme: theme,
          builder: (context, child) => RepaintBoundary(
            key: _capture,
            child: AppThemeBackground(child: child!),
          ),
          home: withNestedNavigator
              ? Navigator(
                  key: nested,
                  onGenerateRoute: (settings) => MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => const AppScaffold(
                      body: SizedBox.expand(key: _firstPage),
                    ),
                  ),
                )
              : const AppScaffold(body: SizedBox.expand(key: _firstPage)),
        ),
      );
    });
    await _firstDecode(tester);
  }

  void push({bool intoNested = false}) {
    unawaited(
      (intoNested ? nested : root).currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              const AppScaffold(body: SizedBox.expand(key: _secondPage)),
        ),
      ),
    );
  }
}

Future<void> _gesture(
  WidgetTester tester,
  String method, {
  double? progress,
}) async {
  final message = _codec.encodeMethodCall(
    MethodCall(
      method,
      progress == null
          ? null
          : {
              'touchOffset': <double>[5 + 200 * progress, 240],
              'progress': progress,
              'swipeEdge': 0,
            },
    ),
  );
  ByteData? response;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (value) => response = value,
  );
  if (method == 'startBackGesture') {
    expect(
      _codec.decodeEnvelope(response!),
      isTrue,
      reason: 'the channel must start a real predictive gesture',
    );
  }
  await tester.pump();
}

Future<void> _expectWallpaperFollowsPage(WidgetTester tester) async {
  final page = tester.renderObject<RenderBox>(find.byKey(_secondPage));
  final rect = Rect.fromPoints(
    page.localToGlobal(Offset.zero),
    page.localToGlobal(Offset(page.size.width, page.size.height)),
  );
  expect(rect.width, lessThan(_size.width - 4));
  expect(rect.left, greaterThan(0));
  // At 25% progress the native transition has only shifted the center ~2px.
  // One whole pixel still separates the global and moving image splits.
  expect(rect.center.dx, greaterThan(_size.width / 2 + 1));

  final frame = await _frame(tester);
  final x = ((_size.width / 2 + rect.center.dx) / 2).floor();
  final y = rect.center.dy.floor();
  // This is to the right of the global photo's split, but to the left of the
  // moving route's split. A wallpaper only outside Navigator would be blue.
  _expectColor(
    frame.pixel(x, y),
    _left,
    'wallpaper must move with the shrinking route, not stay behind Navigator',
  );
  _expectColor(
    frame.pixel((rect.center.dx + 5).ceil(), y),
    _right,
    'the moving route retains both halves of the image',
  );
}

Widget? _delegatedProbe(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  bool allowSnapshotting,
  Widget? child,
) => child;

class _DelegateProbe extends PageTransitionsBuilder {
  const _DelegateProbe({this.onBuild});

  final ValueChanged<Widget>? onBuild;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 437);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 283);

  @override
  DelegatedTransitionBuilder get delegatedTransition => _delegatedProbe;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    onBuild?.call(child);
    return child;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File wallpaper;

  setUp(() {
    directory = Directory.systemTemp.createTempSync(
      'fzu-wallpaper-transition-',
    );
    final pattern = image.Image(width: 320, height: 480, numChannels: 4)
      ..clear(image.ColorRgba8(0xcc, 0x22, 0x44, 255));
    image.fillRect(
      pattern,
      x1: 160,
      y1: 0,
      x2: 319,
      y2: 479,
      color: image.ColorRgba8(0x11, 0x55, 0xbb, 255),
    );
    wallpaper = File('${directory.path}/two-color.png')
      ..writeAsBytesSync(image.encodePng(pattern));
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    directory.deleteSync(recursive: true);
  });

  test('wrapper preserves delegate timing and secondary transition', () {
    const delegate = _DelegateProbe();
    final wrapper = ThemeBackgroundPageTransitionsBuilder(delegate: delegate);
    expect(wrapper.transitionDuration, delegate.transitionDuration);
    expect(
      wrapper.reverseTransitionDuration,
      delegate.reverseTransitionDuration,
    );
    expect(wrapper.delegatedTransition, same(delegate.delegatedTransition));
  });

  test('without wallpaper the default native builders are preserved', () {
    const defaults = PageTransitionsTheme();
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    for (final visuals in [null, const ThemeVisuals(backgroundDim: 0.5)]) {
      final theme = buildThemeFromScheme(scheme, visuals: visuals);
      expect(
        theme.pageTransitionsTheme.builders.keys,
        unorderedEquals(defaults.builders.keys),
      );
      for (final entry in defaults.builders.entries) {
        final builder = theme.pageTransitionsTheme.builders[entry.key]!;
        expect(builder, isNot(isA<ThemeBackgroundPageTransitionsBuilder>()));
        expect(builder.runtimeType, entry.value.runtimeType);
        expect(builder.transitionDuration, entry.value.transitionDuration);
        expect(
          builder.reverseTransitionDuration,
          entry.value.reverseTransitionDuration,
        );
      }
    }
  });

  testWidgets('wrapper passes the identical child through without wallpaper', (
    tester,
  ) async {
    const child = SizedBox.expand();
    Widget? delegatedChild;
    final route = MaterialPageRoute<void>(builder: (_) => child);
    addTearDown(route.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildThemeFromScheme(
          ColorScheme.fromSeed(seedColor: Colors.teal),
          visuals: const ThemeVisuals(backgroundDim: 0.5),
        ),
        home: Builder(
          builder: (context) =>
              ThemeBackgroundPageTransitionsBuilder(
                delegate: _DelegateProbe(
                  onBuild: (child) => delegatedChild = child,
                ),
              ).buildTransitions<void>(
                route,
                context,
                kAlwaysCompleteAnimation,
                kAlwaysDismissedAnimation,
                child,
              ),
        ),
      ),
    );
    expect(delegatedChild, same(child));
    expect(find.byType(AppThemeBackground), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.fuchsia,
  ]) {
    testWidgets('$platform push/pop never inserts a white surface frame', (
      tester,
    ) async {
      expect(PaintingBinding.instance.imageCache.currentSize, 0);
      final scene = _Scene();
      await scene.mount(tester, wallpaper);
      scene.push();
      final pushFrames = await _transitionFrames(tester, '$platform push');
      expect(pushFrames, greaterThan(3));
      expect(find.byKey(_secondPage), findsOneWidget);
      // All route backgrounds use the same decoded ResizeImage/FileImage key.
      expect(PaintingBinding.instance.imageCache.currentSize, 1);
      scene.root.currentState!.pop();
      final popFrames = await _transitionFrames(tester, '$platform pop');
      expect(popFrames, greaterThan(3));
      expect(find.byKey(_secondPage), findsNothing);
      expect(find.byKey(_firstPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(platform));
  }

  for (final nested in [false, true]) {
    for (final completion in ['cancelBackGesture', 'commitBackGesture']) {
      testWidgets(
        '${nested ? 'nested' : 'root'} predictive back keeps the photo inside '
        'the moving route: $completion',
        (tester) async {
          final scene = _Scene();
          await scene.mount(tester, wallpaper, withNestedNavigator: nested);
          scene.push(intoNested: nested);
          await _transitionFrames(tester, 'before predictive back');
          await _gesture(tester, 'startBackGesture', progress: 0);
          _expectWallpaper(await _frame(tester), 'predictive start');
          for (final progress in [0.25, 0.55, 0.85]) {
            await _gesture(
              tester,
              'updateBackGestureProgress',
              progress: progress,
            );
            _expectWallpaper(
              await _frame(tester),
              'predictive progress $progress',
            );
            // Check at each update, not just the final gesture position.
            await _expectWallpaperFollowsPage(tester);
          }
          await _gesture(tester, completion);
          await _transitionFrames(tester, completion);
          expect(
            find.byKey(_secondPage),
            completion == 'cancelBackGesture' ? findsOneWidget : findsNothing,
          );
          if (completion == 'commitBackGesture') {
            expect(find.byKey(_firstPage), findsOneWidget);
          }
          if (nested) {
            expect(scene.root.currentState!.canPop(), isFalse);
            expect(
              scene.nested.currentState!.canPop(),
              completion == 'cancelBackGesture',
            );
          }
          expect(PaintingBinding.instance.imageCache.currentSize, 1);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets('nested Navigator push/pop shares the real decoded wallpaper', (
    tester,
  ) async {
    final scene = _Scene();
    await scene.mount(tester, wallpaper, withNestedNavigator: true);
    scene.push(intoNested: true);
    await _transitionFrames(tester, 'nested push');
    expect(scene.root.currentState!.canPop(), isFalse);
    expect(scene.nested.currentState!.canPop(), isTrue);
    expect(find.byKey(_secondPage), findsOneWidget);
    scene.nested.currentState!.pop();
    await _transitionFrames(tester, 'nested pop');
    expect(find.byKey(_secondPage), findsNothing);
    expect(find.byKey(_firstPage), findsOneWidget);
    expect(PaintingBinding.instance.imageCache.currentSize, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
