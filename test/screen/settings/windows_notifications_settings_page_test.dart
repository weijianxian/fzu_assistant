import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/screen/settings/windows_notifications_settings_page.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/windows_course_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/reveal_widget.dart';
import '../../fixtures/windows_capture_fonts.dart';

class _Backend implements WindowsToastBackend {
  @override
  Future<void> initialize(Future<void> Function() onActivate) async {}
  @override
  Future<void> show(WindowsCourseToast toast) async {}
  @override
  Future<void> update(WindowsCourseToast toast) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppSettings settings;
  late WindowsCourseNotifications notifications;
  late AppLocalizations l10n;
  var loads = 0;
  final captureKey = GlobalKey();
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  setUpAll(
    () => loadWindowsSettingsCaptureFonts(
      capture: const String.fromEnvironment('WINDOWS_NOTIFICATIONS_CAPTURE_DIR')
          .isNotEmpty,
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = AppSettings();
    await settings.load();
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    loads = 0;
    notifications = WindowsCourseNotifications(
      backend: _Backend(),
      account: () => 'student',
      sessionFence: () =>
          () => true,
      isSupported: () => true,
      load: (_, _, now) async {
        loads++;
        return WindowsCourseNotificationData(
          snapshot: NextCourseWidgetSnapshot(generatedAt: now, days: []),
          reminders: [],
          l10n: l10n,
          liveEnabled: settings.courseLiveUpdatesEnabled.value,
        );
      },
    );
  });
  tearDown(() async {
    await notifications.shutdown();
    settings.dispose();
  });

  void settingsTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await notifications.shutdown();
        await tester.pump();
      }
    }, variant: windows);
  }

  Future<void> render(
    WidgetTester tester, {
    String language = 'zh',
    bool dark = false,
    double scale = 1,
    bool liveUpdates = false,
  }) async {
    await tester.pumpWidget(
      AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: dark ? settings.darkTheme : settings.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: captureKey,
            child: WindowsNotificationsSettingsPage(
              notifications: notifications,
              liveUpdates: liveUpdates,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    const directory = String.fromEnvironment(
      'WINDOWS_NOTIFICATIONS_CAPTURE_DIR',
    );
    if (directory.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$directory/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } finally {
        image.dispose();
      }
    });
  }

  settingsTest(
    'Windows reminder settings keep the first-class switch and time only',
    (tester) async {
      tester.view.physicalSize = const Size(960, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await render(tester);
      expect(find.text(l10n.courseReminderSettings), findsOneWidget);
      expect(find.text(l10n.reminderExactPermission), findsNothing);
      expect(find.text(l10n.reminderNotificationPermission), findsNothing);
      expect(find.text(l10n.courseReminderTitle), findsOneWidget);
      expect(find.text(l10n.reminderTime), findsOneWidget);
      expect(find.text(l10n.windowsCourseStages), findsNothing);
      final before = loads;
      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.courseReminderTitle),
      );
      await tester.pumpAndSettle();
      expect(settings.courseReminderEnabled.value, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          SpKeys.courseReminderEnabled,
        ),
        isTrue,
      );
      expect(loads, greaterThan(before));
      expect(tester.takeException(), isNull);
      await capture(tester, 'reminder-zh-light');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  settingsTest('Windows live settings keep a separate real switch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(tester, liveUpdates: true);
    expect(find.text(l10n.courseLiveUpdates), findsOneWidget);
    expect(find.text(l10n.courseReminderTitle), findsNothing);
    expect(find.text(l10n.reminderTime), findsNothing);
    expect(find.text(l10n.windowsNotificationsNext), findsNothing);
    expect(find.text(l10n.reminderExactPermission), findsNothing);
    final before = loads;
    await tester.tap(
      find.widgetWithText(SwitchListTile, l10n.windowsCourseStages),
    );
    await tester.pumpAndSettle();
    expect(settings.courseLiveUpdatesEnabled.value, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        SpKeys.courseLiveUpdatesEnabled,
      ),
      isTrue,
    );
    expect(loads, greaterThan(before));
    expect(tester.takeException(), isNull);
    await capture(tester, 'live-zh-light');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  settingsTest(
    'compact English dark large-text page scrolls without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(480, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await render(
        tester,
        language: 'en',
        dark: true,
        scale: 1.5,
        liveUpdates: true,
      );
      final english = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(english.courseLiveUpdates), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'live-en-dark-large');
      await revealWidget(
        tester,
        find.text(english.windowsNotificationsRefresh),
      );
      expect(
        find.text(english.windowsNotificationsRefresh).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        greaterThan(0),
      );
      final before = loads;
      await tester.tap(find.text(english.windowsNotificationsRefresh));
      await tester.pumpAndSettle();
      expect(loads, greaterThan(before));
      expect(tester.takeException(), isNull);
      await capture(tester, 'live-en-dark-large-bottom');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
