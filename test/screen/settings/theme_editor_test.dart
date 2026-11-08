import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_theme_background.dart';
import 'package:fzu_assistant/common/widget/settings/settings_radio_tile.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/theme/theme_editor_page.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/course_color_palettes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/theme_customization_service.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';

const _picker = MethodChannel('plugins.flutter.io/file_selector');
const _dynamicColor = MethodChannel('io.material.plugins/dynamic_color');
const _name = ValueKey('theme-name');
const _save = ValueKey('theme-save');
const _preview = ValueKey('theme-editor-preview');
const _previewButton = ValueKey('theme-preview-button');
const _previewSheet = ValueKey('theme-preview-sheet');
const _previewClose = ValueKey('theme-preview-close');

Future<void> _capture(WidgetTester tester, String filename) async {
  const directory = String.fromEnvironment('THEME_EDITOR_CAPTURE_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final bitmap = await boundary.toImage(pixelRatio: 1);
    try {
      final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      await File('$directory/$filename')
          .writeAsBytes(png!.buffer.asUint8List());
    } finally {
      bitmap.dispose();
    }
  });
}

ThemeProfile _profile({ThemeVariant? light, ThemeVariant? dark}) =>
    ThemeProfile(
      id: 'editor-test',
      name: '原主题',
      light: light ?? ThemeVariant(colors: {'primary': 0xff123456}),
      dark: dark ?? ThemeVariant(colors: {'primary': 0xffabcdef}),
    );

Finder _listScroll() => find
    .descendant(
      of: find.byKey(const ValueKey('theme-editor-list')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final position = tester.state<ScrollableState>(_listScroll()).position;
    position.jumpTo(0);
    await tester.pump();
    // Move the list itself: the center of a narrow viewport can be over a
    // slider's horizontal recognizer rather than over the scrollable surface.
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      position.jumpTo(
        (position.pixels + 160).clamp(0, position.maxScrollExtent),
      );
      await tester.pump();
    }
  }
  expect(finder, findsOneWidget);
  final tile = find.ancestor(of: finder, matching: find.byType(ListTile));
  // A title Row can have empty space at its center. Scroll and hit-test the
  // native ListTile that owns that title and handles the whole row's taps.
  final target = tester.widget(finder) is Row && tile.evaluate().isNotEmpty
      ? tile.first
      : finder;
  for (var i = 0; i < 5; i++) {
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
    if (target.hitTestable().evaluate().isNotEmpty) return;
  }
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _sheetReveal(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<Finder> _expandSlider(
  WidgetTester tester,
  String id, {
  bool inSheet = false,
}) async {
  final row = find.byKey(ValueKey('theme-slider-row-$id'));
  final slider = find.byKey(ValueKey('theme-slider-$id'));
  final reveal = inSheet ? _sheetReveal : _reveal;
  await reveal(tester, row);
  if (slider.evaluate().isEmpty) {
    await tester.tap(
      find.ancestor(of: row, matching: find.byType(ListTile)).first,
    );
    await tester.pumpAndSettle();
  }
  await reveal(tester, slider);
  return slider;
}

Future<void> _setSlider(
  WidgetTester tester,
  String id,
  double value, {
  bool inSheet = false,
}) async {
  final slider = await _expandSlider(tester, id, inSheet: inSheet);
  final widget = tester.widget<Slider>(slider);
  final theme = SliderTheme.of(tester.element(slider));
  final overlay = theme.overlayShape ?? const RoundSliderOverlayShape();
  final padding =
      widget.padding ??
      theme.padding ??
      EdgeInsets.symmetric(
        horizontal: overlay.getPreferredSize(true, true).width / 2,
      );
  final track = padding
      .resolve(TextDirection.ltr)
      .deflateRect(tester.getRect(slider));
  // Tap the actual track, excluding the native thumb/overlay padding.
  await tester.tapAt(
    Offset(
      track.left +
          track.width * ((value - widget.min) / (widget.max - widget.min)),
      track.center.dy,
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.widget<Slider>(slider).value, closeTo(value, 0.000001));
}

Future<void> _mode(
  WidgetTester tester,
  AppLocalizations l10n,
  Brightness brightness,
) async {
  final segment = find.byKey(const ValueKey('theme-editor-mode'));
  await _reveal(tester, segment);
  await tester.tap(
    find.descendant(
      of: segment,
      matching: find.byIcon(
        brightness == Brightness.light
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _confirmPalette(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('theme-palette-confirm')));
  await tester.pump();
}

Future<void> _openPaletteColor(WidgetTester tester) async {
  final editor = find.byKey(const PageStorageKey('theme-course-palette-edit'));
  await _reveal(tester, editor);
  final color = find.byKey(const ValueKey('theme-course-palette-color-0'));
  if (color.evaluate().isEmpty) {
    final l10n = AppLocalizations.of(tester.element(editor))!;
    await tester.tap(
      find.descendant(
        of: editor,
        matching: find.text(l10n.themeCoursePaletteEdit),
      ),
    );
    await tester.pumpAndSettle();
  }
  await _reveal(tester, color);
  await tester.tap(color);
  await tester.pumpAndSettle();
}

Future<void> _selectBasePalette(WidgetTester tester, String key) async {
  final base = find.byKey(const ValueKey('theme-base-palette'));
  await _reveal(tester, base);
  await tester.tap(base);
  await tester.pumpAndSettle();
  final option = find.byWidgetPredicate(
    (widget) => widget is RadioListTile<String> && widget.value == key,
  );
  await _sheetReveal(tester, option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

Future<void> _finishWork(WidgetTester tester) async {
  // File I/O and the real palette isolate need real event-loop turns. Pump
  // separately so an indeterminate progress indicator cannot stall settling.
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (find.byType(ThemeEditorPage).evaluate().isEmpty ||
        tester.widget<FilledButton>(find.byKey(_save)).onPressed != null) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('The editor operation did not finish');
}

Future<AppLocalizations> _openEditor(
  WidgetTester tester,
  AppSettings settings,
  ThemeProfile profile, {
  Size size = const Size(400, 800),
  Locale locale = const Locale('zh'),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  const captureFont = String.fromEnvironment('THEME_EDITOR_CAPTURE_FONT');
  if (captureFont.isNotEmpty) {
    await tester.runAsync(() async {
      final loader = FontLoader('Roboto')
        ..addFont(
          File(captureFont)
              .readAsBytes()
              .then((bytes) => bytes.buffer.asByteData()),
        );
      await loader.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
  }
  await tester.pumpWidget(
    AppSettingsProvider(
      settings: settings,
      child: ValueListenableBuilder<ThemeProfile?>(
        valueListenable: settings.activeCustomTheme,
        builder: (_, _, _) => MaterialApp(
          theme: settings.lightTheme,
          darkTheme: settings.darkTheme,
          themeMode: ThemeMode.light,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open-editor'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ThemeEditorPage(profile: profile),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-editor')));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(ThemeEditorPage)))!;
}

ThemeVisuals _previewVisuals(WidgetTester tester) =>
    ThemeVisuals.of(tester.element(find.byKey(_preview)));

Future<void> _openPreview(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsNothing);
  expect(find.byKey(_previewSheet), findsNothing);
  expect(find.byKey(_preview, skipOffstage: false), findsNothing);
  final button = find.byKey(_previewButton);
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(find.byKey(_previewSheet), findsOneWidget);
  expect(find.byKey(_preview), findsOneWidget);
  final images = find.descendant(
    of: find.byKey(_preview),
    matching: find.byType(Image),
  );
  for (final element in images.evaluate()) {
    final provider = (element.widget as Image).image;
    var loaded = false;
    unawaited(precacheImage(provider, element).then((_) => loaded = true));
    for (var i = 0; i < 200 && !loaded; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(loaded, isTrue, reason: 'Wallpaper preview did not finish decoding');
  }
  await tester.pumpAndSettle();
}

Future<void> _closePreview(WidgetTester tester) async {
  final close = find.byKey(_previewClose);
  await _sheetReveal(tester, close);
  expect(close.hitTestable(), findsOneWidget);
  await tester.tap(close);
  await tester.pumpAndSettle();
  expect(find.byKey(_previewSheet, skipOffstage: false), findsNothing);
  expect(find.byKey(_preview, skipOffstage: false), findsNothing);
}

Future<void> _previewMode(WidgetTester tester, Brightness brightness) async {
  final segment = find.byKey(const ValueKey('theme-preview-mode'));
  await _sheetReveal(tester, segment);
  await tester.tap(
    find.descendant(
      of: segment,
      matching: find.byIcon(
        brightness == Brightness.light
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _checkPreview(
  WidgetTester tester,
  void Function(ThemeData theme, ThemeVisuals visuals) check,
) async {
  await _openPreview(tester);
  check(
    Theme.of(tester.element(find.byKey(_preview))),
    _previewVisuals(tester),
  );
  await _closePreview(tester);
}

File _png(Directory directory, String filename, int red, int blue) {
  final source = image.Image(width: 16, height: 16, numChannels: 4)
    ..clear(image.ColorRgba8(red, 0, blue, 255));
  return File('${directory.path}/$filename')
    ..writeAsBytesSync(image.encodePng(source));
}

class _FailOnceStore extends ThemeCustomizationService {
  _FailOnceStore(Directory directory) : super(directory: () async => directory);

  bool fail = true;

  @override
  Future<ThemeProfile> save(ThemeProfile profile) async {
    if (fail) {
      fail = false;
      throw const FileSystemException('test write failure');
    }
    return super.save(profile);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ThemeCustomizationService store;
  late AppSettings settings;

  setUp(() async {
    AppSettings.dynamicColorSupported = false;
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('fzu-theme-editor-');
    store = ThemeCustomizationService(
      directory: () async => Directory('${directory.path}/documents'),
    );
    settings = AppSettings(themeStore: store);
    await settings.initDynamicColor();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_picker, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_dynamicColor, null);
    AppSettings.dynamicColorSupported = false;
    settings.dispose();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'course palettes edit, preview and save each brightness separately',
    (tester) async {
      final original = _profile();
      settings.activateCustomTheme(original);
      final l10n = await _openEditor(tester, settings, original);
      final choice = find.byKey(const ValueKey('theme-course-palette'));
      await _reveal(tester, choice);
      expect(
        find.descendant(of: choice, matching: find.text('Tailwind')),
        findsOneWidget,
      );
      await tester.tap(choice);
      await tester.pumpAndSettle();
      final fuu = find.byWidgetPredicate(
        (widget) =>
            widget is RadioListTile<String> &&
            widget.value == CourseColorPalettes.fuu,
      );
      await tester.ensureVisible(fuu);
      await tester.tap(fuu);
      await tester.pumpAndSettle();
      final editor = find.byKey(
        const PageStorageKey('theme-course-palette-edit'),
      );
      await _reveal(tester, editor);
      await tester.tap(
        find.descendant(
          of: editor,
          matching: find.text(l10n.themeCoursePaletteEdit),
        ),
      );
      await tester.pumpAndSettle();
      final count = find.descendant(
        of: editor,
        matching: find.text(l10n.themeCoursePaletteCount(25)),
      );
      final heading = find
          .ancestor(of: count, matching: find.byType(Row))
          .first;
      expect(
        tester.getRect(count).right,
        closeTo(tester.getRect(heading).right, 0.01),
      );
      final color = find.byKey(const ValueKey('theme-course-palette-color-0'));
      await _reveal(tester, color);
      await _capture(tester, 'theme-editor-fuu-palette.png');
      await tester.tap(color);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('theme-color-hex')),
        '#80123456',
      );
      await _sheetReveal(
        tester,
        find.byKey(const ValueKey('theme-color-confirm')),
      );
      await tester.tap(find.byKey(const ValueKey('theme-color-confirm')));
      await tester.pumpAndSettle();
      await _reveal(tester, choice);
      expect(
        find.descendant(
          of: choice,
          matching: find.text(l10n.themeCoursePaletteCustom),
        ),
        findsOneWidget,
      );
      await _checkPreview(tester, (_, visuals) {
        expect(visuals.coursePaletteKey, CourseColorPalettes.fuu);
        expect(visuals.coursePalette.length, 25);
        expect(visuals.coursePalette.first, const Color(0x80123456));
      });
      expect(settings.activeCustomTheme.value, same(original));
      await _mode(tester, l10n, Brightness.dark);
      await _checkPreview(tester, (_, visuals) {
        expect(visuals.coursePaletteKey, CourseColorPalettes.tailwind);
        expect(visuals.coursePalette, isEmpty);
      });
      await _mode(tester, l10n, Brightness.light);
      await _reveal(tester, color);
      await tester.tap(color);
      await tester.pumpAndSettle();
      await _sheetReveal(
        tester,
        find.byKey(const ValueKey('theme-color-reset')),
      );
      await tester.tap(find.byKey(const ValueKey('theme-color-reset')));
      await tester.pumpAndSettle();
      await _checkPreview(tester, (_, visuals) {
        expect(visuals.coursePaletteKey, CourseColorPalettes.fuu);
        expect(visuals.coursePalette, isEmpty);
      });
      await _reveal(tester, choice);
      expect(
        find.descendant(of: choice, matching: find.text('FUU')),
        findsOneWidget,
      );
      final add = find.byKey(const ValueKey('theme-course-palette-add'));
      await _reveal(tester, add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await _reveal(tester, choice);
      expect(
        find.descendant(
          of: choice,
          matching: find.text(l10n.themeCoursePaletteCustom),
        ),
        findsOneWidget,
      );
      await tester.tap(choice);
      await tester.pumpAndSettle();
      await tester.ensureVisible(fuu);
      await tester.tap(fuu);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: choice, matching: find.text('FUU')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      final saved = (await tester.runAsync(() => store.load(original.id)))!;
      expect(saved.light.coursePaletteKey, CourseColorPalettes.fuu);
      expect(saved.light.coursePalette, isEmpty);
      expect(saved.dark.coursePaletteKey, CourseColorPalettes.tailwind);
      expect(saved.dark.coursePalette, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'course palette is generated from the $brightness wallpaper only',
      (tester) async {
        final red = _png(directory, 'red-background.png', 255, 0);
        final blue = _png(directory, 'blue-background.png', 0, 255);
        final redPath = (await tester.runAsync(
          () => store.importBackgroundImage(red),
        ))!;
        final bluePath = (await tester.runAsync(
          () => store.importBackgroundImage(blue),
        ))!;
        final original = _profile(
          light: ThemeVariant(
            colorSource: 'seed',
            seedColor: 0xff335577,
            backgroundImagePath: redPath,
            coursePalette: const [0xffabcdef, 0xff123456],
            courseCardOpacity: 0.65,
            courseCardRadius: 19,
            colors: {'primary': 0xff335577, 'courseCard': 0xffeeeeee},
          ),
          dark: ThemeVariant(
            colorSource: 'system',
            backgroundImagePath: bluePath,
            coursePalette: const [0xc0abcdef, 0xc0123456],
            courseCardOpacity: 0.8,
            courseCardRadius: 24,
            colors: {'primary': 0xff998877, 'courseAccent': 0xffcccccc},
          ),
        );
        final l10n = await _openEditor(
          tester,
          settings,
          original,
          size: const Size(320, 720),
          locale: Locale(brightness == Brightness.light ? 'zh' : 'en'),
          textScale: 1.5,
        );
        await _mode(tester, l10n, brightness);
        final editor = find.byKey(
          const PageStorageKey('theme-course-palette-edit'),
        );
        await _reveal(tester, editor);
        await tester.tap(
          find.descendant(
            of: editor,
            matching: find.text(l10n.themeCoursePaletteEdit),
          ),
        );
        await tester.pumpAndSettle();
        final generate = find.byKey(
          const ValueKey('theme-course-palette-from-wallpaper'),
        );
        await _reveal(tester, generate);
        await tester.tap(generate);
        await _finishWork(tester);
        final choice = find.byKey(const ValueKey('theme-course-palette'));
        await _reveal(tester, choice);
        expect(
          find.descendant(
            of: choice,
            matching: find.text(l10n.themeCoursePaletteCustom),
          ),
          findsOneWidget,
        );
        await _reveal(tester, generate);
        await _capture(
          tester,
          'theme-editor-wallpaper-palette-${brightness.name}.png',
        );
        final expected = brightness == Brightness.light
            ? 0xffff0000
            : 0xff0000ff;
        final before = brightness == Brightness.light
            ? original.light
            : original.dark;
        await _checkPreview(tester, (_, visuals) {
          expect(visuals.coursePalette, [Color(expected)]);
          expect(
            visuals.colors['primary']?.toARGB32(),
            before.colors['primary'],
          );
          expect(visuals.colors.containsKey('courseCard'), isFalse);
          expect(visuals.colors.containsKey('courseAccent'), isFalse);
          expect(visuals.courseCardOpacity, before.courseCardOpacity);
          expect(visuals.courseCardRadius, before.courseCardRadius);
        });
        expect(settings.activeCustomTheme.value, isNull);
        await tester.tap(find.byKey(_save));
        await _finishWork(tester);
        final saved = (await tester.runAsync(() => store.load(original.id)))!;
        final selected = brightness == Brightness.light
            ? saved.light
            : saved.dark;
        expect(selected.coursePalette, [expected]);
        expect(selected.colorSource, before.colorSource);
        expect(selected.seedColor, before.seedColor);
        expect(selected.backgroundImagePath, before.backgroundImagePath);
        expect(
          brightness == Brightness.light
              ? saved.dark.toJson()
              : saved.light.toJson(),
          brightness == Brightness.light
              ? original.dark.toJson()
              : original.light.toJson(),
        );
        expect(tester.takeException(), isNull);
        // Saving applies the wallpaper to the underlying route too. Dispose
        // that route before temporary image files are removed on Windows.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
      },
    );

    testWidgets(
      'course palettes add and remove colors directly in $brightness',
      (tester) async {
        const lightColors = [0xff123456, 0xffabcdef, 0xff008833];
        const darkColors = [0xc0563412, 0xc0efcdab, 0xc0338800];
        final original = _profile(
          light: ThemeVariant(
            coursePalette: lightColors,
            colors: {'courseCard': 0xffeeeeee, 'courseAccent': 0xff333333},
          ),
          dark: ThemeVariant(
            coursePalette: darkColors,
            colors: {'courseCard': 0xff111111, 'courseAccent': 0xffcccccc},
          ),
        );
        settings.activateCustomTheme(original);
        final l10n = await _openEditor(
          tester,
          settings,
          original,
          size: const Size(320, 720),
          locale: Locale(brightness == Brightness.light ? 'zh' : 'en'),
          textScale: 1.5,
        );
        await _mode(tester, l10n, brightness);
        final primary = settings
            .buildProfileTheme(original, brightness)
            .colorScheme
            .primary
            .toARGB32();
        final editor = find.byKey(
          const PageStorageKey('theme-course-palette-edit'),
        );
        await _reveal(tester, editor);
        await tester.tap(
          find.descendant(
            of: editor,
            matching: find.text(l10n.themeCoursePaletteEdit),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('theme-course-palette-from-wallpaper')),
          findsNothing,
        );
        final remove = find.byTooltip(l10n.themeCoursePaletteRemove(2));
        await _reveal(tester, remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        final add = find.byKey(const ValueKey('theme-course-palette-add'));
        await _reveal(tester, add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(const ValueKey('theme-color-hex')), findsNothing);
        final colors = brightness == Brightness.light
            ? lightColors
            : darkColors;
        final expected = [colors.first, colors.last, primary];
        await _checkPreview(tester, (_, visuals) {
          expect(
            visuals.coursePalette.map((color) => color.toARGB32()).toList(),
            expected,
          );
          expect(visuals.colors.containsKey('courseCard'), isFalse);
          expect(visuals.colors.containsKey('courseAccent'), isFalse);
        });
        expect(settings.activeCustomTheme.value, same(original));
        final other = brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light;
        await _mode(tester, l10n, other);
        await _checkPreview(tester, (_, visuals) {
          expect(
            visuals.coursePalette.map((color) => color.toARGB32()).toList(),
            other == Brightness.light ? lightColors : darkColors,
          );
          expect(visuals.colors.containsKey('courseCard'), isTrue);
          expect(visuals.colors.containsKey('courseAccent'), isTrue);
        });
        await tester.tap(find.byKey(_save));
        await _finishWork(tester);
        final saved = (await tester.runAsync(() => store.load(original.id)))!;
        expect(
          brightness == Brightness.light
              ? saved.light.coursePalette
              : saved.dark.coursePalette,
          expected,
        );
        expect(
          other == Brightness.light
              ? saved.light.toJson()
              : saved.dark.toJson(),
          other == Brightness.light
              ? original.light.toJson()
              : original.dark.toJson(),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('wallpaper palette failure preserves existing course colors', (
    tester,
  ) async {
    final invalid = File('${directory.path}/damaged-wallpaper.png')
      ..writeAsStringSync('invalid picture');
    final original = _profile(
      light: ThemeVariant(
        backgroundImagePath: invalid.path,
        coursePalette: const [0xff123456, 0xffabcdef],
        colors: {'courseCard': 0xffeeeeee, 'courseAccent': 0xff333333},
      ),
    );
    final l10n = await _openEditor(tester, settings, original);
    final editor = find.byKey(
      const PageStorageKey('theme-course-palette-edit'),
    );
    await _reveal(tester, editor);
    await tester.tap(
      find.descendant(
        of: editor,
        matching: find.text(l10n.themeCoursePaletteEdit),
      ),
    );
    await tester.pumpAndSettle();
    final generate = find.byKey(
      const ValueKey('theme-course-palette-from-wallpaper'),
    );
    await _reveal(tester, generate);
    await tester.tap(generate);
    await _finishWork(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(_save)).onPressed, isNotNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeEditorPage), findsNothing);
    expect(find.text(l10n.themeUnsavedTitle), findsNothing);
    expect(settings.customThemes.value, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final count in [1, CourseColorPalettes.maxColors]) {
    testWidgets('course palette enforces the $count color boundary', (
      tester,
    ) async {
      final colors = List<int>.generate(
        count,
        (index) => 0xff000000 | index * 0x010101,
      );
      final original = _profile(light: ThemeVariant(coursePalette: colors));
      final l10n = await _openEditor(tester, settings, original);
      final editor = find.byKey(
        const PageStorageKey('theme-course-palette-edit'),
      );
      await _reveal(tester, editor);
      await tester.tap(
        find.descendant(
          of: editor,
          matching: find.text(l10n.themeCoursePaletteEdit),
        ),
      );
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('theme-course-palette-color-0'));
      final add = find.byKey(const ValueKey('theme-course-palette-add'));
      if (count == 1) {
        expect(tester.widget<InputChip>(first).onDeleted, isNull);
        await _reveal(tester, add);
        expect(tester.widget<ActionChip>(add).onPressed, isNotNull);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(tester.widget<InputChip>(first).onDeleted, isNotNull);
        final remove = find.byTooltip(l10n.themeCoursePaletteRemove(2));
        await _reveal(tester, remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(tester.widget<InputChip>(first).onDeleted, isNull);
      } else {
        await _reveal(tester, add);
        expect(tester.widget<ActionChip>(add).onPressed, isNull);
        final remove = find.byTooltip(l10n.themeCoursePaletteRemove(count));
        await _reveal(tester, remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await _reveal(tester, add);
        expect(tester.widget<ActionChip>(add).onPressed, isNotNull);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(tester.widget<ActionChip>(add).onPressed, isNull);
      }
      expect(
        find.descendant(of: editor, matching: find.byType(InputChip)),
        findsNWidgets(count),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'drafts keep all visual parameters and brightness modes isolated',
    (tester) async {
      final original = _profile();
      settings.activateCustomTheme(original);
      final l10n = await _openEditor(tester, settings, original);
      final basicInfo = find.byKey(const ValueKey('theme-basic-info-section'));
      expect(
        find.descendant(
          of: basicInfo,
          matching: find.text(l10n.themeBasicInfo),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: basicInfo, matching: find.byKey(_name)),
        findsOneWidget,
      );
      await _capture(tester, 'theme-editor-basic-info.png');
      await tester.enterText(find.byKey(_name), '  编辑后的主题  ');
      final dimRow = find.byKey(
        const ValueKey('theme-slider-row-backgroundDim'),
      );
      await _reveal(tester, dimRow);
      expect(
        find.byKey(const ValueKey('theme-slider-backgroundDim')),
        findsNothing,
      );
      expect(
        find.descendant(of: dimRow, matching: find.text('0%')),
        findsOneWidget,
      );
      await _setSlider(tester, 'backgroundDim', 0.35);
      await _reveal(tester, dimRow);
      expect(
        find.descendant(of: dimRow, matching: find.text('35%')),
        findsOneWidget,
      );
      final dim = find.byKey(const ValueKey('theme-slider-backgroundDim'));
      await _reveal(tester, dim);
      final drag = await tester.startGesture(tester.getCenter(dim));
      await drag.moveBy(const Offset(40, 0));
      await tester.pump();
      final duringDrag = tester.widget<Slider>(dim).value;
      expect(duringDrag, isNot(0.35));
      expect(
        find.descendant(
          of: dimRow,
          matching: find.text('${(duringDrag * 100).round()}%'),
        ),
        findsOneWidget,
      );
      await drag.up();
      await tester.pumpAndSettle();
      await _setSlider(tester, 'backgroundDim', 0.35);
      await tester.tap(dimRow);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('theme-slider-backgroundDim')),
        findsNothing,
      );
      expect(
        find.descendant(of: dimRow, matching: find.text('35%')),
        findsOneWidget,
      );
      final dimSlider = await _expandSlider(tester, 'backgroundDim');
      expect(tester.widget<Slider>(dimSlider).value, 0.35);
      await _setSlider(tester, 'backgroundBlur', 12);
      await _setSlider(tester, 'surfaceOpacity', 0.55);
      await _setSlider(tester, 'courseCardOpacity', 0.65);
      await _setSlider(tester, 'cardRadius', 32);
      await _setSlider(tester, 'courseCardRadius', 16);
      await _setSlider(tester, 'dividerWidth', 1.5);
      // The background section leaves the viewport. Its native expansion state
      // and draft value must survive being rebuilt by the scrolling list.
      await _reveal(
        tester,
        find.byKey(const ValueKey('theme-slider-row-courseCardRadius')),
      );
      await _reveal(tester, dimRow);
      expect(dimSlider, findsOneWidget);
      expect(tester.widget<Slider>(dimSlider).value, 0.35);
      await _mode(tester, l10n, Brightness.dark);
      await _reveal(tester, dimRow);
      expect(
        find.descendant(of: dimRow, matching: find.text('0%')),
        findsOneWidget,
      );
      await _setSlider(tester, 'backgroundDim', 0.75);
      expect(settings.activeCustomTheme.value, same(original));
      expect(settings.customThemes.value, isEmpty);
      await _mode(tester, l10n, Brightness.light);
      await _reveal(tester, dimRow);
      expect(
        find.descendant(of: dimRow, matching: find.text('35%')),
        findsOneWidget,
      );
      await _checkPreview(tester, (theme, visuals) {
        expect(visuals.backgroundDim, 0.35);
        expect(visuals.backgroundBlur, 12);
        expect(visuals.courseCardOpacity, 0.65);
        expect(visuals.cardRadius, 32);
        expect(theme.brightness, Brightness.light);
      });
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      expect(find.byType(ThemeEditorPage), findsNothing);
      final saved = (await tester.runAsync(() => store.load(original.id)))!;
      expect(saved.name, '编辑后的主题');
      expect(saved.light.backgroundDim, 0.35);
      expect(saved.light.backgroundBlur, 12);
      expect(saved.light.surfaceOpacity, 0.55);
      expect(saved.light.courseCardOpacity, 0.65);
      expect(saved.light.cardRadius, 32);
      expect(saved.light.courseCardRadius, 16);
      expect(saved.light.dividerWidth, 1.5);
      expect(saved.dark.backgroundDim, 0.75);
      expect(saved.dark.courseCardOpacity, original.dark.courseCardOpacity);
      expect(settings.activeCustomTheme.value!.toJson(), saved.toJson());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hex validation and RGBA channels agree before confirming a color',
    (tester) async {
      final original = _profile();
      settings.activateCustomTheme(original);
      final l10n = await _openEditor(tester, settings, original);
      await _openPaletteColor(tester);
      final hex = find.byKey(const ValueKey('theme-color-hex'));
      await tester.enterText(hex, '#GG');
      await tester.pumpAndSettle();
      expect(find.text(l10n.themeColorInvalid), findsOneWidget);
      final confirm = find.byKey(const ValueKey('theme-color-confirm'));
      await _sheetReveal(tester, confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(hex, findsOneWidget);
      await _sheetReveal(tester, hex);
      await tester.enterText(hex, '#80123456');
      await tester.pumpAndSettle();
      for (final entry in {
        'R': 18.0,
        'G': 52.0,
        'B': 86.0,
        'A': 128.0,
      }.entries) {
        final row = find.byKey(
          ValueKey('theme-slider-row-channel-${entry.key}'),
        );
        await _sheetReveal(tester, row);
        expect(
          find.descendant(
            of: row,
            matching: find.text('${entry.value.toInt()}'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('theme-slider-channel-${entry.key}')),
          findsNothing,
        );
      }
      await _setSlider(tester, 'channel-R', 220, inSheet: true);
      expect(tester.widget<TextField>(hex).controller!.text, '#80DC3456');
      final redRow = find.byKey(const ValueKey('theme-slider-row-channel-R'));
      await _sheetReveal(tester, redRow);
      await tester.tap(redRow);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('theme-slider-channel-R')),
        findsNothing,
      );
      expect(
        find.descendant(of: redRow, matching: find.text('220')),
        findsOneWidget,
      );
      final red = await _expandSlider(tester, 'channel-R', inSheet: true);
      expect(tester.widget<Slider>(red).value, 220);
      await _sheetReveal(tester, confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(settings.activeCustomTheme.value, same(original));
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      expect(
        settings.activeCustomTheme.value!.light.coursePalette.first,
        0x80dc3456,
      );
      expect(
        settings.activeCustomTheme.value!.dark.colors,
        original.dark.colors,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'six digit hex is opaque and restoring a palette color uses its preset',
    (tester) async {
      final original = _profile(
        light: ThemeVariant(
          colors: {
            'courseCard': 0xff123456,
            'courseAccent': 0xff334455,
            'courseCardText': 0xff112233,
          },
        ),
      );
      await _openEditor(tester, settings, original);
      await _openPaletteColor(tester);
      final hex = find.byKey(const ValueKey('theme-color-hex'));
      await tester.enterText(hex, '#12AB34');
      final confirm = find.byKey(const ValueKey('theme-color-confirm'));
      await _sheetReveal(tester, confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await _checkPreview(tester, (_, visuals) {
        expect(visuals.coursePalette.first, const Color(0xff12ab34));
      });
      await _openPaletteColor(tester);
      expect(tester.widget<TextField>(hex).controller!.text, '#FF12AB34');
      final reset = find.byKey(const ValueKey('theme-color-reset'));
      await _sheetReveal(tester, reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await _checkPreview(tester, (_, visuals) {
        expect(visuals.coursePalette, isEmpty);
      });
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      final saved = settings.activeCustomTheme.value!;
      expect(saved.light.coursePalette, isEmpty);
      expect(saved.light.colors, {'courseCardText': 0xff112233});
      expect(saved.dark.colors, original.dark.colors);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canceling a color sheet keeps a clean draft clean', (
    tester,
  ) async {
    final original = _profile();
    final l10n = await _openEditor(tester, settings, original);
    await _openPaletteColor(tester);
    await tester.enterText(
      find.byKey(const ValueKey('theme-color-hex')),
      '#00000000',
    );
    final cancel = find.widgetWithText(TextButton, l10n.learningCancel);
    await _sheetReveal(tester, cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeEditorPage), findsNothing);
    expect(find.text(l10n.themeUnsavedTitle), findsNothing);
    expect(settings.customThemes.value, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system and toolbar back protect unsaved edits', (tester) async {
    final original = _profile();
    settings.activateCustomTheme(original);
    final l10n = await _openEditor(tester, settings, original);
    await tester.enterText(find.byKey(_name), '未保存');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(l10n.themeUnsavedTitle), findsOneWidget);
    await tester.tap(find.text(l10n.themeKeepEditing));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(_name)).controller!.text, '未保存');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.themeDiscard));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeEditorPage), findsNothing);
    expect(settings.activeCustomTheme.value, same(original));
    expect(settings.customThemes.value, isEmpty);
  });

  testWidgets('an empty name does not save or apply the draft', (tester) async {
    final l10n = await _openEditor(tester, settings, _profile());
    await tester.enterText(find.byKey(_name), '   ');
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.themeNameRequired), findsOneWidget);
    expect(settings.customThemes.value, isEmpty);
    expect(settings.activeCustomTheme.value, isNull);
  });

  testWidgets(
    'base palette selection is previewed without changing app settings',
    (tester) async {
      final l10n = await _openEditor(tester, settings, _profile());
      final base = find.byKey(const ValueKey('theme-base-palette'));
      await _reveal(tester, base);
      await tester.tap(base);
      await tester.pumpAndSettle();
      final blue = find.text(l10n.themeBlue);
      await _sheetReveal(tester, blue);
      await tester.tap(blue);
      await tester.pumpAndSettle();
      await _confirmPalette(tester);
      expect(settings.themeKey.value, 'deep_purple');
      expect(settings.activeCustomTheme.value, isNull);
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      expect(settings.activeCustomTheme.value!.baseThemeKey, 'deep_purple');
      expect(settings.activeCustomTheme.value!.light.colorSource, 'seed');
      expect(
        settings.activeCustomTheme.value!.light.seedColor,
        appThemes.firstWhere((entry) => entry.key == 'blue').color.toARGB32(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'base palette custom row follows the $brightness choice after saving',
      (tester) async {
        final original = _profile(light: ThemeVariant(), dark: ThemeVariant());
        final l10n = await _openEditor(tester, settings, original);
        final base = find.byKey(const ValueKey('theme-base-palette'));
        final seed = find.byKey(const ValueKey('theme-seed-color'));
        await _mode(tester, l10n, brightness);
        await _reveal(tester, base);
        expect(seed, findsNothing);
        await _selectBasePalette(tester, 'custom');
        expect(find.byKey(const ValueKey('theme-color-hex')), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        await _reveal(tester, seed);
        expect(seed.hitTestable(), findsOneWidget);
        await _checkPreview(tester, (theme, _) {
          expect(
            theme.colorScheme.primary,
            ColorScheme.fromSeed(
              seedColor: appThemes.first.color,
              brightness: brightness,
            ).primary,
          );
        });
        final other = brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light;
        await _mode(tester, l10n, other);
        await _reveal(tester, base);
        expect(seed, findsNothing);
        await tester.tap(find.byKey(_save));
        await _finishWork(tester);
        final saved = (await tester.runAsync(() => store.load(original.id)))!;
        expect(saved.light.isSeedColorCustom, brightness == Brightness.light);
        expect(saved.dark.isSeedColorCustom, brightness == Brightness.dark);
        await _openEditor(tester, settings, saved);
        await _mode(tester, l10n, brightness);
        await _reveal(tester, seed);
        expect(
          find.descendant(
            of: base,
            matching: find.text(l10n.themeCustomPalette),
          ),
          findsOneWidget,
        );
        await _selectBasePalette(tester, 'blue');
        expect(seed, findsNothing);
        await tester.tap(find.byKey(_save));
        await _finishWork(tester);
        final updated = settings.activeCustomTheme.value!;
        final selected = brightness == Brightness.light
            ? updated.light
            : updated.dark;
        expect(selected.isSeedColorCustom, isFalse);
        expect(
          selected.seedColor,
          appThemes.firstWhere((entry) => entry.key == 'blue').color.toARGB32(),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('legacy custom seed shows its editor without a saved choice', (
    tester,
  ) async {
    await _openEditor(
      tester,
      settings,
      _profile(light: ThemeVariant(colorSource: 'seed', seedColor: 0xff123456)),
    );
    final seed = find.byKey(const ValueKey('theme-seed-color'));
    await _reveal(tester, seed);
    expect(find.text('#FF123456'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy source is selected and missing wallpaper source hidden', (
    tester,
  ) async {
    final original = _profile().copyWith(baseThemeKey: 'dynamic');
    final l10n = await _openEditor(tester, settings, original);
    final system = find.byKey(const ValueKey('theme-source-system'));
    await _reveal(tester, system);
    expect(tester.widget<SettingsRadioTile<String>>(system).enabled, isFalse);
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'system',
    );
    expect(find.text(l10n.themeSourceSystemUnavailable), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-source-image')), findsNothing);
    expect(find.byKey(const ValueKey('theme-extract-colors')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.themeUnsavedTitle), findsNothing);
  });

  testWidgets(
    'an old image source without wallpaper falls back to system colors',
    (tester) async {
      final original = _profile(
        light: ThemeVariant(
          colorSource: 'image',
          seedColor: 0xffff0000,
          colors: {'courseAccent': 0xff334455},
        ),
      );
      settings.activateCustomTheme(original);
      await _openEditor(tester, settings, original);
      final system = find.byKey(const ValueKey('theme-source-system'));
      await _reveal(tester, system);
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'system',
      );
      expect(find.byKey(const ValueKey('theme-source-image')), findsNothing);
      expect(settings.activeCustomTheme.value, same(original));
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      final saved = settings.activeCustomTheme.value!;
      expect(saved.light.colorSource, 'system');
      expect(saved.light.seedColor, isNull);
      expect(saved.light.colors, original.light.colors);
      expect(saved.dark.toJson(), original.dark.toJson());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fresh palette selection applies directly without a reset prompt',
    (tester) async {
      final original = _profile(
        light: ThemeVariant(colors: {'courseCard': Colors.green.toARGB32()}),
      );
      final l10n = await _openEditor(tester, settings, original);
      final base = find.byKey(const ValueKey('theme-base-palette'));
      await _reveal(tester, base);
      await tester.tap(base);
      await tester.pumpAndSettle();
      final blue = find.text(l10n.themeBlue);
      await _sheetReveal(tester, blue);
      await tester.tap(blue);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await _checkPreview(tester, (theme, visuals) {
        expect(
          theme.colorScheme.primary,
          ColorScheme.fromSeed(
            seedColor: appThemes
                .firstWhere((entry) => entry.key == 'blue')
                .color,
          ).primary,
        );
        expect(
          visuals.colors['courseCard']?.toARGB32(),
          Colors.green.toARGB32(),
        );
      });
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      expect(settings.activeCustomTheme.value!.light.colorSource, 'seed');
      expect(
        settings.activeCustomTheme.value!.dark.toJson(),
        original.dark.toJson(),
      );
    },
  );

  testWidgets(
    'system source uses real platform colors only after confirmation',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _dynamicColor,
            (call) async => call.method == 'getAccentColor' ? 0xff008833 : null,
          );
      await settings.initDynamicColor();
      final original = _profile(
        light: ThemeVariant(
          colorSource: 'seed',
          seedColor: 0xff663399,
          colors: {'primary': 0xff123456, 'courseAccent': 0xffabcdef},
          courseCardOpacity: 0.6,
        ),
      );
      settings.activateCustomTheme(original);
      final l10n = await _openEditor(tester, settings, original);
      final system = find.byKey(const ValueKey('theme-source-system'));
      await _reveal(tester, system);
      expect(tester.widget<SettingsRadioTile<String>>(system).enabled, isTrue);
      await tester.tap(system);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.themeReplacePaletteMessage(l10n.light)),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.learningCancel));
      await tester.pumpAndSettle();
      await _checkPreview(tester, (_, visuals) {
        expect(visuals.colors['primary'], const Color(0xff123456));
      });
      await tester.tap(system);
      await _confirmPalette(tester);
      await tester.pumpAndSettle();
      await _checkPreview(tester, (theme, visuals) {
        expect(
          theme.colorScheme.primary,
          AppSettings.systemColorScheme(Brightness.light)!.primary,
        );
        expect(visuals.colors, {'courseAccent': const Color(0xffabcdef)});
        expect(visuals.courseCardOpacity, 0.6);
      });
      expect(settings.activeCustomTheme.value, same(original));
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      final saved = settings.activeCustomTheme.value!;
      expect(saved.light.colorSource, 'system');
      expect(saved.light.seedColor, 0xff663399);
      expect(saved.dark.toJson(), original.dark.toJson());
      expect(saved.baseThemeKey, original.baseThemeKey);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom seed replacement preserves timetable and other appearance',
    (tester) async {
      final original = _profile(
        light: ThemeVariant(
          colors: {'primary': 0xff123456, 'todayHighlight': 0xff334455},
          courseCardOpacity: 0.45,
          courseCardRadius: 19,
        ),
      );
      final l10n = await _openEditor(tester, settings, original);
      await _selectBasePalette(tester, 'custom');
      final seed = find.byKey(const ValueKey('theme-seed-color'));
      await _reveal(tester, seed);
      await tester.tap(seed);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('theme-color-hex')),
        '#FF0088AA',
      );
      final confirm = find.byKey(const ValueKey('theme-color-confirm'));
      await _sheetReveal(tester, confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text(l10n.themeReplacePalette), findsOneWidget);
      await tester.tap(find.text(l10n.learningCancel));
      await tester.pumpAndSettle();
      await _checkPreview(tester, (_, visuals) {
        expect(visuals.colors['primary'], const Color(0xff123456));
      });
      await tester.tap(seed);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('theme-color-hex')),
        '#FF0088AA',
      );
      await _sheetReveal(tester, confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await _confirmPalette(tester);
      await tester.pumpAndSettle();
      await _checkPreview(tester, (theme, visuals) {
        expect(
          theme.colorScheme.primary,
          ColorScheme.fromSeed(seedColor: const Color(0xff0088aa)).primary,
        );
        expect(visuals.courseCardOpacity, 0.45);
        expect(visuals.courseCardRadius, 19);
      });
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      final saved = settings.activeCustomTheme.value!;
      expect(saved.light.colorSource, 'seed');
      expect(saved.light.seedColor, 0xff0088aa);
      expect(saved.light.colors, {'todayHighlight': 0xff334455});
      expect(saved.dark.toJson(), original.dark.toJson());
      expect(saved.baseThemeKey, original.baseThemeKey);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late dynamic colors refresh an open editor and its preview', (
    tester,
  ) async {
    final original = _profile(
      light: ThemeVariant(colorSource: 'system', seedColor: 0xff663399),
    );
    final l10n = await _openEditor(tester, settings, original);
    final system = find.byKey(const ValueKey('theme-source-system'));
    await _reveal(tester, system);
    expect(tester.widget<SettingsRadioTile<String>>(system).enabled, isFalse);
    await _openPreview(tester);
    expect(
      Theme.of(tester.element(find.byKey(_preview))).colorScheme.primary,
      ColorScheme.fromSeed(seedColor: const Color(0xff663399)).primary,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _dynamicColor,
          (call) async => call.method == 'getAccentColor' ? 0xffcc4400 : null,
        );
    await settings.initDynamicColor();
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(_preview))).colorScheme.primary,
      AppSettings.systemColorScheme(Brightness.light)!.primary,
    );
    await _closePreview(tester);
    expect(tester.widget<SettingsRadioTile<String>>(system).enabled, isTrue);
    expect(find.text(l10n.themeSourceSystemUnavailable), findsNothing);
    expect(settings.activeCustomTheme.value, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'picked image is copied, mode scoped, and independent of the source',
    (tester) async {
      final source = _png(directory, 'picked.png', 255, 0);
      Map<Object?, Object?>? request;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_picker, (call) async {
            expect(call.method, 'openFile');
            request = call.arguments as Map<Object?, Object?>;
            return [source.path];
          });
      final l10n = await _openEditor(tester, settings, _profile());
      final choose = find.byKey(const ValueKey('theme-choose-image'));
      await _reveal(tester, choose);
      await tester.tap(choose);
      await _finishWork(tester);
      expect(request!['acceptedTypeGroups'], isNotEmpty);
      await _openPreview(tester);
      final path = _previewVisuals(tester).backgroundImage!;
      expect(path, contains('fzu-themes'));
      expect(path, isNot(source.path));
      expect(settings.activeCustomTheme.value, isNull);
      expect(settings.customThemes.value, isEmpty);
      expect(_previewVisuals(tester).colors, {
        'primary': const Color(0xff123456),
      });
      await tester.runAsync(() => source.delete());
      expect(await tester.runAsync(() => File(path).exists()), isTrue);
      await _closePreview(tester);
      await _mode(tester, l10n, Brightness.dark);
      await _checkPreview(tester, (_, visuals) {
        expect(visuals.backgroundImage, isNull);
      });
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      expect(settings.activeCustomTheme.value!.light.backgroundImagePath, path);
      expect(
        settings.activeCustomTheme.value!.dark.backgroundImagePath,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'removing $brightness wallpaper selects system colors without changing the other mode',
      (tester) async {
        final source = _png(directory, 'background.png', 255, 0);
        final path = (await tester.runAsync(
          () => store.importBackgroundImage(source),
        ))!;
        final original = _profile(
          light: ThemeVariant(
            colorSource: 'image',
            seedColor: 0xffff0000,
            backgroundImagePath: path,
            backgroundDim: 0.2,
            colors: {'courseAccent': 0xff334455},
          ),
          dark: ThemeVariant(
            colorSource: 'image',
            seedColor: 0xffff0000,
            backgroundImagePath: path,
            backgroundDim: 0.8,
            colors: {'divider': 0xff112233},
          ),
        );
        settings.activateCustomTheme(original);
        final l10n = await _openEditor(tester, settings, original);
        await _mode(tester, l10n, brightness);
        final remove = find.byKey(const ValueKey('theme-remove-image'));
        await _reveal(tester, remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        final system = find.byKey(const ValueKey('theme-source-system'));
        await _reveal(tester, system);
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          'system',
        );
        expect(find.byKey(const ValueKey('theme-source-image')), findsNothing);
        expect(settings.activeCustomTheme.value, same(original));
        await tester.tap(find.byKey(_save));
        await _finishWork(tester);
        final saved = settings.activeCustomTheme.value!;
        final removed = brightness == Brightness.light
            ? saved.light
            : saved.dark;
        final prior = brightness == Brightness.light
            ? original.light
            : original.dark;
        expect(removed.backgroundImagePath, isNull);
        expect(removed.colorSource, 'system');
        expect(removed.seedColor, isNull);
        expect(removed.backgroundDim, prior.backgroundDim);
        expect(removed.colors, prior.colors);
        expect(
          brightness == Brightness.light
              ? saved.dark.toJson()
              : saved.light.toJson(),
          brightness == Brightness.light
              ? original.dark.toJson()
              : original.light.toJson(),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$brightness image source directly samples its own wallpaper', (
      tester,
    ) async {
      final red = _png(directory, 'red.png', 255, 0);
      final blue = _png(directory, 'blue.png', 0, 255);
      final redPath = (await tester.runAsync(
        () => store.importBackgroundImage(red),
      ))!;
      final bluePath = (await tester.runAsync(
        () => store.importBackgroundImage(blue),
      ))!;
      final original = _profile(
        light: ThemeVariant(
          backgroundImagePath: redPath,
          colors: {'primary': 0xff123456, 'courseAccent': 0xff334455},
        ),
        dark: ThemeVariant(
          backgroundImagePath: bluePath,
          colors: {'primary': 0xffabcdef, 'divider': 0xff112233},
        ),
      );
      settings.activateCustomTheme(original);
      final l10n = await _openEditor(tester, settings, original);
      await _mode(tester, l10n, brightness);
      final imageSource = find.byKey(const ValueKey('theme-source-image'));
      await _reveal(tester, imageSource);
      expect(find.byKey(const ValueKey('theme-extract-colors')), findsNothing);
      await tester.tap(imageSource);
      await tester.pumpAndSettle();
      expect(
        find.text(
          l10n.themeReplacePaletteMessage(
            brightness == Brightness.light ? l10n.light : l10n.dark,
          ),
        ),
        findsOneWidget,
      );
      await _confirmPalette(tester);
      await _finishWork(tester);
      expect(settings.activeCustomTheme.value, same(original));
      await tester.tap(find.byKey(_save));
      await _finishWork(tester);
      final saved = settings.activeCustomTheme.value!;
      final selected = brightness == Brightness.light
          ? saved.light
          : saved.dark;
      final seed = brightness == Brightness.light
          ? const Color(0xffff0000)
          : const Color(0xff0000ff);
      expect(
        selected.colors,
        brightness == Brightness.light
            ? {'courseAccent': 0xff334455}
            : {'divider': 0xff112233},
      );
      expect(selected.colorSource, 'image');
      expect(selected.seedColor, seed.toARGB32());
      expect(
        settings.buildProfileTheme(saved, brightness).colorScheme.primary,
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness).primary,
      );
      expect(
        brightness == Brightness.light
            ? saved.dark.toJson()
            : saved.light.toJson(),
        brightness == Brightness.light
            ? original.dark.toJson()
            : original.light.toJson(),
      );
      expect(saved.light.backgroundImagePath, redPath);
      expect(saved.dark.backgroundImagePath, bluePath);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changing wallpaper refreshes its seed and keeps custom colors', (
    tester,
  ) async {
    final blue = _png(directory, 'original.png', 0, 255);
    final bluePath = (await tester.runAsync(
      () => store.importBackgroundImage(blue),
    ))!;
    final red = _png(directory, 'replacement.png', 255, 0);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_picker, (_) async => [red.path]);
    final original = _profile(
      dark: ThemeVariant(
        colorSource: 'image',
        seedColor: 0xff0000ff,
        backgroundImagePath: bluePath,
        colors: {'primary': 0xffabcdef, 'courseAccent': 0xff334455},
        backgroundDim: 0.7,
        courseCardRadius: 16,
      ),
    );
    final l10n = await _openEditor(tester, settings, original);
    await _mode(tester, l10n, Brightness.dark);
    final choose = find.byKey(const ValueKey('theme-choose-image'));
    await _reveal(tester, choose);
    await tester.tap(choose);
    await _finishWork(tester);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byKey(_save));
    await _finishWork(tester);
    final saved = settings.activeCustomTheme.value!;
    expect(saved.dark.colorSource, 'image');
    expect(saved.dark.seedColor, 0xffff0000);
    expect(saved.dark.backgroundImagePath, isNot(bluePath));
    expect(saved.dark.backgroundImagePath, isNot(red.path));
    expect(saved.dark.colors, original.dark.colors);
    expect(saved.dark.backgroundDim, 0.7);
    expect(saved.dark.courseCardRadius, 16);
    expect(saved.light.toJson(), original.light.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling or rejecting an image preserves the draft', (
    tester,
  ) async {
    final invalid = File('${directory.path}/broken.png')
      ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47]);
    String? pick;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _picker,
          (_) async => pick == null ? null : [pick],
        );
    await _openEditor(tester, settings, _profile());
    final choose = find.byKey(const ValueKey('theme-choose-image'));
    await _reveal(tester, choose);
    await tester.tap(choose);
    await _finishWork(tester);
    await _checkPreview(tester, (_, visuals) {
      expect(visuals.backgroundImage, isNull);
    });
    pick = invalid.path;
    await _reveal(tester, choose);
    await tester.tap(choose);
    await _finishWork(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    await _checkPreview(tester, (_, visuals) {
      expect(visuals.backgroundImage, isNull);
    });
    expect(settings.customThemes.value, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save failure keeps the draft editable and supports retry', (
    tester,
  ) async {
    settings.dispose();
    settings = AppSettings(themeStore: _FailOnceStore(directory));
    final original = _profile();
    settings.activateCustomTheme(original);
    await _openEditor(tester, settings, original);
    await tester.enterText(find.byKey(_name), '保存重试');
    await tester.tap(find.byKey(_save));
    await _finishWork(tester);
    expect(find.byType(ThemeEditorPage), findsOneWidget);
    expect(settings.activeCustomTheme.value, same(original));
    expect(settings.customThemes.value, isEmpty);
    await tester.tap(find.byKey(_save));
    await _finishWork(tester);
    expect(settings.activeCustomTheme.value!.name, '保存重试');
    expect(find.byType(ThemeEditorPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final locale in [const Locale('zh'), const Locale('en')]) {
      testWidgets(
        'long form and color sheet fit $size ${locale.languageCode}',
        (tester) async {
          final l10n = await _openEditor(
            tester,
            settings,
            _profile(),
            size: size,
            locale: locale,
            textScale: 1.5,
          );
          await _setSlider(tester, 'backgroundDim', 0.3);
          final dimRow = find.byKey(
            const ValueKey('theme-slider-row-backgroundDim'),
          );
          await _reveal(tester, dimRow);
          final summary = find.descendant(
            of: dimRow,
            matching: find.text('30%'),
          );
          expect(summary.hitTestable(), findsOneWidget);
          expect(tester.getRect(summary).right, lessThanOrEqualTo(size.width));
          expect(
            tester.getRect(summary).left,
            greaterThan(
              tester
                  .getRect(
                    find.descendant(
                      of: dimRow,
                      matching: find.text(l10n.themeBackgroundDim),
                    ),
                  )
                  .right,
            ),
          );
          await _mode(tester, l10n, Brightness.dark);
          expect(tester.takeException(), isNull);
          await _openPaletteColor(tester);
          final alpha = await _expandSlider(tester, 'channel-A', inSheet: true);
          await tester.drag(alpha, const Offset(-40, 0));
          await tester.pumpAndSettle();
          final alphaValue = tester.widget<Slider>(alpha).value.toInt();
          final alphaRow = find.byKey(
            const ValueKey('theme-slider-row-channel-A'),
          );
          await _sheetReveal(tester, alphaRow);
          expect(
            find.descendant(of: alphaRow, matching: find.text('$alphaValue')),
            findsOneWidget,
          );
          await tester.tap(alphaRow);
          await tester.pumpAndSettle();
          expect(alpha, findsNothing);
          expect(
            find.descendant(of: alphaRow, matching: find.text('$alphaValue')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          final confirm = find.byKey(const ValueKey('theme-color-confirm'));
          await _sheetReveal(tester, confirm);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          final lastRow = find.byKey(
            const ValueKey('theme-slider-row-courseCardRadius'),
          );
          await _reveal(tester, lastRow);
          expect(lastRow.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final scenario in [
    (size: const Size(400, 800), scale: 1.0, style: InterfaceStyle.cards),
    (
      size: const Size(400, 800),
      scale: 1.0,
      style: InterfaceStyle.continuousCards,
    ),
    (size: const Size(400, 800), scale: 1.0, style: InterfaceStyle.classic),
    (size: const Size(320, 480), scale: 2.0, style: InterfaceStyle.cards),
    (size: const Size(640, 320), scale: 2.0, style: InterfaceStyle.cards),
  ]) {
    testWidgets('preview opens on demand and preserves form scroll $scenario', (
      tester,
    ) async {
      final original = _profile();
      settings.activateCustomTheme(original);
      settings.interfaceStyle.value = scenario.style;
      final l10n = await _openEditor(
        tester,
        settings,
        original,
        size: scenario.size,
        textScale: scenario.scale,
      );
      final button = find.byKey(_previewButton);
      expect(
        find.descendant(of: button, matching: find.text(l10n.themePreview)),
        findsOneWidget,
      );
      expect(tester.widget(button), isA<TextButton>());
      expect(find.byKey(_preview, skipOffstage: false), findsNothing);
      expect(find.byKey(_previewSheet, skipOffstage: false), findsNothing);
      final mode = find.byKey(const ValueKey('theme-editor-mode'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('theme-editor-list')),
          matching: mode,
        ),
        findsOneWidget,
      );
      final list = tester.getRect(_listScroll());
      expect(
        list.top,
        lessThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom + 1),
      );
      expect(list.height, greaterThan(scenario.size.height * 0.5));
      await _reveal(tester, find.byKey(_name));
      await tester.enterText(find.byKey(_name), '当前草稿预览');
      await _setSlider(tester, 'backgroundDim', 0.3);
      final captureName =
          '${scenario.size.width.toInt()}x${scenario.size.height.toInt()}-${scenario.scale}-${scenario.style.name}';
      await _capture(tester, 'theme-editor-$captureName.png');
      await tester.dragFrom(
        Offset(list.left + 8, list.center.dy),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(_listScroll()).position;
      final before = position.pixels;
      expect(before, greaterThan(0));
      expect(mode.hitTestable(), findsNothing);
      await _openPreview(tester);
      expect(
        find.descendant(
          of: find.byKey(_preview),
          matching: find.text('当前草稿预览'),
        ),
        findsOneWidget,
      );
      expect(_previewVisuals(tester).backgroundDim, 0.3);
      expect(
        MediaQuery.textScalerOf(tester.element(find.byKey(_preview))).scale(16),
        16 * scenario.scale,
      );
      await _previewMode(tester, Brightness.dark);
      expect(
        Theme.of(tester.element(find.byKey(_preview))).brightness,
        Brightness.dark,
      );
      expect(
        _previewVisuals(tester).colors['primary'],
        const Color(0xffabcdef),
      );
      await _previewMode(tester, Brightness.light);
      expect(_previewVisuals(tester).backgroundDim, 0.3);
      await _sheetReveal(
        tester,
        find.descendant(
          of: find.byKey(_preview),
          matching: find.text(l10n.customCourseName),
        ),
      );
      await _capture(tester, 'theme-editor-$captureName-preview.png');
      await _closePreview(tester);
      expect(position.pixels, closeTo(before, 0.01));
      expect(settings.activeCustomTheme.value, same(original));
      expect(settings.customThemes.value, isEmpty);
      final last = find.byKey(
        const ValueKey('theme-slider-row-courseCardRadius'),
      );
      await _reveal(tester, last);
      expect(last.hitTestable(), findsOneWidget);
      final atEnd = position.pixels;
      await _checkPreview(tester, (_, visuals) {
        expect(visuals.backgroundDim, 0.3);
      });
      expect(position.pixels, closeTo(atEnd, 0.01));
      await _setSlider(tester, 'backgroundDim', 0.65);
      await _checkPreview(tester, (_, visuals) {
        expect(visuals.backgroundDim, 0.65);
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview mode changes leave a clean draft unsaved', (
    tester,
  ) async {
    final original = _profile();
    settings.activateCustomTheme(original);
    final l10n = await _openEditor(tester, settings, original);
    await _openPreview(tester);
    await _previewMode(tester, Brightness.dark);
    await _closePreview(tester);
    expect(settings.activeCustomTheme.value, same(original));
    expect(settings.customThemes.value, isEmpty);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeEditorPage), findsNothing);
    expect(find.text(l10n.themeUnsavedTitle), findsNothing);
  });

  testWidgets('preview shows real slider edits after closing and reopening', (
    tester,
  ) async {
    final original = _profile();
    settings.activateCustomTheme(original);
    await _openEditor(tester, settings, original);
    await _openPreview(tester);
    expect(_previewVisuals(tester).backgroundDim, original.light.backgroundDim);
    await _closePreview(tester);
    await _setSlider(tester, 'backgroundDim', 0.42);
    await _openPreview(tester);
    expect(_previewVisuals(tester).backgroundDim, 0.42);
    expect(settings.activeCustomTheme.value, same(original));
    expect(settings.customThemes.value, isEmpty);
    await _closePreview(tester);
    final slider = await _expandSlider(tester, 'backgroundDim');
    expect(tester.widget<Slider>(slider).value, 0.42);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard leaves the full form editable without a preview', (
    tester,
  ) async {
    await _openEditor(
      tester,
      settings,
      _profile(),
      size: const Size(400, 800),
      textScale: 1.5,
    );
    await tester.showKeyboard(find.byKey(_name));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(find.byKey(_preview, skipOffstage: false), findsNothing);
    expect(find.byKey(_previewSheet, skipOffstage: false), findsNothing);
    expect(tester.getRect(_listScroll()).height, greaterThan(240));
    await _reveal(tester, find.byKey(_name));
    expect(find.byKey(_name).hitTestable(), findsOneWidget);
    await tester.enterText(find.byKey(_name), '键盘下编辑');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(_name)).controller!.text,
      '键盘下编辑',
    );
    expect(find.byKey(_save).hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byKey(_save)).bottom, lessThanOrEqualTo(480));
    await _capture(tester, 'theme-editor-keyboard.png');
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'individual color tweaks are removed and course palette stays editable',
    (tester) async {
      final l10n = await _openEditor(tester, settings, _profile());
      final position = tester.state<ScrollableState>(_listScroll()).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      for (final role in ThemeVariant.colorKeys) {
        expect(find.byKey(ValueKey('theme-color-$role')), findsNothing);
      }
      expect(
        find.byKey(const ValueKey('theme-material-section')),
        findsNothing,
      );
      for (final id in ['courseCardOpacity', 'courseCardRadius']) {
        final row = find.byKey(ValueKey('theme-slider-row-$id'));
        await _reveal(tester, row);
        expect(row.hitTestable(), findsOneWidget);
      }
      await _openPaletteColor(tester);
      expect(find.byKey(const ValueKey('theme-color-hex')), findsOneWidget);
      final cancel = find.widgetWithText(TextButton, l10n.learningCancel);
      await _sheetReveal(tester, cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      await _openPreview(tester);
      expect(tester.widget(find.byKey(_preview)), isA<AppThemeBackground>());
      await _closePreview(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
