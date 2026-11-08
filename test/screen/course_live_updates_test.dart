import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/dev/dev_tool.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/service/android_task_scheduler.dart';
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

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    AndroidAlarmManager.setTestOverrides(
      getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
    );
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getNotificationChannels' || 'getActiveNotifications' => [],
        _ => true,
      };
    });
    for (final channel in [
      AndroidPermissionsService.channel,
      CourseReminderService.channel,
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'permissions') {
          return {'notifications': true, 'exact': true};
        }
        return null;
      });
    }
  });
  tearDown(() {
    for (final channel in [
      notifications,
      AndroidPermissionsService.channel,
      CourseReminderService.channel,
      AndroidAlarmManager.channel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets(
    'developer previews post all course states, clear only the preview and open settings',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettings();
      await settings.load();
      await tester.pumpWidget(
        AppSettingsProvider(
          settings: settings,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DevToolPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.where((call) => call.method == 'show'), isEmpty);
      expect(find.text('Allowed by Android'), findsOneWidget);
      final ids = <int>{};
      for (final title in ['Class in progress', 'Class ended', 'Next class']) {
        final tile = find.widgetWithText(ListTile, title);
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        final shown =
            calls.lastWhere((call) => call.method == 'show').arguments as Map;
        expect(shown['title'], title);
        ids.add(shown['id'] as int);
        expect(tester.takeException(), isNull);
      }
      expect(ids, hasLength(1));
      expect(calls.map((call) => call.method), isNot(contains('permissions')));
      final sequence = find.widgetWithText(
        ListTile,
        'Test all styles in 2 minutes',
      );
      await tester.ensureVisible(sequence);
      await tester.tap(sequence);
      await tester.pumpAndSettle();
      expect(
        find.text('Preview started: now, 30s, 60s and 110s'),
        findsOneWidget,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          AndroidTaskScheduler.livePreviewRunKey,
        ),
        isNotNull,
      );
      final alarm =
          calls.lastWhere((call) => call.method == 'Alarm.oneShotAt').arguments
              as List;
      expect(alarm[0], AndroidTaskScheduler.livePreviewTaskId);
      expect((alarm[8] as Map)['task'], 'courseLivePreview');
      final clear = find.widgetWithText(ListTile, 'Clear course preview');
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(
        (calls.lastWhere((call) => call.method == 'cancel').arguments
            as Map)['id'],
        ids.single,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          AndroidTaskScheduler.livePreviewRunKey,
        ),
        isNull,
      );
      final open = find.widgetWithText(ListTile, 'Live Update settings');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(
        (calls.lastWhere((call) => call.method == 'open').arguments
            as Map)['name'],
        'android.permission.POST_PROMOTED_NOTIFICATIONS',
      );
      expect(calls.map((call) => call.method), isNot(contains('deviceInfo')));
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
