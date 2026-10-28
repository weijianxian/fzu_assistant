import 'dart:async';

import 'package:fzu_assistant/service/android_task_scheduler.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

/// 预生成课程通知，由 android_alarm_manager_plus 在后台 Dart 回调中展示。
class CourseReminderService {
  static final instance = CourseReminderService();
  static const channel = MethodChannel('com.weijx.fzu_assistant/reminders');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final error = ValueNotifier<bool>(false);
  int _revision = 0;

  Future<Map<String, bool>> permissions() async {
    if (!supported) return {'notifications': false, 'exact': false};
    final result = await channel.invokeMapMethod<String, bool>('permissions');
    return result ?? {'notifications': false, 'exact': false};
  }

  Future<void> requestPermission(String permission) async {
    if (supported) await channel.invokeMethod<void>(permission);
  }

  Future<void> cancel() async {
    ++_revision;
    if (supported) await AndroidTaskScheduler.cancelAll();
  }

  Future<void> testNotification() async {
    if (!supported) return;
    final status = await permissions();
    if (status['notifications'] != true || status['exact'] != true) {
      throw StateError(
        'Allow notifications and exact alarms in Settings first',
      );
    }
    await AndroidTaskScheduler.testNotification();
  }

  Future<void> sync(AppSettings settings) async {
    if (!supported) return;
    final revision = ++_revision;
    final account = ApiClient.instance.studentId;
    bool stale() =>
        revision != _revision || account != ApiClient.instance.studentId;
    try {
      if (!settings.courseReminderEnabled.value || account == null) {
        await AndroidTaskScheduler.replaceCoursePlans([]);
        error.value = false;
        return;
      }
      final calendar = await CacheHelper.loadMap(SpKeys.cacheSchoolCalendar);
      final caches = await CacheHelper.loadMap(SpKeys.cacheCoursesMap);
      final holidays = await CacheHelper.loadMap(
        SpKeys.cacheHolidayAdjustmentsMap,
      );
      final locale =
          settings.currentLocale ??
          WidgetsBinding.instance.platformDispatcher.locale;
      final l10n = await AppLocalizations.delegate.load(
        Locale(locale.languageCode == 'zh' ? 'zh' : 'en'),
      );
      final plans = buildPlans(
        settings: settings,
        account: account,
        l10n: l10n,
        calendar: calendar,
        caches: caches,
        holidays: holidays,
        now: DateTime.now().toUtc(),
      );
      if (stale()) return;
      final status = await permissions();
      if (stale()) return;
      await AndroidTaskScheduler.replaceCoursePlans(
        status['notifications'] == true && status['exact'] == true ? plans : [],
      );
      if (!stale()) error.value = false;
    } catch (_) {
      if (!stale()) {
        error.value = true;
        // 失败时不继续使用可能属于旧课表的通知。
        try {
          await AndroidTaskScheduler.replaceCoursePlans([]);
        } catch (_) {
          /* 保留错误状态，由设置页提示重试。 */
        }
      }
    }
  }

  @visibleForTesting
  static List<Map<String, Object>> buildPlans({
    required AppSettings settings,
    required String account,
    required AppLocalizations l10n,
    required Map<String, dynamic> calendar,
    required Map<String, dynamic> caches,
    required Map<String, dynamic> holidays,
    required DateTime now,
  }) {
    final terms = calendar.isEmpty
        ? <CalTerm>[]
        : SchoolCalendar.fromJson(calendar).terms;
    now = now.toUtc();
    final beijing = now.add(const Duration(hours: 8));
    final plans = <Map<String, Object>>[];
    for (var i = 0; i < 180; i++) {
      final day = DateTime.utc(beijing.year, beijing.month, beijing.day + i);
      final fire = day
          .add(Duration(minutes: settings.courseReminderMinutes.value))
          .subtract(const Duration(hours: 8));
      if (!fire.isAfter(now)) continue;
      final tomorrow = day.add(const Duration(days: 1));
      CalTerm? term;
      for (final candidate in terms) {
        final start = DateTime.tryParse(candidate.startDate);
        final end = DateTime.tryParse(candidate.endDate);
        if (start == null || end == null) continue;
        if (!tomorrow.isBefore(
              DateTime.utc(start.year, start.month, start.day),
            ) &&
            !tomorrow.isAfter(DateTime.utc(end.year, end.month, end.day))) {
          term = candidate;
          break;
        }
      }
      var body = l10n.courseReminderUnknown;
      if (term != null && caches[term.term] != null) {
        var courses = ((caches[term.term] as Map)['courses'] as List)
            .map((c) => Course.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList();
        if (settings.west2AdjustmentsEnabled.value) {
          courses = CourseService.applyHolidayAdjustments(
            courses,
            (holidays[term.term] as List?) ?? [],
          );
        }
        final monday = CourseService.getFirstMondayFromTerm(term);
        // 使用 UTC 的年月日计算校历周次，不受设备时区和夏令时影响。
        final offset = monday == null
            ? -1
            : tomorrow
                  .difference(
                    DateTime.utc(monday.year, monday.month, monday.day),
                  )
                  .inDays;
        final week = offset ~/ 7 + 1;
        if (offset >= 0 && week <= CourseService.totalScheduleWeeks) {
          final sessions = CourseSessions.forDay(
            courses: courses,
            week: week,
            weekday: tomorrow.weekday,
            autoAdjust: settings.autoAdjustCourse.value,
            account: account,
            term: term.term,
            hiddenSessions: settings.hiddenCourseSessions.value,
          );
          body = reminderBody(sessions, l10n);
        }
      }
      plans.add({
        'at': fire.millisecondsSinceEpoch,
        'title': l10n.courseReminderTitle,
        'body': body,
      });
    }
    return plans;
  }

  static String reminderBody(
    List<CourseSession> sessions,
    AppLocalizations l10n,
  ) {
    if (sessions.isEmpty) return l10n.courseReminderRest;
    final first = sessions.first.startClass;
    return sessions
        .where((s) => s.startClass == first)
        .map(
          (s) => l10n.courseReminderCourse(
            coursePeriodTimes[first - 1].$1,
            s.course.name,
            s.location,
          ),
        )
        .join('\n');
  }
}
