import 'dart:convert';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final requests = <String>[];
  Map<String, String>? device;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    requests.clear();
    device = {'manufacturer': 'Xiaomi', 'brand': 'Redmi'};
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'fzu_username': 'student',
      'fzu_password': 'password',
      'fzu_academic_session': jsonEncode({
        'studentId': 'student',
        'userId': 'cached-identifier',
        'cookies': ['session=test; Path=/'],
      }),
    });
    AndroidAlarmManager.setTestOverrides(
      getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
    );
    messenger.setMockMethodCallHandler(CourseReminderService.channel, (
      call,
    ) async {
      requests.add(call.method);
      if (call.method == 'deviceInfo') return device;
      if (call.method == 'permissions') {
        return {'notifications': true, 'exact': true};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
      call,
    ) async {
      requests.add('alarm:${call.method}');
      return true;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        requests.add('notification:${call.method}');
        return true;
      },
    );
  });
  tearDown(() async {
    await ApiClient.instance.clearSession();
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(CourseReminderService.channel, null);
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      null,
    );
  });

  test('brand matching trims and normalizes known brands without substring guessing', () {
    for (final value in [' Xiaomi ', 'REDMI', 'poco']) {
      expect(
        CourseReminderService.matchesXiaomiDevice(manufacturer: value),
        isTrue,
      );
      expect(CourseReminderService.matchesXiaomiDevice(brand: value), isTrue);
    }
    for (final value in [
      '',
      'Samsung',
      'Google',
      'Xiaomi-compatible',
      'my-poco-phone',
      'mi',
    ]) {
      expect(
        CourseReminderService.matchesXiaomiDevice(
          manufacturer: value,
          brand: value,
        ),
        isFalse,
      );
    }
  });

  for (final brand in ['Xiaomi', 'Samsung']) {
    test(
      '$brand sync retains opt-in and schedules through the Flutter plugins',
      () async {
        device = {'manufacturer': brand, 'brand': brand};
        expect(await ApiClient.instance.restoreCachedSession(), isTrue);
        final sp = await SharedPreferences.getInstance();
        await sp.setString(
          'android_course_reminder_plans',
          '[{"at":9999999999999}]',
        );
        await sp.setString('android_course_reminder_generation', 'old-course');
        await sp.setString('android_notification_test_generation', 'old-test');
        final settings = AppSettings();
        await settings.load();
        settings.courseReminderEnabled.value = true;
        final reminder = CourseReminderService();
        await reminder.sync(settings);
        expect(settings.courseReminderEnabled.value, isTrue);
        expect(sp.getBool('course_reminder_enabled'), isTrue);
        final plans =
            jsonDecode(sp.getString('android_course_reminder_plans')!) as List;
        expect(plans, isNotEmpty);
        expect(plans.length, inInclusiveRange(179, 180));
        expect(
          sp.getString('android_course_reminder_generation'),
          isNot('old-course'),
        );
        expect(
          sp.getString('android_notification_test_generation'),
          'old-test',
        );
        expect(requests, contains('permissions'));
        expect(requests, contains('alarm:Alarm.oneShotAt'));
        expect(requests, isNot(contains('deviceInfo')));
        expect(reminder.error.value, isFalse);
        settings.dispose();
        reminder.error.dispose();
      },
    );
  }

  test(
    'Xiaomi permission actions and one-minute test remain available',
    () async {
      final reminder = CourseReminderService();
      await reminder.requestPermission('requestNotifications');
      await reminder.testNotification();
      expect(requests, contains('requestNotifications'));
      expect(requests, contains('permissions'));
      expect(requests, contains('alarm:Alarm.oneShotAt'));
      expect(requests, isNot(contains('deviceInfo')));
      expect(requests, isNot(contains('alarm:Alarm.cancel')));
      reminder.error.dispose();
    },
  );

  test(
    'one-minute tests still require notification and exact alarm authorization',
    () async {
      messenger.setMockMethodCallHandler(CourseReminderService.channel, (
        call,
      ) async {
        requests.add(call.method);
        if (call.method == 'permissions') {
          return {'notifications': true, 'exact': false};
        }
        return device;
      });
      final reminder = CourseReminderService();
      await expectLater(reminder.testNotification(), throwsStateError);
      expect(requests, contains('permissions'));
      expect(requests, isNot(contains('alarm:Alarm.oneShotAt')));
      reminder.error.dispose();
    },
  );

  test(
    'missing read-only host method keeps legacy and widget-test behavior',
    () async {
      messenger.setMockMethodCallHandler(CourseReminderService.channel, (
        call,
      ) async {
        if (call.method == 'deviceInfo') throw MissingPluginException();
        return null;
      });
      final reminder = CourseReminderService();
      expect(await reminder.isXiaomiDevice(), isFalse);
      reminder.error.dispose();
    },
  );

  test(
    'device-info failures do not gate authorization or scheduling',
    () async {
      messenger.setMockMethodCallHandler(CourseReminderService.channel, (
        call,
      ) async {
        requests.add(call.method);
        if (call.method == 'deviceInfo') {
          throw PlatformException(code: 'device_info_failed');
        }
        if (call.method == 'permissions') {
          return {'notifications': true, 'exact': true};
        }
        return null;
      });
      final reminder = CourseReminderService();
      await expectLater(
        reminder.isXiaomiDevice(),
        throwsA(isA<PlatformException>()),
      );
      final settings = AppSettings();
      await settings.load();
      settings.courseReminderEnabled.value = true;
      expect(await ApiClient.instance.restoreCachedSession(), isTrue);
      requests.clear();
      await reminder.requestPermission('requestNotifications');
      await reminder.sync(settings);
      await reminder.testNotification();
      expect(reminder.error.value, isFalse);
      expect(settings.courseReminderEnabled.value, isTrue);
      expect(requests, contains('requestNotifications'));
      expect(requests, contains('alarm:Alarm.oneShotAt'));
      expect(requests, isNot(contains('deviceInfo')));
      settings.dispose();
      reminder.error.dispose();
    },
  );

  test('other brands keep the permission request path', () async {
    device = {'manufacturer': 'samsung', 'brand': 'samsung'};
    final reminder = CourseReminderService();
    expect(await reminder.isXiaomiDevice(), isFalse);
    await reminder.requestPermission('requestNotifications');
    expect(requests, contains('requestNotifications'));
    reminder.error.dispose();
  });
}
