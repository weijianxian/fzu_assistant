import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/calendar_sync.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/course_live_updates_controller.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes only local display data to Android; never fetches academic services.
class NextCourseWidgetService with WidgetsBindingObserver {
  NextCourseWidgetService({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static final instance = NextCourseWidgetService();
  static const channel = MethodChannel(
    'com.weijx.fzu_assistant/next_course_widget',
  );
  static const backgroundChannel = MethodChannel(
    'com.weijx.fzu_assistant/widget_background',
  );
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final error = ValueNotifier<bool>(false);
  final snapshot = ValueNotifier<NextCourseWidgetSnapshot?>(null);
  final DateTime Function() _now;
  Future<void>? _writes;
  int _revision = 0;
  bool _suspended = false;
  AppSettings? _settings;
  VoidCallback? _unbind;

  /// Call once after settings.load. The returned cleanup removes all listeners.
  ///
  /// Home should also call [sync] on mount, including after successful login or
  /// restoration of a cached session. Logout must await [clear].
  VoidCallback bind(AppSettings settings) {
    _unbind?.call();
    _settings = settings;
    final inputs = <Listenable>[
      CacheHelper.changes,
      CustomCourseStore.instance,
      settings.hiddenCourseSessions,
      settings.autoAdjustCourse,
      settings.west2AdjustmentsAccess,
      settings.localeKey,
      settings.courseLiveUpdatesEnabled,
    ];
    void update() => unawaited(_sync(settings));
    for (final input in inputs) {
      input.addListener(update);
    }
    WidgetsBinding.instance.addObserver(this);
    var bound = true;
    void unbind() {
      if (!bound) return;
      bound = false;
      for (final input in inputs) {
        input.removeListener(update);
      }
      WidgetsBinding.instance.removeObserver(this);
      _settings = null;
      _unbind = null;
    }

    _unbind = unbind;
    update();
    return unbind;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = _settings;
    if (state == AppLifecycleState.resumed && settings != null) {
      unawaited(_sync(settings));
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final settings = _settings;
    if (settings != null && settings.localeKey.value == 'system') {
      unawaited(_sync(settings));
    }
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final previous = _writes;
    final next = previous == null
        ? operation()
        : previous.then(
            (_) => operation(),
            onError: (Object _, StackTrace _) => operation(),
          );
    _writes = next;
    void release() {
      // A completed Future retains its Zone. Do not schedule the next write in
      // an earlier widget test's FakeAsync queue, which is no longer pumped.
      if (identical(_writes, next)) _writes = null;
    }

    unawaited(
      next.then<void>(
        (_) => release(),
        onError: (Object _, StackTrace _) => release(),
      ),
    );
    return next;
  }

  Future<void> sync(AppSettings settings) {
    _suspended = false;
    return _sync(settings);
  }

  Future<void> _sync(AppSettings settings, {int attempt = 1}) async {
    if (!supported || _suspended) return;
    final revision = ++_revision;
    final account = ApiClient.instance.studentId;
    bool stale() =>
        _suspended ||
        revision != _revision ||
        account != ApiClient.instance.studentId;
    try {
      // Capture native inputs before reloading the foreground isolate's cache.
      // A background commit between either step and publication must reject
      // this build, rather than overwrite its newer snapshot.
      final inputs = await _readInputs();
      final baseline = inputs?.baseline;
      if (stale()) return;
      // Native input writes can be committed before the foreground stores have
      // notified listeners. Use the captured values that publication validates,
      // rather than mixing their baseline with older in-memory settings.
      final customCourses = baseline == null
          ? CustomCourseStore.instance.value
          : CustomCourse.parseList(
              _decodeInputList(baseline, CustomCourseStore.storageKey),
            );
      final hiddenSessions = baseline == null
          ? settings.hiddenCourseSessions.value
          : _hiddenInputSessions(baseline);
      final autoAdjust = baseline == null
          ? settings.autoAdjustCourse.value
          : (baseline['flutter.${SpKeys.autoAdjustCourse}'] as bool? ?? true);
      final useWest2Adjustments = baseline == null
          ? settings.useWest2Adjustments
          : _inputWest2Access(baseline) == FeatureAccess.allow;
      final locale = baseline == null
          ? settings.localeKey.value
          : switch (baseline['flutter.${SpKeys.localeKey}']) {
              'zh' => 'zh',
              'en' => 'en',
              _ => 'system',
            };
      await (await SharedPreferences.getInstance()).reload();
      if (stale()) return;
      final calendar = await CacheHelper.loadMap(SpKeys.cacheSchoolCalendar);
      final caches = await CacheHelper.loadMap(SpKeys.cacheCoursesMap);
      final holidays = await CacheHelper.loadMap(
        SpKeys.cacheHolidayAdjustmentsMap,
      );
      if (stale()) return;
      final now = _now().toUtc();
      final beijing = now.add(NextCourseWidgetSnapshot.beijingOffset);
      final today = DateTime.utc(beijing.year, beijing.month, beijing.day);
      final terms = calendar.isEmpty
          ? <CalTerm>[]
          : SchoolCalendar.fromJson(calendar).terms;
      final coursesByTerm = <String, List<Course>>{};
      DateTime? sourceUpdatedAt;
      for (final entry in caches.entries) {
        final raw = entry.value;
        if (raw is! Map || raw['courses'] is! List) continue;
        try {
          var courses = (raw['courses'] as List)
              .map(
                (value) =>
                    Course.fromJson(Map<String, dynamic>.from(value as Map)),
              )
              .toList();
          if (useWest2Adjustments) {
            courses = CourseService.applyHolidayAdjustments(
              courses,
              (holidays[entry.key] as List?) ?? [],
            );
          }
          coursesByTerm[entry.key] = courses;
          for (final term in terms.where((term) => term.term == entry.key)) {
            final start = DateTime.tryParse(term.startDate);
            final end = DateTime.tryParse(term.endDate);
            if (start == null || end == null) continue;
            final first = DateTime.utc(start.year, start.month, start.day);
            final last = DateTime.utc(end.year, end.month, end.day);
            if (!today.isBefore(first) && !today.isAfter(last)) {
              sourceUpdatedAt = _cacheTimestamp(raw['updatedAt'], now);
              break;
            }
          }
        } catch (_) {
          // A damaged term stays unknown, rather than becoming an empty term.
        }
      }
      final next = NextCourseWidgetSnapshot.build(
        account: account ?? '',
        terms: terms,
        coursesByTerm: coursesByTerm,
        now: now,
        sourceUpdatedAt: sourceUpdatedAt,
        autoAdjust: autoAdjust,
        customCourses: customCourses,
        hiddenSessions: hiddenSessions,
        locale: locale,
        totalScheduleWeeks: CourseService.totalScheduleWeeks,
      );
      Map<String, Object>? calendarPayload;
      final calendarConfig = inputs?.calendar ?? const {};
      if (account != null &&
          account.isNotEmpty &&
          calendarConfig['enabled'] == true &&
          calendarConfig['granted'] == true &&
          calendarConfig['owner'] == calendarAccountKey(account)) {
        final actualTerms = widgetRefreshTerms(
          SchoolCalendar(currentTerm: '', terms: terms),
          now,
        ).toSet();
        final completeTerms = terms
            .where(
              (term) =>
                  actualTerms.contains(term.term) &&
                  coursesByTerm.containsKey(term.term),
            )
            .toList();
        if (completeTerms.isNotEmpty) {
          try {
            calendarPayload = buildCalendarSyncPayload(
              account: account,
              terms: completeTerms,
              coursesByTerm: coursesByTerm,
              customCourses: customCourses,
              hiddenSessions: hiddenSessions,
              autoAdjust: autoAdjust,
              includeExams: calendarConfig['includeExams'] != false,
              reminderMinutes: calendarConfig['reminder'] as int? ?? 15,
              now: now,
            );
          } catch (_) {
            // Incomplete local inputs preserve existing calendar events and
            // must not prevent the widget from showing its valid cached data.
          }
        }
      }
      var refused = false;
      await _serialize(() async {
        if (stale()) return;
        final encoded = jsonEncode(next.toJson());
        if (baseline == null) {
          await channel.invokeMethod<void>('setSnapshot', encoded);
        } else {
          try {
            final accepted = await backgroundChannel.invokeMethod<bool>(
              'publishSnapshot',
              {
                'baseline': baseline,
                'snapshot': encoded,
                'calendar': ?calendarPayload,
              },
            );
            if (accepted != true) {
              refused = true;
              return;
            }
          } on MissingPluginException {
            // Older hosts have no guarded publication method.
            await channel.invokeMethod<void>('setSnapshot', encoded);
          }
        }
        if (!stale()) {
          snapshot.value = next;
          error.value = false;
          await CourseLiveUpdatesController.synchronize();
        }
      });
      if (refused && !stale() && attempt < 3) {
        // Retry outside the native-write queue, with a fresh baseline and fresh
        // preferences. Continuous changes leave the last accepted widget intact.
        await _sync(settings, attempt: attempt + 1);
      }
    } catch (_) {
      if (stale()) return;
      error.value = true;
      snapshot.value = null;
      await _serialize(() async {
        if (stale()) return;
        try {
          await channel.invokeMethod<void>('invalidate');
        } on MissingPluginException {
          // Hosts without widgets still run normally.
        } on PlatformException {
          // Keep the visible retry state if the native host fails too.
        }
      });
    }
  }

  static Object? _decodeInputList(Map<Object?, Object?> baseline, String key) {
    final raw = baseline['flutter.$key'];
    return raw == null ? const [] : jsonDecode(raw as String);
  }

  static List<HiddenCourseSession> _hiddenInputSessions(
    Map<Object?, Object?> baseline,
  ) {
    final records = _decodeInputList(baseline, SpKeys.hiddenCourseSessions);
    if (records is! List) {
      throw const FormatException('隐藏课程列表无效');
    }
    final sessions = <HiddenCourseSession>[];
    for (final record in records) {
      try {
        sessions.add(
          HiddenCourseSession.fromJson(
            Map<String, dynamic>.from(record as Map),
          ),
        );
      } catch (_) {
        // Match AppSettings: a damaged record does not discard valid entries.
      }
    }
    return sessions;
  }

  static FeatureAccess _inputWest2Access(Map<Object?, Object?> baseline) {
    final access = baseline['flutter.${SpKeys.west2AdjustmentsAccess}'];
    if (access != null) {
      return FeatureAccess.parse(access as String?);
    }
    return baseline['flutter.${SpKeys.west2AdjustmentsEnabled}'] == true
        ? FeatureAccess.allow
        : FeatureAccess.tip;
  }

  static Future<
    ({Map<Object?, Object?> baseline, Map<Object?, Object?> calendar})?
  >
  _readInputs() async {
    try {
      final inputs = await backgroundChannel.invokeMapMethod<String, dynamic>(
        'readInputs',
      );
      if (inputs == null) return null;
      final baseline = inputs['baseline'];
      if (baseline is! Map) {
        throw StateError('小组件输入基线无效');
      }
      return (
        baseline: Map<Object?, Object?>.from(baseline),
        calendar: Map<Object?, Object?>.from(inputs['calendar'] as Map? ?? {}),
      );
    } on MissingPluginException {
      // Tests and native hosts predating background sync use the legacy bridge.
      return null;
    }
  }

  /// Invalidates in-flight builds and queues removal after any in-flight write.
  ///
  /// Automatic listeners remain suspended until Home explicitly calls [sync]
  /// after login. This prevents a logout-before-clearSession race from restoring
  /// the departing account's data.
  Future<void> clear() async {
    ++_revision;
    _suspended = true;
    snapshot.value = null;
    error.value = false;
    if (!supported) return;
    await _serialize(() async {
      try {
        await channel.invokeMethod<void>('clear');
      } on MissingPluginException {
        // Tests and older native hosts have no persisted widget snapshot.
      } on PlatformException {
        // Widget failures must not strand the user in the signed-in UI.
        error.value = true;
        try {
          await channel.invokeMethod<void>('invalidate');
        } on MissingPluginException {
          // No native integration remains to invalidate.
        } on PlatformException {
          // Keep retry state; never propagate an optional widget failure to logout.
        }
      }
    });
  }

  static DateTime? _cacheTimestamp(Object? value, DateTime now) {
    final timestamp = switch (value) {
      int milliseconds
          when milliseconds > 0 && milliseconds <= now.millisecondsSinceEpoch =>
        DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
      // Only timezone-qualified legacy strings represent an unambiguous instant.
      String text when RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text) =>
        DateTime.tryParse(text)?.toUtc(),
      _ => null,
    };
    return timestamp != null &&
            timestamp.millisecondsSinceEpoch > 0 &&
            !timestamp.isAfter(now)
        ? timestamp
        : null;
  }

  Future<bool> requestPin({
    NextCourseWidgetVariant variant = NextCourseWidgetVariant.square,
  }) async {
    if (!supported) return false;
    try {
      return await channel.invokeMethod<bool>('requestPin', {
            'variant': variant.name,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
