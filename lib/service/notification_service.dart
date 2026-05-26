import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

const _channelId = 'fzu_debug_channel';
const _channelName = '调试通知';

/// AlarmManager 回调（必须是顶层函数，运行在独立 isolate）
@pragma('vm:entry-point')
void _alarmCallback(int id) async {
  await _showNotification(
    id,
    '⏰ AlarmManager 通道',
    '这条通知通过 AlarmManager 精确调度触发',
  );
}

/// 在 isolate 内初始化并显示通知
Future<void> _showNotification(int id, String title, String body) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(_channelId, _channelName),
    ),
  );
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static Future<void> init() async {
    tz.initializeTimeZones();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await AndroidAlarmManager.initialize();
  }

  /// AlarmManager 精确闹钟调度
  static Future<bool> scheduleViaAlarmManager({
    required int id,
    required DateTime when,
  }) async {
    return AndroidAlarmManager.oneShotAt(
      when,
      id,
      _alarmCallback,
      exact: true,
      wakeup: true,
    );
  }

  /// 立即显示通知（调试用）
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName),
      ),
    );
  }
}
