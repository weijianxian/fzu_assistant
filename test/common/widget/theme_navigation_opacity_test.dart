import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/app_theme_background.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';
import 'package:image/image.dart' as image;

const _capture = ValueKey('navigation-wallpaper-frame');
const _body = ValueKey('navigation-page-body');
const _wallpaperColor = Color(0xff2585c5);
const _insets = EdgeInsets.fromLTRB(8, 24, 8, 24);

class _NavigationShell extends StatefulWidget {
  const _NavigationShell();

  @override
  State<_NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<_NavigationShell> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final rail = MediaQuery.orientationOf(context) == Orientation.landscape;
    void select(int index) => setState(() => selected = index);

    // Match HomeScreen's native controls and nested page scaffolds without
    // mounting its unrelated account, network, reminder and shortcut services.
    return AppScaffold.shell(
      navigationRail: rail
          ? NavigationRail(
              scrollable: true,
              groupAlignment: 0,
              selectedIndex: selected,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Schedule'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.build),
                  label: Text('Tools'),
                ),
              ],
            )
          : null,
      bottomNavigationBar: rail
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: select,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Schedule',
                ),
                NavigationDestination(icon: Icon(Icons.build), label: 'Tools'),
              ],
            ),
      body: const AppScaffold(body: SizedBox.expand(key: _body)),
    );
  }
}

Widget _app(ThemeData theme) => MaterialApp(
  theme: theme,
  themeAnimationDuration: Duration.zero,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(padding: _insets, viewPadding: _insets),
    child: RepaintBoundary(
      key: _capture,
      child: AppThemeBackground(child: child!),
    ),
  ),
  home: const _NavigationShell(),
);

void _viewport(WidgetTester tester, bool rail) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = rail ? const Size(840, 480) : const Size(360, 640);
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.imageCache
      ..clear()
      ..clearLiveImages();
  });
}

Finder _navigation(bool rail) =>
    find.byType(rail ? NavigationRail : NavigationBar);

Material _surface(WidgetTester tester, bool rail) => tester.widget<Material>(
  find.descendant(of: _navigation(rail), matching: find.byType(Material)).first,
);

Future<void> _mount(WidgetTester tester, ThemeData theme) async {
  // FileImage must start I/O in the real async zone rather than leave the
  // initial codec future suspended in the widget test's fake clock.
  await tester.runAsync(() => tester.pumpWidget(_app(theme)));
  if (theme.extension<ThemeVisuals>()?.hasBackground == true) {
    final finder = find.byType(Image);
    expect(finder, findsWidgets);
    // Route transitions also own a wallpaper so page snapshots are complete.
    // Wait for every rendered image, without fixing the number of layers.
    for (final element in finder.evaluate()) {
      final widget = element.widget as Image;
      final configuration = createLocalImageConfiguration(element);
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
          await ready.future.timeout(const Duration(seconds: 5));
        } finally {
          stream.removeListener(listener);
        }
      });
    }
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

class _Frame {
  const _Frame(this.width, this.bytes);

  final int width;
  final Uint8List bytes;

  Color pixel(Offset point) {
    final index = (point.dy.floor() * width + point.dx.floor()) * 4;
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
      final bytes = (await picture.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      return _Frame(
        picture.width,
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      picture.dispose();
    }
  }))!;
}

void _expectPixel(Color actual, Color expected, String reason) {
  for (final shift in [0, 8, 16, 24]) {
    expect(
      (actual.toARGB32() >> shift) & 0xff,
      closeTo((expected.toARGB32() >> shift) & 0xff, 2),
      reason: reason,
    );
  }
}

Map<String, Color> _colors(Brightness brightness) =>
    brightness == Brightness.light
    ? const {
        'surface': Color(0xffffe9cf),
        'surfaceContainer': Color(0xffd5e8d9),
        'surfaceTint': Color(0xffff00ff),
      }
    : const {
        'surface': Color(0xff24162e),
        'surfaceContainer': Color(0xff183b31),
        'surfaceTint': Colors.cyan,
      };

void main() {
  late Directory directory;
  late File wallpaper;

  setUpAll(() {
    directory = Directory.systemTemp.createTempSync('fzu-navigation-opacity-');
    final source = image.Image(width: 4, height: 4);
    image.fill(source, color: image.ColorRgb8(0x25, 0x85, 0xc5));
    wallpaper = File('${directory.path}/wallpaper.png')
      ..writeAsBytesSync(image.encodePng(source));
  });

  tearDownAll(() {
    wallpaper.deleteSync();
    directory.deleteSync();
  });

  for (final rail in [false, true]) {
    final control = rail ? 'landscape rail' : 'bottom bar';
    for (final brightness in Brightness.values) {
      testWidgets(
        '$control paints wallpaper panel opacity and live updates: $brightness',
        (tester) async {
          _viewport(tester, rail);
          final colors = _colors(brightness);
          final dim = brightness == Brightness.light ? 0.2 : 0.55;
          final background = Color.alphaBlend(
            Colors.black.withValues(alpha: dim),
            _wallpaperColor,
          );
          final role = rail ? 'surface' : 'surfaceContainer';

          // Non-monotonic updates catch stale theme values as well as both
          // endpoints. A nontransparent custom tint exposes elevation overlays.
          for (final opacity in [0.5, 0.0, 1.0, 0.3]) {
            final theme = buildTheme(
              Colors.deepPurple,
              brightness: brightness,
              visuals: ThemeVisuals(
                colors: colors,
                backgroundImage: wallpaper.path,
                backgroundDim: dim,
                surfaceOpacity: opacity,
              ),
            );
            await _mount(tester, theme);

            final material = _surface(tester, rail);
            final panel = colors[role]!.withValues(alpha: opacity);
            expect(material.color, panel, reason: '$role at opacity=$opacity');
            expect(material.elevation, 0);
            final frame = await _frame(tester);
            final rect = tester.getRect(_navigation(rail));
            final expected = Color.alphaBlend(panel, background);
            _expectPixel(
              frame.pixel(rect.topLeft + const Offset(2, 2)),
              expected,
              '$control panel must blend with the real PNG at opacity=$opacity',
            );
            _expectPixel(
              frame.pixel(rect.bottomLeft + const Offset(2, -2)),
              expected,
              '$control system-edge surface must use the same opacity',
            );
            _expectPixel(
              frame.pixel(tester.getCenter(find.byKey(_body))),
              background,
              'nested scaffolds must leave the dimmed wallpaper visible',
            );
          }
        },
      );

      testWidgets(
        '$control restores native Material 3 without wallpaper: $brightness',
        (tester) async {
          _viewport(tester, rail);
          final preset = buildTheme(Colors.teal, brightness: brightness);
          final customWithoutImage = buildTheme(
            Colors.teal,
            brightness: brightness,
            visuals: ThemeVisuals(
              colors: _colors(brightness),
              surfaceOpacity: 0,
            ),
          );

          for (final theme in [preset, customWithoutImage]) {
            // Obtain defaults from the installed SDK's real control, including
            // elevation and tint, instead of freezing a copy of SDK defaults.
            await _mount(
              tester,
              ThemeData(
                useMaterial3: true,
                brightness: brightness,
                colorScheme: theme.colorScheme,
              ),
            );
            final native = _surface(tester, rail);
            final nativeSize = tester.getSize(_navigation(rail));

            // Removing a previously transparent wallpaper theme must restore
            // native chrome rather than leaving a stale navigation override.
            await _mount(
              tester,
              buildTheme(
                Colors.teal,
                brightness: brightness,
                visuals: ThemeVisuals(
                  backgroundImage: wallpaper.path,
                  surfaceOpacity: 0,
                ),
              ),
            );
            await _mount(tester, theme);

            final actual = _surface(tester, rail);
            expect(actual.color, native.color);
            expect(actual.color!.a, 1);
            expect(actual.elevation, native.elevation);
            expect(actual.surfaceTintColor, native.surfaceTintColor);
            expect(actual.shadowColor, native.shadowColor);
            expect(tester.getSize(_navigation(rail)), nativeSize);
            expect(find.byType(Image), findsNothing);
            final frame = await _frame(tester);
            final rect = tester.getRect(_navigation(rail));
            _expectPixel(
              frame.pixel(rect.bottomLeft + const Offset(2, -2)),
              native.color!,
              'without wallpaper the navigation surface remains opaque',
            );
            _expectPixel(
              frame.pixel(tester.getCenter(find.byKey(_body))),
              theme.colorScheme.surface,
              'preset page background remains the native surface',
            );
            await tester.tap(find.text('Tools').last);
            await tester.pumpAndSettle();
            expect(
              rail
                  ? tester
                        .widget<NavigationRail>(_navigation(rail))
                        .selectedIndex
                  : tester
                        .widget<NavigationBar>(_navigation(rail))
                        .selectedIndex,
              1,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
