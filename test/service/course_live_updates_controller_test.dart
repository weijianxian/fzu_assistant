import 'dart:convert';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/service/android_task_scheduler.dart';
import 'package:fzu_assistant/service/course_live_updates_controller.dart';
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
  var exact = true;
  var generation = 'owner';
  var reads = 0;
  var changeDuringRead = false;
  late String snapshot;
  DateTime at(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 11, 8, hour - 8, minute);

  NextCourseWidgetEntry course(
    String name,
    int first,
    int last,
    int startHour,
    int startMinute,
    int endHour,
    int endMinute,
  ) => NextCourseWidgetEntry(
    name: name,
    location: 'Room A',
    start: at(startHour, startMinute),
    end: at(endHour, endMinute),
    startClass: first,
    endClass: last,
    week: 9,
  );

  Map<dynamic, dynamic> shown() =>
      calls.lastWhere((call) => call.method == 'show').arguments as Map;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({
      SpKeys.courseLiveUpdatesEnabled: true,
    });
    calls.clear();
    allowed = exact = true;
    generation = 'owner';
    reads = 0;
    changeDuringRead = false;
    CourseLiveUpdatesController.error.value = false;
    snapshot = jsonEncode(
      NextCourseWidgetSnapshot(
        generatedAt: at(8),
        locale: 'zh',
        days: [
          NextCourseWidgetDay(
            start: at(0),
            known: true,
            courses: [
              course('Morning 1', 1, 2, 8, 20, 10, 0),
              course('Morning 2', 3, 4, 10, 20, 12, 0),
              course('Afternoon', 5, 8, 14, 0, 17, 30),
            ],
          ),
        ],
      ).toJson(),
    );
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
        'areNotificationsEnabled' => allowed,
        'canScheduleExactNotifications' => exact,
        'getNotificationChannels' => [],
        'getActiveNotifications' => [],
        _ => true,
      };
    });
    messenger.setMockMethodCallHandler(CourseLiveUpdatesController.channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method != 'readLiveUpdateSnapshot') return null;
      reads++;
      return {
        'generation': generation,
        'snapshot': changeDuringRead && reads >= 2 ? '$snapshot ' : snapshot,
      };
    });
  });
  tearDown(() {
    for (final channel in [
      notifications,
      AndroidAlarmManager.channel,
      CourseLiveUpdatesController.channel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('real classes refresh progress once a minute and use a separate notification ID', () async {
    final progress = <int>[];
    for (final minute in [0, 1]) {
      calls.clear();
      await CourseLiveUpdatesController.synchronize(now: at(9, minute));
      expect(CourseLiveUpdatesController.error.value, isFalse);
      expect(shown()['id'], CourseLiveUpdatesController.notificationId);
      expect(shown()['title'], '上课中');
      final details = shown()['platformSpecifics'] as Map;
      expect(details['subText'], isNull);
      progress.add((details['styleInformation'] as Map)['progress'] as int);
      final alarm =
          calls
                  .singleWhere((call) => call.method == 'Alarm.oneShotAt')
                  .arguments
              as List;
      expect(alarm[0], AndroidTaskScheduler.courseLiveTaskId);
      expect(alarm[5], at(9, minute + 1).millisecondsSinceEpoch);
      expect((alarm[8] as Map)['task'], 'courseLiveUpdate');
      expect((alarm[8] as Map)['generation'], 'owner');
    }
    expect(progress, [2400, 2460]);
  });

  test('breaks show the next morning class and noon ends rather than waiting for afternoon', () async {
    await CourseLiveUpdatesController.synchronize(now: at(10));
    expect(shown()['title'], '下节课');
    expect(shown()['body'], contains('Morning 2'));
    calls.clear();
    await CourseLiveUpdatesController.synchronize(now: at(12));
    expect(shown()['title'], '课程结束');
    expect(shown()['body'], contains('上午课程已结束'));
    expect(shown()['body'], isNot(contains('Afternoon')));
    final details = shown()['platformSpecifics'] as Map;
    expect(details['ongoing'], isFalse);
    expect(details['requestPromotedOngoing'], isFalse);
    final alarm =
        calls.singleWhere((call) => call.method == 'Alarm.oneShotAt').arguments
            as List;
    expect(alarm[5], at(13, 55).millisecondsSinceEpoch);
    calls.clear();
    await CourseLiveUpdatesController.synchronize(now: at(13, 56));
    expect(shown()['title'], '下节课');
    expect(shown()['body'], contains('Afternoon'));
  });

  test(
    'next-class text and alarm refresh by minute until the exact class start',
    () async {
      for (final minute in [0, 1, 19]) {
        calls.clear();
        await CourseLiveUpdatesController.synchronize(now: at(10, minute));
        expect(CourseLiveUpdatesController.error.value, isFalse);
        expect(shown()['title'], '下节课');
        expect(shown()['body'], startsWith('${20 - minute} 分钟后上课\n'));
        final alarm =
            calls
                    .singleWhere((call) => call.method == 'Alarm.oneShotAt')
                    .arguments
                as List;
        expect(alarm[5], at(10, minute + 1).millisecondsSinceEpoch);
      }
    },
  );

  test(
    'disabled settings cancel only real-course work and never the preview',
    () async {
      await (await SharedPreferences.getInstance()).setBool(
        SpKeys.courseLiveUpdatesEnabled,
        false,
      );
      await CourseLiveUpdatesController.synchronize(now: at(9));
      expect(calls.where((call) => call.method == 'show'), isEmpty);
      expect(
        calls
            .where((call) => call.method == 'cancel')
            .map((call) => (call.arguments as Map)['id']),
        [CourseLiveUpdatesController.notificationId],
      );
      expect(
        calls
            .where((call) => call.method == 'Alarm.cancel')
            .map((call) => (call.arguments as List).first),
        [AndroidTaskScheduler.courseLiveTaskId],
      );
    },
  );

  test('old-account callbacks and snapshots replaced during publication never post', () async {
    generation = 'new-owner';
    await CourseLiveUpdatesController.synchronize(
      expectedGeneration: 'owner',
      now: at(9),
    );
    expect(
      calls.where((call) => call.method == 'show' || call.method == 'cancel'),
      isEmpty,
    );
    calls.clear();
    changeDuringRead = true;
    reads = 0;
    await CourseLiveUpdatesController.synchronize(now: at(9));
    expect(calls.where((call) => call.method == 'show'), isEmpty);
    expect(calls.where((call) => call.method == 'Alarm.oneShotAt'), isEmpty);
  });

  test(
    'missing permissions do not prompt from a background callback',
    () async {
      for (final permissions in [(false, true), (true, false)]) {
        allowed = permissions.$1;
        exact = permissions.$2;
        calls.clear();
        await CourseLiveUpdatesController.synchronize(now: at(9));
        expect(calls.where((call) => call.method == 'show'), isEmpty);
        expect(
          calls.where((call) => call.method == 'Alarm.oneShotAt'),
          isEmpty,
        );
        expect(
          calls.where(
            (call) => call.method == 'requestNotificationsPermission',
          ),
          isEmpty,
        );
      }
    },
  );

  test('expired completion is not replayed and unknown coverage is not announced as free', () async {
    await CourseLiveUpdatesController.synchronize(now: at(12, 15));
    expect(calls.where((call) => call.method == 'show'), isEmpty);
    final raw = jsonDecode(snapshot) as Map<String, dynamic>;
    (raw['days'] as List).first['known'] = false;
    snapshot = jsonEncode(raw);
    calls.clear();
    await CourseLiveUpdatesController.synchronize(now: at(9));
    expect(calls.where((call) => call.method == 'show'), isEmpty);
    expect(calls.where((call) => call.method == 'Alarm.oneShotAt'), isEmpty);
  });
}
