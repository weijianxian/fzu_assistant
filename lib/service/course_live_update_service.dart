import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course_live_update.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/service/android_task_scheduler.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:fzu_assistant/model/course_live_update.dart'
    show CourseLiveUpdatePreview;

/// Android 官方课程实况展示与独立开发者示例；不联网。
abstract final class CourseLiveUpdateService {
  static const notificationId = 4210;
  static const _channelId = 'course_live_updates';
  static const _promotionPermission =
      'android.permission.POST_PROMOTED_NOTIFICATIONS';
  static String? _tickingGeneration;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> promotionEnabled() async {
    if (!supported) return false;
    final plugin = await AndroidTaskScheduler.notificationPlugin();
    return await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()!
            .canPostPromotedNotifications() ??
        false;
  }

  static Future<void> openSettings() =>
      AndroidPermissionsService.openSettings(_promotionPermission);

  /// 三个状态使用相同 ID；活动结束时退出实况，保留可清除的结束通知。
  /// 返回值仅表示应用可请求提升展示，最终展示仍由系统决定。
  static Future<bool> showPreview(CourseLiveUpdatePreview preview) async {
    if (!supported) return false;
    final plugin = await _readyPlugin(requestPermission: true);
    final now = DateTime.now();
    final active = preview != CourseLiveUpdatePreview.ended;
    if (active) {
      final generation = await AndroidTaskScheduler.beginLivePreview(
        now,
        mode: preview.name,
      );
      final promoted = await _show(
        plugin,
        _manualTimeline(now, preview).at(now)!,
        now: now,
      );
      await _startTicker(generation, plugin);
      return promoted;
    }
    await AndroidTaskScheduler.cancelLivePreview();
    final next = preview == CourseLiveUpdatePreview.nextClass;
    final start = next
        ? now.add(const Duration(minutes: 5))
        : now.subtract(Duration(minutes: active ? 20 : 45));
    final end = next
        ? start.add(const Duration(minutes: 45))
        : active
        ? now.add(const Duration(minutes: 25))
        : now;
    return _show(
      plugin,
      CourseLiveUpdateFrame(preview, [
        NextCourseWidgetEntry(
          name: next ? 'College Physics' : 'Advanced Mathematics',
          location: next
              ? 'Teaching Building 2-205'
              : 'Teaching Building 3-301',
          start: start,
          end: end,
          startClass: next ? 3 : 1,
          endClass: next ? 4 : 2,
          week: 1,
        ),
      ]),
      now: now,
    );
  }

  /// Runs a compressed morning with two classes and an afternoon class that
  /// must not be announced when the morning finishes.
  static Future<void> startPreviewSequence() async {
    if (!supported) return;
    await _readyPlugin(requestPermission: true);
    final permissions = await CourseReminderService.instance.permissions();
    if (permissions['exact'] != true) {
      throw StateError('Allow exact alarms in Android settings first');
    }
    final generation = await AndroidTaskScheduler.beginLivePreview(
      DateTime.now(),
    );
    try {
      await runPreviewSequence(generation, scheduleNext: false);
      final plugin = await AndroidTaskScheduler.notificationPlugin();
      await _startTicker(generation, plugin);
    } catch (_) {
      await clearPreview();
      rethrow;
    }
  }

  /// Background callbacks derive the state from the clock. A delayed callback
  /// skips expired stages instead of replaying stale notifications.
  static Future<void> runPreviewSequence(
    String? generation, {
    @visibleForTesting DateTime? now,
    bool animate = false,
    bool scheduleNext = true,
  }) async {
    if (!supported || generation == null) return;
    if (animate && _tickingGeneration == generation) return;
    if (animate) _tickingGeneration = generation;
    try {
      await _runPreview(
        generation,
        now: now,
        animate: animate,
        scheduleNext: scheduleNext,
      );
    } finally {
      if (animate && _tickingGeneration == generation) {
        _tickingGeneration = null;
      }
    }
  }

  static Future<void> _startTicker(
    String generation,
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    if (await android.canScheduleExactNotifications() == true) {
      await AndroidTaskScheduler.schedule(
        id: AndroidTaskScheduler.livePreviewTaskId,
        at: DateTime.now().add(const Duration(seconds: 1)),
        task: 'courseLivePreview',
        params: {'generation': generation},
      );
    } else {
      // Immediate previews also work without exact-alarm permission. The
      // foreground engine can update them while its process remains alive.
      unawaited(runPreviewSequence(generation, animate: true));
    }
  }

  static Future<void> _runPreview(
    String generation, {
    DateTime? now,
    required bool animate,
    required bool scheduleNext,
  }) async {
    final sp = await SharedPreferences.getInstance();
    Future<bool> current() async {
      await sp.reload();
      final raw = sp.getString(AndroidTaskScheduler.livePreviewRunKey);
      return raw != null &&
          (jsonDecode(raw) as Map)['generation'] == generation;
    }

    if (!await current()) return;
    final run = jsonDecode(
      sp.getString(AndroidTaskScheduler.livePreviewRunKey)!,
    ) as Map;
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      run['startedAt'] as int,
      isUtc: true,
    );
    final mode = run['mode'] as String? ?? 'sequence';
    final sequence = mode == 'sequence';
    final timeline = sequence
        ? _previewTimeline(startedAt)
        : _manualTimeline(
            startedAt,
            CourseLiveUpdatePreview.values.byName(mode),
          );
    final finish = sequence
        ? startedAt.add(const Duration(seconds: 110))
        : timeline.courses.last.end;
    if (!(now ?? DateTime.now()).isBefore(
      finish.add(CourseLiveUpdateTimeline.endedLifetime),
    )) {
      return;
    }
    final plugin = await _readyPlugin(requestPermission: false);
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    final exact = await android.canScheduleExactNotifications() == true;
    DateTime? scheduled;
    while (await current()) {
      final instant = now ?? DateTime.now().toUtc();
      if (!instant.isBefore(
        finish.add(CourseLiveUpdateTimeline.endedLifetime),
      )) {
        return;
      }
      final frame = timeline.at(instant);
      if (frame == null) return;
      final next = timeline.nextChangeAfter(instant);
      if (scheduleNext &&
          exact &&
          next != null &&
          next != scheduled &&
          !next.isAfter(finish) &&
          await current()) {
        await AndroidTaskScheduler.schedule(
          id: AndroidTaskScheduler.livePreviewTaskId,
          at: next,
          task: 'courseLivePreview',
          params: {'generation': generation},
        );
        scheduled = next;
      }
      if (!await current()) return;
      await _show(plugin, frame, now: instant);
      if (!animate || frame.state == CourseLiveUpdatePreview.ended) return;
      await Future<void>.delayed(
        sequence ? const Duration(seconds: 1) : const Duration(seconds: 5),
      );
    }
  }

  static CourseLiveUpdateTimeline _manualTimeline(
    DateTime now,
    CourseLiveUpdatePreview preview,
  ) {
    final next = preview == CourseLiveUpdatePreview.nextClass;
    final start = next
        ? now.add(const Duration(minutes: 5))
        : now.subtract(const Duration(minutes: 20));
    return CourseLiveUpdateTimeline([
      NextCourseWidgetEntry(
        name: next ? 'College Physics' : 'Advanced Mathematics',
        location: next ? 'Teaching Building 2-205' : 'Teaching Building 3-301',
        start: start,
        end: start.add(const Duration(minutes: 45)),
        startClass: next ? 3 : 1,
        endClass: next ? 4 : 2,
        week: 1,
      ),
    ]);
  }

  static CourseLiveUpdateTimeline _previewTimeline(DateTime start) {
    NextCourseWidgetEntry course(
      String name,
      String location,
      int firstPeriod,
      int startSeconds,
      int endSeconds,
    ) => NextCourseWidgetEntry(
      name: name,
      location: location,
      start: start.add(Duration(seconds: startSeconds)),
      end: start.add(Duration(seconds: endSeconds)),
      startClass: firstPeriod,
      endClass: firstPeriod + 1,
      week: 1,
    );
    return CourseLiveUpdateTimeline([
      course('Advanced Mathematics', 'Teaching Building 3-301', 1, 0, 30),
      course('College Physics', 'Teaching Building 2-205', 3, 60, 110),
      course('Afternoon course', 'Teaching Building 1-101', 5, 14400, 17100),
    ]);
  }

  static Future<FlutterLocalNotificationsPlugin> _readyPlugin({
    required bool requestPermission,
  }) async {
    final plugin = await AndroidTaskScheduler.notificationPlugin();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    if (await android.areNotificationsEnabled() != true &&
        (!requestPermission ||
            await android.requestNotificationsPermission() != true)) {
      throw StateError('Allow notifications in Android settings first');
    }
    for (final channel
        in await android.getNotificationChannels() ??
            <AndroidNotificationChannel>[]) {
      if (channel.id == _channelId && channel.importance == Importance.none) {
        throw StateError(
          'Allow the Course live updates notification channel in Android settings first',
        );
      }
    }
    return plugin;
  }

  static Future<bool> _show(
    FlutterLocalNotificationsPlugin plugin,
    CourseLiveUpdateFrame frame, {
    required DateTime now,
    int id = notificationId,
    AppLocalizations? l10n,
  }) async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    final promoted = await android.canPostPromotedNotifications() ?? false;
    final active = frame.state != CourseLiveUpdatePreview.ended;
    final target = frame.state == CourseLiveUpdatePreview.nextClass
        ? frame.start
        : frame.end;
    final title = switch (frame.state) {
      CourseLiveUpdatePreview.inProgress =>
        l10n?.courseLiveInProgress ?? 'Class in progress',
      CourseLiveUpdatePreview.ended => l10n?.courseLiveEnded ?? 'Class ended',
      CourseLiveUpdatePreview.nextClass => l10n?.courseLiveNext ?? 'Next class',
    };
    final finished = l10n == null
        ? '${frame.part.label} classes finished'
        : switch (frame.part) {
            CourseDayPart.morning => l10n.courseLiveMorningEnded,
            CourseDayPart.afternoon => l10n.courseLiveAfternoonEnded,
            CourseDayPart.evening => l10n.courseLiveEveningEnded,
          };
    final content = [
      for (final course in frame.courses)
        '${course.name} · ${course.location}\n'
            '${_time(course.start)}–${_time(course.end)} (UTC+8)',
      if (!active) finished,
    ].join('\n');
    final nextClass = frame.state == CourseLiveUpdatePreview.nextClass;
    final body = [
      if (nextClass)
        l10n == null
            ? 'Starts in ${_countdown(frame.start.difference(now))}'
            : l10n.courseLiveStartsInMinutes(
                (frame.start.difference(now).inMilliseconds / 60000).ceil(),
              ),
      content,
    ].join('\n');
    // The system notification survives Dart/background-engine restarts. Read it
    // to distinguish a meaningful change from a progress/countdown tick.
    final previous = (await plugin.getActiveNotifications())
        .where((notification) => notification.id == id)
        .firstOrNull;
    final unchanged =
        previous?.title == title &&
        (nextClass
            ? previous?.body?.endsWith('\n$content') == true
            : previous?.body == content);
    await plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Course live updates',
          channelDescription: 'Course progress and next-class countdowns',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          category: active
              ? AndroidNotificationCategory.progress
              : AndroidNotificationCategory.status,
          subText: l10n == null ? 'Sample course' : null,
          ongoing: active,
          requestPromotedOngoing: active,
          autoCancel: !active,
          onlyAlertOnce: unchanged,
          when: target.millisecondsSinceEpoch,
          showWhen: active,
          usesChronometer: active,
          chronometerCountDown: active,
          timeoutAfter: active
              ? target.difference(now).inMilliseconds
              : CourseLiveUpdateTimeline.endedLifetime.inMilliseconds,
          styleInformation: frame.state == CourseLiveUpdatePreview.inProgress
              ? ProgressStyleInformation([
                  ProgressStyleSegment(
                    frame.end.difference(frame.start).inSeconds,
                  ),
                ], progress: now.difference(frame.start).inSeconds)
              : BigTextStyleInformation(body),
        ),
      ),
    );
    return active && promoted;
  }

  static Future<void> showCourseFrame(
    CourseLiveUpdateFrame frame, {
    required int id,
    required DateTime now,
    required AppLocalizations l10n,
  }) async {
    final plugin = await _readyPlugin(requestPermission: false);
    await _show(plugin, frame, now: now, id: id, l10n: l10n);
  }

  static Future<void> clearPreview() async {
    if (!supported) return;
    await AndroidTaskScheduler.cancelLivePreview();
    final plugin = await AndroidTaskScheduler.notificationPlugin();
    await plugin.cancel(id: notificationId);
  }

  static String _time(DateTime time) {
    final beijing = time.toUtc().add(const Duration(hours: 8));
    return '${beijing.hour.toString().padLeft(2, '0')}:'
        '${beijing.minute.toString().padLeft(2, '0')}';
  }

  static String _countdown(Duration remaining) {
    final total = (remaining.inMilliseconds / 1000).ceil();
    final seconds = total < 0 ? 0 : total;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
