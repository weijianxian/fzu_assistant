import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/settings/course_live_updates_settings_page.dart';
import 'package:fzu_assistant/screen/settings/settings_page.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/service/course_live_updates_controller.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  var allowed = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    allowed = true;
    AndroidAlarmManager.setTestOverrides(
      getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
    );
    for (final channel in [
      AndroidAlarmManager.channel,
      notifications,
      CourseReminderService.channel,
      AndroidPermissionsService.channel,
      CourseLiveUpdatesController.channel,
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'permissions' => {'notifications': allowed, 'exact': allowed},
          'getNotificationChannels' => [],
          'getActiveNotifications' => [],
          'readLiveUpdateSnapshot' => {'generation': null, 'snapshot': null},
          _ => true,
        };
      });
    }
  });
  tearDown(() {
    for (final channel in [
      AndroidAlarmManager.channel,
      notifications,
      CourseReminderService.channel,
      AndroidPermissionsService.channel,
      CourseLiveUpdatesController.channel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<AppSettings> mount(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettings();
    await settings.load();
    await tester.pumpWidget(
      AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            AppRoutes.courseLiveUpdates: (_) =>
                const CourseLiveUpdatesSettingsPage(),
          },
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    });
    return settings;
  }

  testWidgets(
    'Android platform settings opens Live Updates and persists its independent switch',
    (tester) async {
      final settings = await mount(tester, const SettingsPage());
      final entry = find.widgetWithText(ListTile, '实况通知');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('课程实况通知'), findsOneWidget);
      expect(settings.courseLiveUpdatesEnabled.value, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(settings.courseLiveUpdatesEnabled.value, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          SpKeys.courseLiveUpdatesEnabled,
        ),
        isTrue,
      );
      expect(settings.courseReminderEnabled.value, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(settings.courseLiveUpdatesEnabled.value, isFalse);
      expect(calls.where((call) => call.method == 'show'), isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'missing notification and alarm permissions leave the switch off',
    (tester) async {
      allowed = false;
      final settings = await mount(
        tester,
        const CourseLiveUpdatesSettingsPage(),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(settings.courseLiveUpdatesEnabled.value, isFalse);
      expect(calls.where((call) => call.method == 'Alarm.oneShotAt'), isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('Live Updates platform entry is absent outside Android', (
    tester,
  ) async {
    await mount(tester, const SettingsPage());
    expect(find.text('实况通知'), findsNothing);
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));
}
