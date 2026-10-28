import 'package:flutter/services.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';

/// Flutter 测试环境没有 Android AlarmManager，模拟原生提醒通道。
void mockReminderChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        AndroidAlarmManager.channel,
        (call) async => true,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async => true,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(CourseReminderService.channel, (call) async {
        if (call.method == 'permissions') {
          return {'notifications': true, 'exact': true};
        }
        return null;
      });
}
