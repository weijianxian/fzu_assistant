import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/android_task_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('one-minute test uses a distinct exact waking background Dart alarm and logout cancels both tasks', () async {
    SharedPreferences.setMockInitialValues({'unrelated': 'keep'});
    AndroidAlarmManager.setTestOverrides(
      getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
    );
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.weijx.fzu_assistant/reminders'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => true,
    );
    final before = DateTime.now().millisecondsSinceEpoch;
    await AndroidTaskScheduler.testNotification();
    final args =
        calls.singleWhere((c) => c.method == 'Alarm.oneShotAt').arguments
            as List;
    expect(args[0], AndroidTaskScheduler.testTaskId);
    expect(args[2], isTrue); // allowWhileIdle
    expect(args[3], isTrue); // exact
    expect(args[4], isTrue); // wakeup
    expect(args[6], isTrue); // rescheduleOnReboot
    expect(args[5], greaterThanOrEqualTo(before + 60000));
    expect((args[8] as Map)['task'], 'notificationTest');
    await AndroidTaskScheduler.cancelAll();
    final canceled = calls
        .where((c) => c.method == 'Alarm.cancel')
        .map((c) => (c.arguments as List).first);
    expect(
      canceled,
      containsAll([
        AndroidTaskScheduler.courseTaskId,
        AndroidTaskScheduler.testTaskId,
      ]),
    );
    expect(
      (await SharedPreferences.getInstance()).getString('unrelated'),
      'keep',
    );
  });
}
