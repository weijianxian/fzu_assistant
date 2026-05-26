import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/constants/time_slots.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _idBase = 3000;
const _channelId = 'fzu_early_class';
const _channelName = '早课提醒';
const _spKeyEnabled = 'early_class_enabled';
const _spKeyMinutes = 'early_class_minutes';
const _spKeyFirstMonday = 'early_class_first_monday';
const _spKeyTerm = 'early_class_term';
const _spKeySkipWeekend = 'early_class_skip_weekend';

const _weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 闹钟回调（独立 isolate，不能用单例）
@pragma('vm:entry-point')
void _alarmCallback(int id) async {
  final alarmWeekday = id - _idBase;

  final sp = await SharedPreferences.getInstance();
  final skipWeekend = sp.getBool(_spKeySkipWeekend) ?? true;
  final fmStr = sp.getString(_spKeyFirstMonday);
  final term = sp.getString(_spKeyTerm);
  if (fmStr == null || term == null) return;

  final firstMonday = DateTime.parse(fmStr);
  final currentWeek = _getWeek(firstMonday);
  if (currentWeek < 1) return;

  // 明天的 weekday 和周次
  final targetWeekday = alarmWeekday == 7 ? 1 : alarmWeekday + 1;
  final targetWeek = alarmWeekday >= 5 ? currentWeek + 1 : currentWeek;

  // 周末跳过
  if (skipWeekend && targetWeekday >= 6) {
    _scheduleNext(alarmWeekday, sp);
    return;
  }

  final courses = await _loadCourses(term);
  final firstClass = _findFirstClass(courses, targetWeek, targetWeekday);

  final dayName = _weekdays[targetWeekday];
  String title;
  String body;
  if (firstClass != null) {
    final slot = timeSlots[firstClass.$2 - 1];
    title = '📚 $dayName有课';
    body = '第一节课：${firstClass.$1}\n${slot.$1}-${slot.$2} ${firstClass.$3}';
  } else {
    title = '🎉 $dayName没课';
    body = '明天没有课程安排，好好休息吧';
  }

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

  _scheduleNext(alarmWeekday, sp);
}

/// 闹钟触发后自动调度下一天
void _scheduleNext(int alarmWeekday, SharedPreferences sp) {
  final nextWeekday = alarmWeekday == 7 ? 1 : alarmWeekday + 1;
  final skipWeekend = sp.getBool(_spKeySkipWeekend) ?? true;
  if (skipWeekend && nextWeekday >= 6) return;

  final now = DateTime.now();
  final daysToAdd = nextWeekday - now.weekday;
  final targetDate = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: daysToAdd <= 0 ? daysToAdd + 7 : daysToAdd));

  final fmStr = sp.getString(_spKeyFirstMonday);
  final term = sp.getString(_spKeyTerm);
  if (fmStr == null || term == null) return;

  final firstMonday = DateTime.parse(fmStr);
  final targetWeek = _getWeekFromTarget(firstMonday, targetDate);
  if (targetWeek < 1 || targetWeek > 19) return;

  CacheHelper.loadForKey<List<Course>>(
    SpKeys.cacheCoursesMap,
    term,
    (json) => (json as List).map((e) => Course.fromJson(e)).toList(),
  ).then((courses) {
    if (courses == null) return;
    _scheduleAlarmForDay(courses, targetWeek, nextWeekday, targetDate, sp);
  });
}

/// 为某天设置闹钟：闹钟时间 = 今天最后一节课结束 - N 分钟
/// 无课时用默认最后一节下课时间
void _scheduleAlarmForDay(
  List<Course> courses,
  int week,
  int weekday,
  DateTime date,
  SharedPreferences sp,
) {
  final minutes = sp.getInt(_spKeyMinutes) ?? 10;
  final lastEnd = _findLastClassEnd(courses, week, weekday);
  final endStr = lastEnd ?? timeSlots.last.$2;
  final parts = endStr.split(':');
  final alarmTime = DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  ).subtract(Duration(minutes: minutes));

  if (alarmTime.isAfter(DateTime.now())) {
    AndroidAlarmManager.oneShotAt(
      alarmTime,
      _idBase + weekday,
      _alarmCallback,
      exact: true,
      wakeup: true,
    );
  }
}

int _getWeek(DateTime firstMonday) {
  return (DateTime.now().difference(firstMonday).inDays / 7).floor() + 1;
}

int _getWeekFromTarget(DateTime firstMonday, DateTime target) {
  return (target.difference(firstMonday).inDays / 7).floor() + 1;
}

Future<List<Course>> _loadCourses(String term) async {
  final result = await CacheHelper.loadForKey<List<Course>>(
    SpKeys.cacheCoursesMap,
    term,
    (json) => (json as List).map((e) => Course.fromJson(e)).toList(),
  );
  return result ?? [];
}

/// 找某天第一节课
(String, int, String)? _findFirstClass(
  List<Course> courses,
  int week,
  int weekday,
) {
  String? bestName;
  int bestStart = 999;
  String? bestLocation;

  for (final c in courses) {
    for (final r in c.scheduleRules) {
      if (r.weekday != weekday) continue;
      if (week < r.startWeek || week > r.endWeek) continue;
      if (r.single && week.isEven) continue;
      if (r.double && week.isOdd) continue;
      if (r.startClass < bestStart) {
        bestStart = r.startClass;
        bestName = c.name;
        bestLocation = r.location;
      }
    }
  }

  if (bestName == null) return null;
  return (bestName, bestStart, bestLocation ?? '');
}

/// 找某天最后一节课的结束时间（如 "17:30"），无课返回 null
String? _findLastClassEnd(List<Course> courses, int week, int weekday) {
  int bestEnd = 0;

  for (final c in courses) {
    for (final r in c.scheduleRules) {
      if (r.weekday != weekday) continue;
      if (week < r.startWeek || week > r.endWeek) continue;
      if (r.single && week.isEven) continue;
      if (r.double && week.isOdd) continue;
      if (r.endClass > bestEnd) bestEnd = r.endClass;
    }
  }

  if (bestEnd == 0) return null;
  return timeSlots[bestEnd - 1].$2;
}

class EarlyClassReminderService {
  static bool _enabled = false;
  static int _minutesBefore = 10;
  static bool _skipWeekend = true;
  static String? _currentTerm;
  static DateTime? _firstMonday;

  static bool get isEnabled => _enabled;
  static int get minutesBefore => _minutesBefore;
  static bool get skipWeekend => _skipWeekend;
  static String? get currentTerm => _currentTerm;
  static DateTime? get firstMonday => _firstMonday;

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _enabled = sp.getBool(_spKeyEnabled) ?? false;
    _minutesBefore = sp.getInt(_spKeyMinutes) ?? 10;
    _skipWeekend = sp.getBool(_spKeySkipWeekend) ?? true;
    final fmStr = sp.getString(_spKeyFirstMonday);
    _firstMonday = fmStr != null ? DateTime.tryParse(fmStr) : null;
    _currentTerm = sp.getString(_spKeyTerm);
  }

  static Future<void> setEnabled(
    bool enabled, {
    String? term,
    DateTime? firstMonday,
  }) async {
    _enabled = enabled;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_spKeyEnabled, enabled);

    if (enabled) {
      if (term != null) {
        _currentTerm = term;
        await sp.setString(_spKeyTerm, term);
      }
      if (firstMonday != null) {
        _firstMonday = firstMonday;
        await sp.setString(_spKeyFirstMonday, firstMonday.toIso8601String());
      }
      await scheduleForWeek();
    } else {
      await cancelAll();
    }
  }

  static Future<void> setMinutesBefore(int minutes) async {
    _minutesBefore = minutes.clamp(0, 20);
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_spKeyMinutes, _minutesBefore);
    if (_enabled) await scheduleForWeek();
  }

  static Future<void> setSkipWeekend(bool skip) async {
    _skipWeekend = skip;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_spKeySkipWeekend, skip);
    if (_enabled) await scheduleForWeek();
  }

  /// 为本周剩余天调度（有课无课都调度闹钟）
  static Future<void> scheduleForWeek() async {
    if (!_enabled || _currentTerm == null || _firstMonday == null) return;

    final courses = await _loadCourses(_currentTerm!);
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentWeek = _getWeek(_firstMonday!);
    if (currentWeek < 1 || currentWeek > 19) return;

    for (var wd = now.weekday; wd <= 7; wd++) {
      // 明天是周末且开启跳过
      final targetWd = wd == 7 ? 1 : wd + 1;
      if (_skipWeekend && targetWd >= 6) continue;

      final daysToAdd = wd - now.weekday;
      final targetDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: daysToAdd));
      _scheduleAlarmForDay(courses, currentWeek, wd, targetDate, sp);
    }
  }

  /// 为下一周全部天调度
  static Future<void> scheduleForNextWeek() async {
    if (!_enabled || _currentTerm == null || _firstMonday == null) return;

    final courses = await _loadCourses(_currentTerm!);
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final nextWeek = _getWeek(_firstMonday!) + 1;
    if (nextWeek < 1 || nextWeek > 19) {
      await cancelAll();
      return;
    }

    final daysToMonday = now.weekday == 7 ? 1 : 7 - now.weekday + 1;
    final nextMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysToMonday));

    for (var wd = 1; wd <= 5; wd++) {
      if (_skipWeekend) {
        final nextDayWd = wd == 5 ? 6 : wd + 1;
        if (nextDayWd >= 6) continue;
      }
      final targetDate = nextMonday.add(Duration(days: wd - 1));
      _scheduleAlarmForDay(courses, nextWeek, wd, targetDate, sp);
    }
  }

  static Future<void> cancelAll() async {
    for (var wd = 1; wd <= 7; wd++) {
      await AndroidAlarmManager.cancel(_idBase + wd);
    }
  }

  static Future<void> rescheduleIfNeeded() async {
    if (!_enabled || _currentTerm == null || _firstMonday == null) return;
    await scheduleForWeek();
  }
}
