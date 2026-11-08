import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course_live_update.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/service/android_task_scheduler.dart';
import 'package:fzu_assistant/service/course_live_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uses the accepted widget snapshot, whose courses already include adjustments,
/// hidden sessions and custom courses. Never fetches academic data.
abstract final class CourseLiveUpdatesController {
  static const notificationId = 4212;
  static const channel = MethodChannel(
    'com.weijx.fzu_assistant/widget_background',
  );
  static final error = ValueNotifier(false);

  static Future<void> synchronize({
    String? expectedGeneration,
    @visibleForTesting DateTime? now,
  }) async {
    if (!CourseLiveUpdateService.supported) return;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.reload();
      if (sp.getBool(SpKeys.courseLiveUpdatesEnabled) != true) {
        await cancel();
        error.value = false;
        return;
      }
      Future<Map<String, dynamic>?> read() =>
          channel.invokeMapMethod<String, dynamic>('readLiveUpdateSnapshot');
      final source = await read();
      final generation = source?['generation'] as String?;
      // A callback from the departing account must not cancel or overwrite the
      // newly signed-in account's notification.
      if (expectedGeneration != null && generation != expectedGeneration) {
        return;
      }
      if (generation == null || source?['snapshot'] is! String) {
        await cancel();
        error.value = false;
        return;
      }
      final snapshotJson = source!['snapshot'] as String;
      final schedule = CourseLiveUpdateSchedule.fromJson(
        Map<String, dynamic>.from(jsonDecode(snapshotJson) as Map),
      );
      final plugin = await AndroidTaskScheduler.notificationPlugin();
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      if (await android.areNotificationsEnabled() != true ||
          await android.canScheduleExactNotifications() != true) {
        await cancel();
        error.value = false;
        return;
      }
      final instant = (now ?? DateTime.now()).toUtc();
      final frame = schedule.at(instant);
      var next = schedule.nextChangeAfter(instant);
      if (frame != null && frame.state != CourseLiveUpdatePreview.ended) {
        final progressAt = instant.add(const Duration(minutes: 1));
        if (next == null || progressAt.isBefore(next)) next = progressAt;
      }
      Future<bool> current() async {
        await sp.reload();
        if (sp.getBool(SpKeys.courseLiveUpdatesEnabled) != true) return false;
        final latest = await read();
        return latest?['generation'] == generation &&
            latest?['snapshot'] == snapshotJson;
      }

      final locale = schedule.locale == 'system'
          ? WidgetsBinding.instance.platformDispatcher.locale.languageCode
          : schedule.locale;
      final l10n = await AppLocalizations.delegate.load(
        Locale(locale == 'zh' ? 'zh' : 'en'),
      );
      if (!await current()) return;
      if (next != null) {
        if (!await AndroidAlarmManager.initialize()) {
          throw StateError('Cannot initialize course Live Update alarms');
        }
        await AndroidTaskScheduler.schedule(
          id: AndroidTaskScheduler.courseLiveTaskId,
          at: next,
          task: 'courseLiveUpdate',
          params: {'generation': generation},
        );
      } else {
        await AndroidAlarmManager.cancel(AndroidTaskScheduler.courseLiveTaskId);
      }
      if (!await current()) return;
      if (frame == null) {
        await plugin.cancel(id: notificationId);
      } else {
        await CourseLiveUpdateService.showCourseFrame(
          frame,
          id: notificationId,
          now: instant,
          l10n: l10n,
        );
      }
      error.value = false;
    } on MissingPluginException {
      // Optional bridge is absent on older test hosts.
    } catch (_) {
      error.value = true;
    }
  }

  static Future<void> cancel() async {
    if (!CourseLiveUpdateService.supported) return;
    await AndroidAlarmManager.cancel(AndroidTaskScheduler.courseLiveTaskId);
    final plugin = await AndroidTaskScheduler.notificationPlugin();
    await plugin.cancel(id: notificationId);
  }
}

/// Minimal decoding of the credential-free native snapshot.
class CourseLiveUpdateSchedule {
  CourseLiveUpdateSchedule({required this.days, this.locale = 'system'});

  final List<({DateTime day, CourseLiveUpdateTimeline timeline})> days;
  final String locale;

  factory CourseLiveUpdateSchedule.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['signedIn'] != true) {
      return CourseLiveUpdateSchedule(days: []);
    }
    final days = <({DateTime day, CourseLiveUpdateTimeline timeline})>[];
    for (final raw in json['days'] as List? ?? []) {
      final day = raw as Map;
      if (day['known'] != true) continue;
      days.add((
        day: DateTime.fromMillisecondsSinceEpoch(
          day['start'] as int,
          isUtc: true,
        ),
        timeline: CourseLiveUpdateTimeline([
          for (final raw in day['courses'] as List)
            NextCourseWidgetEntry(
              name: (raw as Map)['name'] as String,
              location: raw['location'] as String,
              start: DateTime.fromMillisecondsSinceEpoch(
                raw['start'] as int,
                isUtc: true,
              ),
              end: DateTime.fromMillisecondsSinceEpoch(
                raw['end'] as int,
                isUtc: true,
              ),
              startClass: raw['startClass'] as int,
              endClass: raw['endClass'] as int,
              week: raw['week'] as int? ?? 1,
            ),
        ]),
      ));
    }
    return CourseLiveUpdateSchedule(
      days: days,
      locale: json['locale'] as String? ?? 'system',
    );
  }

  CourseLiveUpdateFrame? at(DateTime now) {
    for (final day in days) {
      if (!now.isBefore(day.day) &&
          now.isBefore(day.day.add(const Duration(days: 1)))) {
        return day.timeline.at(now);
      }
    }
    return null;
  }

  DateTime? nextChangeAfter(DateTime now) {
    final changes = [
      for (final day in days)
        if (day.timeline.nextChangeAfter(now) case final DateTime next) next,
    ]..sort();
    return changes.firstOrNull;
  }
}
