import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/calendar_sync.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/service/android_task_scheduler.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetSyncStatus {
  const WidgetSyncStatus({
    this.exactAllowed = false,
    this.running = false,
    this.failed = false,
    this.lastSuccess,
    this.nextAt,
  });

  final bool exactAllowed, running, failed;
  final DateTime? lastSuccess, nextAt;
}

/// The alarm executes in its own Dart engine. Native commits fence both account
/// changes and edits made while network requests are in flight.
class WidgetSyncService {
  WidgetSyncService({
    Future<bool> Function(String generation)? refresh,
    DateTime Function()? now,
  }) : _refresh = refresh ?? _refreshInIsolate,
       _now = now ?? DateTime.now;

  static final instance = WidgetSyncService();
  static const channel = MethodChannel(
    'com.weijx.fzu_assistant/widget_background',
  );
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final enabled = ValueNotifier<bool>(true);
  final minutes = ValueNotifier<int>(23 * 60);
  final status = ValueNotifier(const WidgetSyncStatus());
  static final cacheUpdates = ValueNotifier<int>(0);
  final Future<bool> Function(String) _refresh;
  final DateTime Function() _now;
  String? _activeAccount, _generation;
  int? _alarmId;
  Future<void>? _pending;
  bool _running = false;
  bool _suspended = false;
  int _revision = 0;
  int _sequence = 0;
  int? _loadedCacheVersion;

  Future<void> _serialize(Future<void> Function() action) {
    final previous = _pending;
    final next = previous == null
        ? action()
        : previous.then(
            (_) => action(),
            onError: (Object _, StackTrace _) => action(),
          );
    _pending = next;
    unawaited(
      next.then<void>(
        (_) {
          if (identical(_pending, next)) _pending = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_pending, next)) _pending = null;
        },
      ),
    );
    return next;
  }

  Future<void> load() async {
    if (!supported) return;
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>('getState');
      if (raw == null) return;
      _alarmId = (raw['alarmId'] as num?)?.toInt();
      enabled.value = raw['enabled'] as bool? ?? true;
      minutes.value = (raw['minutes'] as int? ?? 23 * 60).clamp(0, 1439);
      final permission = await CourseReminderService.instance.permissions();
      final exact = permission['exact'] == true;
      final last = raw['lastSuccess'] as int?;
      status.value = WidgetSyncStatus(
        exactAllowed: exact,
        running: _running,
        failed: raw['failed'] as bool? ?? false,
        lastSuccess: last == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(last, isUtc: true),
        nextAt: enabled.value && exact && raw['generation'] != null
            ? AndroidTaskScheduler.nextWidgetSync(_now(), minutes.value)
            : null,
      );
    } on MissingPluginException {
      // Unit tests and hosts predating the optional widget bridge.
    } on PlatformException {
      status.value = const WidgetSyncStatus(failed: true);
    }
  }

  Future<void> configure({bool? enabled, int? minutes}) => _serialize(() async {
    await load();
    if (enabled != null) this.enabled.value = enabled;
    if (minutes != null) this.minutes.value = minutes.clamp(0, 1439);
    await _configure(force: true);
  });

  /// Called after login and on foreground restoration, including permission
  /// changes. Reuses the generation unless account or preferences changed.
  Future<void> reconcile() => _serialize(() async {
    await load();
    await _configure(force: false);
  });

  Future<void> activate() {
    _suspended = false;
    return reconcile();
  }

  Future<void> reloadCaches() async {
    if (!supported) return;
    await load();
    final version = status.value.lastSuccess?.millisecondsSinceEpoch;
    if (version == null || version == _loadedCacheVersion) return;
    _loadedCacheVersion = version;
    await (await SharedPreferences.getInstance()).reload();
    CacheHelper.changes.value++;
    cacheUpdates.value++;
  }

  Future<void> _configure({required bool force}) async {
    if (!supported || _suspended) return;
    final revision = _revision;
    final account = ApiClient.instance.studentId;
    try {
      if (account == null || account.isEmpty) {
        await cancel();
        return;
      }
      if (force || _generation == null || _activeAccount != account) {
        final oldAlarmId = _alarmId;
        _generation = '${_now().microsecondsSinceEpoch}-${++_sequence}';
        _activeAccount = account;
        await channel.invokeMethod<void>('configure', {
          'enabled': enabled.value,
          'minutes': minutes.value,
          'generation': _generation,
        });
        await load();
        if (oldAlarmId != null && oldAlarmId != _alarmId) {
          await AndroidTaskScheduler.cancelWidgetSync(alarmId: oldAlarmId);
        }
      }
      if (revision != _revision || account != ApiClient.instance.studentId) {
        return;
      }
      if (enabled.value && status.value.exactAllowed) {
        await AndroidTaskScheduler.scheduleWidgetSync(
          generation: _generation!,
          minutes: minutes.value,
          alarmId: _alarmId,
        );
      } else {
        await AndroidTaskScheduler.cancelWidgetSync(alarmId: _alarmId);
      }
      await load();
    } on MissingPluginException {
      // Optional integration is absent on non-Android test hosts.
    } catch (_) {
      _generation = null;
      status.value = WidgetSyncStatus(
        exactAllowed: status.value.exactAllowed,
        lastSuccess: status.value.lastSuccess,
        failed: true,
      );
    }
  }

  /// Invalidate native generation before any awaited alarm cancellation.
  Future<void> cancel() async {
    ++_revision;
    _suspended = true;
    _activeAccount = null;
    _generation = null;
    _loadedCacheVersion = null;
    final alarmId = _alarmId;
    _alarmId = null;
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // No background bridge was registered.
    } on PlatformException {
      // Logout continues even if the optional scheduler is unavailable.
    }
    try {
      await AndroidTaskScheduler.cancelWidgetSync(alarmId: alarmId);
    } on MissingPluginException {
      // The native storage and alarm revocations are independent.
    } on PlatformException {
      // A revoked callback is harmless even if Android cannot cancel its alarm.
    }
  }

  Future<void> requestExactPermission() =>
      CourseReminderService.instance.requestPermission('requestExact');

  Future<bool> refreshNow() async {
    if (!supported || _running) return false;
    // Reserve before reconciliation so another caller cannot enter while it
    // awaits native state. Manual refresh also works with automatic sync off.
    _running = true;
    try {
      await reconcile();
      final generation = _generation;
      if (generation == null) return false;
      final success = await _refresh(generation);
      if (success) {
        await reloadCaches();
      }
      return success;
    } finally {
      _running = false;
      await load();
    }
  }

  static Future<bool> _refreshInIsolate(String generation) async {
    final token = ServicesBinding.rootIsolateToken;
    if (token == null) return false;
    return Isolate.run(() async {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      DartPluginRegistrant.ensureInitialized();
      return refreshWidgetData(generation, manual: true);
    });
  }

  @pragma('vm:entry-point')
  static Future<void> runBackground(String? generation) async {
    if (generation == null) return;
    final state = await channel.invokeMapMethod<String, dynamic>('getState');
    if (state?['generation'] != generation || state?['enabled'] != true) {
      return;
    }
    // Schedule tomorrow first, so a network failure cannot stop future updates.
    await AndroidTaskScheduler.scheduleWidgetSync(
      generation: generation,
      minutes: state?['minutes'] as int? ?? 23 * 60,
      alarmId: (state?['alarmId'] as num?)?.toInt(),
    );
    final acquired = await channel.invokeMethod<bool>('acquireWakeLock', {
      'generation': generation,
    });
    if (acquired != true) return;
    try {
      await refreshWidgetData(generation);
    } finally {
      await channel.invokeMethod<void>('releaseWakeLock', {
        'generation': generation,
      });
    }
  }
}

/// Stages official calendar and courses entirely in memory. The plugin compares
/// the captured inputs and generation before publishing caches and widgets.
@visibleForTesting
Future<bool> refreshWidgetData(
  String generation, {
  bool manual = false,
  Future<String?> Function()? authenticate,
  Future<SchoolCalendar> Function()? fetchCalendar,
  Future<List<Course>> Function(String)? fetchCourses,
  DateTime? now,
}) async {
  const channel = WidgetSyncService.channel;
  AppSettings? settings;
  try {
    final prepared = await channel.invokeMapMethod<String, dynamic>('prepare', {
      'generation': generation,
      'manual': manual,
    });
    if (prepared == null) return false;
    final baseline = Map<String, dynamic>.from(prepared['baseline'] as Map);
    final calendarConfig = Map<String, dynamic>.from(
      prepared['calendar'] as Map? ?? {},
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    settings = AppSettings();
    await settings.load();
    Future<String?> signIn() async {
      final api = ApiClient.instance..persistAcademicSession = false;
      return await api.relogin() ? api.studentId : null;
    }

    final account = await (authenticate ?? signIn)();
    if (account == null) throw StateError('教务会话无效');
    if (calendarConfig['enabled'] == true &&
        calendarConfig['owner'] != calendarAccountKey(account)) {
      throw StateError('日历账号已变化，请重新开启同步');
    }
    final calendar =
        await (fetchCalendar ?? AcademicService().getSchoolCalendar)();
    if (calendar.terms.isEmpty) throw StateError('校历数据无效');
    final instant = (now ?? DateTime.now()).toUtc();
    final terms = widgetRefreshTerms(calendar, instant);
    if (terms.isEmpty) throw StateError('当前日期不在有效校历范围内');
    final caches = await CacheHelper.loadMap(SpKeys.cacheCoursesMap);
    final service = CourseService();
    for (final term in terms) {
      final courses = fetchCourses != null
          ? await fetchCourses(term)
          : await service.getCourses(
              term,
              useCache: false,
              persistCache: false,
              requireCompleteRows: true,
            );
      caches[term] = {
        'courses': courses.map((course) => course.toJson()).toList(),
        'updatedAt': instant.millisecondsSinceEpoch,
      };
    }
    final holidays = await CacheHelper.loadMap(
      SpKeys.cacheHolidayAdjustmentsMap,
    );
    // Respect the user's independent west2 authorization; cached adjustments
    // remain available without adding a third-party network dependency here.
    final coursesByTerm = <String, List<Course>>{};
    for (final entry in caches.entries) {
      final raw = entry.value;
      if (raw is! Map || raw['courses'] is! List) continue;
      final courses = (raw['courses'] as List)
          .map((c) => Course.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList();
      coursesByTerm[entry.key] = settings.useWest2Adjustments
          ? CourseService.applyHolidayAdjustments(
              courses,
              holidays[entry.key] as List? ?? [],
            )
          : courses;
    }
    final customRaw = preferences.getString(CustomCourseStore.storageKey);
    final custom = customRaw == null
        ? <CustomCourse>[]
        : CustomCourse.parseList(jsonDecode(customRaw));
    final snapshot = NextCourseWidgetSnapshot.build(
      account: account,
      terms: calendar.terms,
      coursesByTerm: coursesByTerm,
      now: instant,
      autoAdjust: settings.autoAdjustCourse.value,
      customCourses: custom,
      hiddenSessions: settings.hiddenCourseSessions.value,
      locale: settings.localeKey.value,
    );
    final encoded = snapshot.toJson()
      ..['sourceUpdatedAt'] = instant.millisecondsSinceEpoch;
    return await channel.invokeMethod<bool>('commit', {
          'generation': generation,
          'manual': manual,
          'baseline': baseline,
          'writes': {
            SpKeys.cacheSchoolCalendar: jsonEncode(calendar.toJson()),
            SpKeys.cacheCoursesMap: jsonEncode(caches),
          },
          'snapshot': jsonEncode(encoded),
          if (calendarConfig['enabled'] == true)
            'calendar': buildCalendarSyncPayload(
              account: account,
              terms: calendar.terms
                  .where((term) => terms.contains(term.term))
                  .toList(),
              coursesByTerm: coursesByTerm,
              customCourses: custom,
              hiddenSessions: settings.hiddenCourseSessions.value,
              autoAdjust: settings.autoAdjustCourse.value,
              includeExams: calendarConfig['includeExams'] != false,
              reminderMinutes: calendarConfig['reminder'] as int? ?? 15,
              now: instant,
            ),
        }) ??
        false;
  } catch (error) {
    if (kDebugMode) {
      debugPrint(
        'NightlySync: ${error is StateError
            ? error.message
            : error is FormatException
            ? error.message
            : error.runtimeType}',
      );
    }
    try {
      await channel.invokeMethod<void>('markFailed', {
        'generation': generation,
        'manual': manual,
      });
    } on MissingPluginException {
      // No background integration on this host.
    } on PlatformException {
      // Existing caches and widgets remain intact even if status cannot save.
    }
    return false;
  } finally {
    settings?.dispose();
  }
}

@visibleForTesting
List<String> widgetRefreshTerms(SchoolCalendar calendar, DateTime now) {
  final beijing = now.toUtc().add(const Duration(hours: 8));
  final today = DateTime.utc(beijing.year, beijing.month, beijing.day);
  final end = today.add(const Duration(days: 14));
  return calendar.terms
      .where((term) {
        final startDate = DateTime.tryParse(term.startDate);
        final endDate = DateTime.tryParse(term.endDate);
        if (startDate == null || endDate == null) return false;
        final start = DateTime.utc(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final finish = DateTime.utc(endDate.year, endDate.month, endDate.day);
        return !finish.isBefore(today) && !start.isAfter(end);
      })
      .map((term) => term.term)
      .toSet()
      .toList();
}
