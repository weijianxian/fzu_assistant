import 'dart:convert';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/service/android_task_scheduler.dart';
import 'package:fzu_assistant/service/course_live_update_service.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final activeNotifications = <int, Map<String, Object?>>{};
  var allowed = true;
  var grantOnRequest = true;
  var promoted = true;
  var channelBlocked = false;
  var exactAllowed = true;

  Map<dynamic, dynamic> shown() =>
      calls.lastWhere((call) => call.method == 'show').arguments as Map;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    activeNotifications.clear();
    allowed = true;
    grantOnRequest = true;
    promoted = true;
    channelBlocked = false;
    exactAllowed = true;
    SharedPreferences.setMockInitialValues({'unrelated': 'keep'});
    AndroidAlarmManager.setTestOverrides(
      getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
    );
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    messenger.setMockMethodCallHandler(CourseReminderService.channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'permissions'
          ? {'notifications': allowed, 'exact': exactAllowed}
          : null;
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'show') {
        final args = call.arguments as Map;
        final id = args['id'] as int;
        activeNotifications[id] = {
          'id': id,
          'title': args['title'],
          'body': args['body'],
        };
      } else if (call.method == 'cancel') {
        activeNotifications.remove((call.arguments as Map)['id']);
      }
      return switch (call.method) {
        'areNotificationsEnabled' => allowed,
        'requestNotificationsPermission' => grantOnRequest,
        'canPostPromotedNotifications' => promoted,
        'getActiveNotifications' => activeNotifications.values.toList(),
        'getNotificationChannels' =>
          channelBlocked
              ? [
                  {
                    'id': 'course_live_updates',
                    'name': 'Course live updates',
                    'importance': 0,
                    'showBadge': true,
                    'bypassDnd': false,
                    'playSound': true,
                    'enableVibration': true,
                    'enableLights': false,
                    'ledColor': 0,
                    'audioAttributesUsage': 5,
                  },
                ]
              : [],
        _ => true,
      };
    });
    messenger.setMockMethodCallHandler(AndroidPermissionsService.channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(AndroidPermissionsService.channel, null);
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, null);
    messenger.setMockMethodCallHandler(CourseReminderService.channel, null);
  });

  test('in-progress preview reaches Android with a timed promoted progress notification', () async {
    final before = DateTime.now().millisecondsSinceEpoch;
    expect(
      await CourseLiveUpdateService.showPreview(
        CourseLiveUpdatePreview.inProgress,
      ),
      isTrue,
    );
    final notification = shown();
    expect(notification['title'], 'Class in progress');
    expect(notification['body'], contains('Teaching Building 3-301'));
    final details = notification['platformSpecifics'] as Map;
    expect(details['ongoing'], isTrue);
    expect(details['importance'], 4);
    expect(details['priority'], 1);
    expect(details['onlyAlertOnce'], isFalse);
    expect(details['requestPromotedOngoing'], isTrue);
    expect(details['usesChronometer'], isTrue);
    expect(details['chronometerCountDown'], isTrue);
    expect(details['when'], greaterThanOrEqualTo(before + 80 * 60000));
    expect(details['timeoutAfter'], 200 * 60000);
    final style = details['styleInformation'] as Map;
    expect(style['progress'], 20 * 60);
    final segments = style['segments'] as List;
    expect(segments.map((segment) => segment['length']), [6000, 1200, 6000]);
    expect(segments.map((segment) => segment['id']), [0, 1, 2]);
    expect(segments.first['colorBlue'], isNotNull);
    expect(segments.first['colorBlue'], segments.last['colorBlue']);
    expect(segments[1]['colorBlue'], isNot(segments.first['colorBlue']));
    expect(style['styledByProgress'], isTrue);
    expect(style['points'], isEmpty);
    expect(style.containsKey('progressTrackerIcon'), isFalse);
    expect(
      calls.map((call) => call.method),
      isNot(contains('requestNotificationsPermission')),
    );
  });

  test('all three states replace one notification and completion exits the live state', () async {
    final ids = <int>{};
    for (final preview in CourseLiveUpdatePreview.values) {
      await CourseLiveUpdateService.showPreview(preview);
      final notification = shown();
      ids.add(notification['id'] as int);
      final details = notification['platformSpecifics'] as Map;
      if (preview == CourseLiveUpdatePreview.ended) {
        expect(notification['title'], 'Class ended');
        expect(details['ongoing'], isFalse);
        expect(details['requestPromotedOngoing'], isFalse);
        expect(details['usesChronometer'], isFalse);
        expect(details['autoCancel'], isTrue);
        expect(details['timeoutAfter'], 5 * 60000);
      } else if (preview == CourseLiveUpdatePreview.nextClass) {
        expect(notification['title'], 'Next class');
        expect(notification['body'], contains('College Physics'));
        expect(details['ongoing'], isTrue);
        expect(details['timeoutAfter'], 105 * 60000);
        expect(details['chronometerCountDown'], isTrue);
        expect((details['styleInformation'] as Map)['progress'], 115 * 60);
      }
    }
    expect(ids, hasLength(1));
    await CourseLiveUpdateService.clearPreview();
    expect(
      (calls.lastWhere((call) => call.method == 'cancel').arguments
          as Map)['id'],
      ids.single,
    );
    expect(calls.map((call) => call.method), isNot(contains('cancelAll')));
  });

  test(
    'promotion disabled or unsupported still sends a standard fallback',
    () async {
      promoted = false;
      expect(await CourseLiveUpdateService.promotionEnabled(), isFalse);
      expect(
        await CourseLiveUpdateService.showPreview(
          CourseLiveUpdatePreview.nextClass,
        ),
        isFalse,
      );
      expect(shown()['title'], 'Next class');
    },
  );

  test('notification permission denial never posts a preview', () async {
    allowed = false;
    grantOnRequest = false;
    await expectLater(
      CourseLiveUpdateService.showPreview(CourseLiveUpdatePreview.inProgress),
      throwsStateError,
    );
    expect(
      calls.map((call) => call.method),
      contains('requestNotificationsPermission'),
    );
    expect(calls.map((call) => call.method), isNot(contains('show')));
  });

  test(
    'granting regular notification permission permits an immediate preview',
    () async {
      allowed = false;
      expect(
        await CourseLiveUpdateService.showPreview(
          CourseLiveUpdatePreview.nextClass,
        ),
        isTrue,
      );
      expect(
        calls.map((call) => call.method),
        contains('requestNotificationsPermission'),
      );
      expect(shown()['title'], 'Next class');
    },
  );

  test('a blocked preview channel does not report a successful post', () async {
    channelBlocked = true;
    await expectLater(
      CourseLiveUpdateService.showPreview(CourseLiveUpdatePreview.inProgress),
      throwsStateError,
    );
    expect(calls.map((call) => call.method), isNot(contains('show')));
  });

  test('settings targets the official promotion permission', () async {
    await CourseLiveUpdateService.openSettings();
    final call = calls.single;
    expect(call.method, 'open');
    expect(
      (call.arguments as Map)['name'],
      'android.permission.POST_PROMOTED_NOTIFICATIONS',
    );
  });

  test('two-minute run posts all styles with background alarms and ends the morning', () async {
    await CourseLiveUpdateService.startPreviewSequence();
    final sp = await SharedPreferences.getInstance();
    final run = jsonDecode(
      sp.getString(AndroidTaskScheduler.livePreviewRunKey)!,
    ) as Map;
    final generation = run['generation'] as String;
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      run['startedAt'] as int,
      isUtc: true,
    );
    final id = shown()['id'];
    expect(shown()['title'], 'Class in progress');
    expect(
      (shown()['platformSpecifics'] as Map)['timeoutAfter'],
      inInclusiveRange(108000, 110000),
    );
    for (final (seconds, title, course) in [
      (30, 'Next class', 'College Physics'),
      (60, 'Class in progress', 'College Physics'),
      (110, 'Class ended', 'Morning classes finished'),
    ]) {
      await CourseLiveUpdateService.runPreviewSequence(
        generation,
        now: startedAt.add(Duration(seconds: seconds)),
      );
      expect(shown()['id'], id);
      expect(shown()['title'], title);
      expect(shown()['body'], contains(course));
      expect(shown()['body'], isNot(contains('Afternoon course')));
    }
    final alarms = calls.where((call) => call.method == 'Alarm.oneShotAt');
    expect(alarms, hasLength(3));
    final times = <int>[];
    for (final alarm in alarms) {
      final args = alarm.arguments as List;
      expect(args[0], AndroidTaskScheduler.livePreviewTaskId);
      expect(args[2], isTrue);
      expect(args[3], isTrue);
      expect(args[4], isTrue);
      expect(args[6], isTrue);
      expect((args[8] as Map)['task'], 'courseLivePreview');
      expect((args[8] as Map)['generation'], generation);
      times.add((args[5] as int) - startedAt.millisecondsSinceEpoch);
    }
    expect(times.first, inInclusiveRange(1000, 4000));
    expect(times.skip(1), [60000, 110000]);
    expect((shown()['platformSpecifics'] as Map)['ongoing'], isFalse);
    expect(
      (shown()['platformSpecifics'] as Map)['requestPromotedOngoing'],
      isFalse,
    );
    expect(sp.getString('unrelated'), 'keep');
  });

  test(
    'late callbacks skip expired stages and never replay an afternoon class',
    () async {
      await CourseLiveUpdateService.startPreviewSequence();
      final sp = await SharedPreferences.getInstance();
      final run = jsonDecode(
        sp.getString(AndroidTaskScheduler.livePreviewRunKey)!,
      ) as Map;
      final start = DateTime.fromMillisecondsSinceEpoch(
        run['startedAt'] as int,
      );
      calls.clear();
      await CourseLiveUpdateService.runPreviewSequence(
        run['generation'] as String,
        now: start.add(const Duration(seconds: 90)),
      );
      expect(shown()['title'], 'Class in progress');
      expect(shown()['body'], contains('College Physics'));
      expect(calls.where((call) => call.method == 'show'), hasLength(1));
      calls.clear();
      await CourseLiveUpdateService.runPreviewSequence(
        run['generation'] as String,
        now: start.add(const Duration(hours: 4)),
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'clear, manual previews, restart and logout revoke old sequence callbacks',
    () async {
      Future<String> start() async {
        await CourseLiveUpdateService.startPreviewSequence();
        final sp = await SharedPreferences.getInstance();
        return (jsonDecode(
              sp.getString(AndroidTaskScheduler.livePreviewRunKey)!,
            ) as Map)['generation']
            as String;
      }

      Future<void> assertRevoked(String generation) async {
        calls.clear();
        await CourseLiveUpdateService.runPreviewSequence(generation);
        expect(calls, isEmpty);
      }

      var old = await start();
      await CourseLiveUpdateService.clearPreview();
      await assertRevoked(old);
      old = await start();
      await CourseLiveUpdateService.showPreview(
        CourseLiveUpdatePreview.nextClass,
      );
      await assertRevoked(old);
      old = await start();
      await start();
      await assertRevoked(old);
      old = await start();
      await AndroidTaskScheduler.cancelAll();
      expect(
        (await SharedPreferences.getInstance()).getString(
          AndroidTaskScheduler.livePreviewRunKey,
        ),
        isNull,
      );
      await assertRevoked(old);
    },
  );

  test('sequence requires exact alarms; background callbacks never prompt for permission', () async {
    exactAllowed = false;
    await expectLater(
      CourseLiveUpdateService.startPreviewSequence(),
      throwsStateError,
    );
    expect(calls.where((call) => call.method == 'Alarm.oneShotAt'), isEmpty);
    exactAllowed = true;
    await CourseLiveUpdateService.startPreviewSequence();
    final sp = await SharedPreferences.getInstance();
    final run = jsonDecode(
      sp.getString(AndroidTaskScheduler.livePreviewRunKey)!,
    ) as Map;
    calls.clear();
    allowed = false;
    await expectLater(
      CourseLiveUpdateService.runPreviewSequence(run['generation'] as String),
      throwsStateError,
    );
    expect(
      calls.map((call) => call.method),
      isNot(contains('requestNotificationsPermission')),
    );
    expect(calls.where((call) => call.method == 'show'), isEmpty);
  });

  test('progress advances with the clock without changing its deadline or notification ID', () async {
    await CourseLiveUpdateService.startPreviewSequence();
    final sp = await SharedPreferences.getInstance();
    final run = jsonDecode(
      sp.getString(AndroidTaskScheduler.livePreviewRunKey)!,
    ) as Map;
    final start = DateTime.fromMillisecondsSinceEpoch(run['startedAt'] as int);
    final progress = <int>[];
    final deadlines = <int>{};
    final ids = <int>{};
    final ticks = [2, 12, 13, 15, 16, 22];
    for (final seconds in ticks) {
      await CourseLiveUpdateService.runPreviewSequence(
        run['generation'] as String,
        now: start.add(Duration(seconds: seconds)),
      );
      final notification = shown();
      expect(notification['title'], 'Class in progress');
      final details = notification['platformSpecifics'] as Map;
      progress.add((details['styleInformation'] as Map)['progress'] as int);
      deadlines.add(details['when'] as int);
      ids.add(notification['id'] as int);
      expect(details['onlyAlertOnce'], isTrue);
    }
    expect(progress, ticks);
    expect(deadlines, hasLength(1));
    expect(ids, {CourseLiveUpdateService.notificationId});
    await CourseLiveUpdateService.clearPreview();
  });

  test('the whole-morning bar advances across breaks and the second class without resetting', () async {
    await CourseLiveUpdateService.startPreviewSequence();
    final sp = await SharedPreferences.getInstance();
    final run = jsonDecode(
      sp.getString(AndroidTaskScheduler.livePreviewRunKey)!,
    ) as Map;
    final start = DateTime.fromMillisecondsSinceEpoch(run['startedAt'] as int);
    final generation = run['generation'] as String;
    final ids = <int>{};
    final nextDeadlines = <int>{};
    for (final seconds in [0, 30, 40, 50, 60, 61, 110]) {
      await CourseLiveUpdateService.runPreviewSequence(
        generation,
        now: start.add(Duration(seconds: seconds)),
      );
      final notification = shown();
      ids.add(notification['id'] as int);
      final details = notification['platformSpecifics'] as Map;
      if (seconds < 110) {
        final style = details['styleInformation'] as Map;
        expect(style['progress'], seconds);
        expect(
          (style['segments'] as List).map((segment) => segment['length']),
          [30, 30, 50],
        );
        expect(style['points'], isEmpty);
        expect(style.containsKey('progressTrackerIcon'), isFalse);
        expect(details['timeoutAfter'], (110 - seconds) * 1000);
      }
      if (seconds >= 30 && seconds < 60) {
        expect(
          notification['body'],
          startsWith('Starts in 00:${60 - seconds}\n'),
        );
        nextDeadlines.add(details['when'] as int);
      }
      expect(
        details['onlyAlertOnce'],
        ![30, 60, 110].contains(seconds),
        reason: 'Only a stage/content change should alert at ${seconds}s',
      );
    }
    expect(nextDeadlines, {
      start.add(const Duration(seconds: 60)).millisecondsSinceEpoch,
    });
    expect(ids, {CourseLiveUpdateService.notificationId});
    await CourseLiveUpdateService.clearPreview();
  });

  test('other platforms never invoke Android channels', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(await CourseLiveUpdateService.promotionEnabled(), isFalse);
    expect(
      await CourseLiveUpdateService.showPreview(
        CourseLiveUpdatePreview.inProgress,
      ),
      isFalse,
    );
    await CourseLiveUpdateService.clearPreview();
    await CourseLiveUpdateService.startPreviewSequence();
    await CourseLiveUpdateService.runPreviewSequence('unavailable');
    await CourseLiveUpdateService.openSettings();
    expect(calls, isEmpty);
  });
}
