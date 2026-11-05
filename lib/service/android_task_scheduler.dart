import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';

/// 闹钟只保存任务名和 JSON 参数，回调在插件的后台 isolate 执行。
/// 后续定时代码在 [dispatchAndroidTask] 中增加明确的任务分支。
abstract final class AndroidTaskScheduler {
  static const courseTaskId = 4201;
  static const testTaskId = 4202;
  static const widgetSyncTaskId = 4203;
  static const _plansKey = 'android_course_reminder_plans';
  static const _generationKey = 'android_course_reminder_generation';
  static const _testGenerationKey = 'android_notification_test_generation';
  static const notificationChannelId = 'tomorrow_courses';
  static Future<void>? _initializing;
  static Future<void>? _tail;

  static Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object error) {
        _initializing = null;
        throw error;
      });

  static Future<void> _initialize() async {
    // 清除旧版手写 Receiver 的闹钟，避免迁移后重复提醒。
    await const MethodChannel('com.weijx.fzu_assistant/reminders')
        .invokeMethod<void>('cancelLegacy');
    if (!await AndroidAlarmManager.initialize()) {
      throw StateError('无法初始化后台定时任务');
    }
  }

  static Future<void> _serialize(Future<void> Function() work) {
    final previous = _tail;
    final next = previous == null
        ? work()
        : previous.then(
            (_) => work(),
            onError: (Object _, StackTrace _) => work(),
          );
    _tail = next;
    void clear() {
      if (identical(_tail, next)) _tail = null;
    }

    unawaited(
      next.then<void>(
        (_) => clear(),
        onError: (Object _, StackTrace _) => clear(),
      ),
    );
    return next;
  }

  static Future<void> replaceCoursePlans(List<Map<String, Object>> plans) =>
      _serialize(() async {
        await const MethodChannel('com.weijx.fzu_assistant/reminders')
            .invokeMethod<void>('cancelLegacy');
        final sp = await SharedPreferences.getInstance();
        final generation = DateTime.now().microsecondsSinceEpoch.toString();
        await sp.setString(_generationKey, generation);
        await sp.setString(_plansKey, jsonEncode(plans));
        await AndroidAlarmManager.cancel(courseTaskId);
        if (plans.isEmpty) return;
        await initialize();
        await _scheduleNextCourse(plans, generation);
      });

  static Future<void> cancelAll() => _serialize(() async {
    await const MethodChannel('com.weijx.fzu_assistant/reminders')
        .invokeMethod<void>('cancelLegacy');
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_generationKey);
    await sp.remove(_testGenerationKey);
    await sp.remove(_plansKey);
    await AndroidAlarmManager.cancel(courseTaskId);
    await AndroidAlarmManager.cancel(testTaskId);
    final notifications = await notificationPlugin();
    await notifications.cancel(id: courseTaskId);
    await notifications.cancel(id: testTaskId);
  });

  static Future<void> testNotification() => _serialize(() async {
    await initialize();
    final sp = await SharedPreferences.getInstance();
    final generation = DateTime.now().microsecondsSinceEpoch.toString();
    await sp.setString(_testGenerationKey, generation);
    final at = DateTime.now().add(const Duration(minutes: 1));
    await schedule(
      id: testTaskId,
      at: at,
      task: 'notificationTest',
      params: {
        'generation': generation,
        'scheduledAt': at.millisecondsSinceEpoch,
      },
    );
  });

  static DateTime nextWidgetSync(DateTime now, int minutes) {
    final beijing = now.toUtc().add(const Duration(hours: 8));
    var next = DateTime.utc(beijing.year, beijing.month, beijing.day)
        .add(Duration(minutes: minutes.clamp(0, 1439)))
        .subtract(const Duration(hours: 8));
    if (!next.isAfter(now.toUtc())) next = next.add(const Duration(days: 1));
    return next;
  }

  static Future<void> scheduleWidgetSync({
    required String generation,
    required int minutes,
    int? alarmId,
  }) async {
    // This entry is also called from the headless engine. It uses only the
    // registered alarm plugin, without the Activity-only reminder channel.
    if (!await AndroidAlarmManager.initialize()) {
      throw StateError('无法初始化小组件后台同步');
    }
    await schedule(
      id: alarmId ?? widgetSyncTaskId,
      at: nextWidgetSync(DateTime.now(), minutes),
      task: 'widgetSync',
      params: {'generation': generation},
    );
  }

  static Future<void> cancelWidgetSync({int? alarmId}) async {
    await AndroidAlarmManager.cancel(alarmId ?? widgetSyncTaskId);
    if (alarmId != null && alarmId != widgetSyncTaskId) {
      await AndroidAlarmManager.cancel(widgetSyncTaskId);
    }
  }

  static Future<void> schedule({
    required int id,
    required DateTime at,
    required String task,
    Map<String, dynamic> params = const {},
  }) async {
    final ok = await AndroidAlarmManager.oneShotAt(
      at,
      id,
      dispatchAndroidTask,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
      params: {...params, 'task': task},
    );
    if (!ok) throw StateError('无法注册精确闹钟');
    developer.log(
      'Scheduled $task id=$id at=${at.toUtc().toIso8601String()}',
      name: 'AndroidTasks',
    );
  }

  static Future<void> _scheduleNextCourse(
    List<dynamic> plans,
    String generation,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final item in plans) {
      final plan = Map<String, dynamic>.from(item as Map);
      if ((plan['at'] as int) <= now) continue;
      await schedule(
        id: courseTaskId,
        at: DateTime.fromMillisecondsSinceEpoch(plan['at'] as int),
        task: 'courseReminder',
        params: {...plan, 'generation': generation},
      );
      return;
    }
  }

  static Future<FlutterLocalNotificationsPlugin> notificationPlugin() async {
    // 后台引擎和测试环境各自持有 Dart 插件状态，显式注册 Android 实现。
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_course_reminder'),
      ),
    );
    return plugin;
  }
}

@pragma('vm:entry-point')
Future<void> dispatchAndroidTask(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final receivedAt = DateTime.now().toUtc();
  developer.log(
    'Received ${params['task']} id=$id at=${receivedAt.toIso8601String()}',
    name: 'AndroidTasks',
  );
  try {
    if (params['task'] == 'widgetSync') {
      await WidgetSyncService.runBackground(params['generation'] as String?);
      return;
    }
    final sp = await SharedPreferences.getInstance();
    await sp.reload();
    final task = params['task'];
    final key = task == 'courseReminder'
        ? AndroidTaskScheduler._generationKey
        : AndroidTaskScheduler._testGenerationKey;
    if (sp.getString(key) != params['generation']) return;
    String title;
    String body;
    if (task == 'courseReminder') {
      final plans = jsonDecode(
        sp.getString(AndroidTaskScheduler._plansKey) ?? '[]',
      ) as List;
      await AndroidTaskScheduler._scheduleNextCourse(
        plans,
        params['generation'] as String,
      );
      final lateness =
          receivedAt.millisecondsSinceEpoch - (params['at'] as int);
      if (lateness > const Duration(hours: 1).inMilliseconds) return;
      title = params['title'] as String;
      body = params['body'] as String;
    } else if (task == 'notificationTest') {
      title = 'Notification test';
      body =
          'android_alarm_manager_plus executed this Dart task in the background.\n'
          'Scheduled: ${DateTime.fromMillisecondsSinceEpoch(params['scheduledAt'] as int).toUtc().toIso8601String()}\n'
          'Executed: ${receivedAt.toIso8601String()}';
    } else {
      throw StateError('Unknown scheduled task: $task');
    }
    final plugin = await AndroidTaskScheduler.notificationPlugin();
    await sp.reload();
    if (sp.getString(key) != params['generation']) return;
    await plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          AndroidTaskScheduler.notificationChannelId,
          params['title'] as String? ?? 'Tomorrow’s classes',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
    developer.log('Posted notification id=$id', name: 'AndroidTasks');
  } catch (error, stack) {
    developer.log(
      'Background task failed',
      name: 'AndroidTasks',
      error: error,
      stackTrace: stack,
    );
  }
}
