import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/windows_background_settings_page.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/desktop_window.dart';
import 'package:fzu_assistant/service/windows_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/windows_background.dart';
import '../../fixtures/windows_capture_fonts.dart';

Future<void> _capture(WidgetTester tester, String filename) async {
  const directory = String.fromEnvironment('WINDOWS_BACKGROUND_CAPTURE_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('windows-background-capture')),
  );
  await tester.runAsync(() async {
    final bitmap = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$filename').writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      bitmap.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);
  late FakeBackgroundWindow native;
  late DesktopWindow window;
  late FakeBackgroundTray tray;
  late WindowsBackgroundService service;

  setUpAll(() async {
    await loadWindowsSettingsCaptureFonts(
      capture: const String.fromEnvironment('WINDOWS_BACKGROUND_CAPTURE_DIR')
          .isNotEmpty,
    );
  });

  void backgroundTest(
    String description,
    Future<void> Function(WidgetTester) body, {
    TargetPlatformVariant? variant,
    bool isSupported = true,
  }) {
    testWidgets(description, (tester) async {
      // Keep the service's cached futures and the widget interactions in the
      // same fake async zone. setUp runs outside testWidgets' fake clock.
      SharedPreferences.setMockInitialValues({});
      native = FakeBackgroundWindow();
      window = DesktopWindow.forTesting(native);
      tray = FakeBackgroundTray();
      service = WindowsBackgroundService.forTesting(
        window: window,
        tray: tray,
        isSupported: isSupported,
      );
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        await tester.pump();
        window.dispose();
      }
    }, variant: variant ?? windows);
  }

  Widget app({
    String locale = 'zh',
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) => MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildTheme(Colors.teal, brightness: brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: RepaintBoundary(
      key: const ValueKey('windows-background-capture'),
      child: WindowsBackgroundSettingsPage(service: service),
    ),
  );

  Future<void> enableBackground(WidgetTester tester) async {
    expect(service.initialized, isTrue);
    expect(service.busy, isFalse);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
  }

  backgroundTest('opt-in control persists and exposes tray status', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 720);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WindowsBackgroundSettingsPage)),
    )!;
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.text(l10n.windowsBackgroundDisabled), findsOneWidget);
    await enableBackground(tester);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(find.text(l10n.windowsBackgroundReady), findsOneWidget);
    expect(tray.labels!.showWindow, l10n.windowsBackgroundRestore);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        SpKeys.windowsCloseToTray,
      ),
      isTrue,
    );
    await _capture(tester, 'windows-background-ready-zh.png');
    expect(tester.takeException(), isNull);
  });

  backgroundTest(
    'failed opt-in keeps control off and retry attempts same action',
    (tester) async {
      tray.creationFails = true;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(WindowsBackgroundSettingsPage)),
      )!;
      await enableBackground(tester);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(find.text(l10n.windowsBackgroundFailed), findsOneWidget);
      expect(native.isVisible, isTrue);
      tray.creationFails = false;
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();
      expect(service.enabled, isTrue);
      expect(find.text(l10n.windowsBackgroundReady), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  backgroundTest('compact dark layout supports English and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(locale: 'en', brightness: Brightness.dark, textScale: 1.5),
    );
    await tester.pumpAndSettle();
    expect(find.text('Background activity'), findsOneWidget);
    expect(find.text('Closing the window quits the app'), findsOneWidget);
    await enableBackground(tester);
    expect(tray.labels!.showWindow, 'Show window');
    await _capture(tester, 'windows-background-dark-en-large-text.png');
    expect(tester.takeException(), isNull);
  });

  backgroundTest(
    'unsupported platform exposes no background control',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('后台托盘仅支持 Windows'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(native.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    isSupported: false,
  );
}
