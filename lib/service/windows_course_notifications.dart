import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/course_live_update.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/windows_toast_backend.dart';
import 'package:url_launcher/url_launcher.dart';

export 'windows_toast_backend.dart'
    show WindowsCourseToast, WindowsToastBackend;

class WindowsCourseNotificationData {
  const WindowsCourseNotificationData({
    required this.snapshot,
    required this.reminders,
    required this.l10n,
    required this.liveEnabled,
  });

  final NextCourseWidgetSnapshot snapshot;
  final List<Map<String, Object>> reminders;
  final AppLocalizations l10n;
  final bool liveEnabled;
}

/// Windows notifications run in the application's existing foreground/tray
/// process. No Windows service, Android alarm or native widget lock is used.
///
/// We deliberately keep future plans in-process: Inno/portable applications
/// lack MSIX identity, so the plugin cannot individually remove shown toasts.
/// Stopping the process stops reminders; logout invalidates pending work before
/// awaiting plugin calls. A delayed wake skips expired stages.
class WindowsCourseNotifications with WidgetsBindingObserver {
  WindowsCourseNotifications({
    WindowsToastBackend? backend,
    DateTime Function()? now,
    String? Function()? account,
    bool Function() Function()? sessionFence,
    Future<WindowsCourseNotificationData> Function(
      AppSettings settings,
      String account,
      DateTime now,
    )?
    load,
    bool Function()? isSupported,
  }) : _backend = backend ?? PluginWindowsToastBackend(),
       _now = now ?? DateTime.now,
       _account = account ?? (() => ApiClient.instance.studentId),
       _sessionFence = sessionFence ?? _academicFence,
       _load = load ?? loadData,
       _isSupported = isSupported ?? (() => supported);

  static final instance = WindowsCourseNotifications();
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  static const courseNotificationId = 5310;
  static const reminderNotificationId = 5311;
  static const previewNotificationId = 5312;

  final WindowsToastBackend _backend;
  final DateTime Function() _now;
  final String? Function() _account;
  final bool Function() Function() _sessionFence;
  final Future<WindowsCourseNotificationData> Function(
    AppSettings,
    String,
    DateTime,
  )
  _load;
  final bool Function() _isSupported;
  final error = ValueNotifier(false);
  final ready = ValueNotifier(false);
  final nextReminder = ValueNotifier<DateTime?>(null);

  Future<void>? _initializing, _writes;
  Future<void> Function()? _onActivate;
  AppSettings? _settings;
  WindowsCourseNotificationData? _data;
  VoidCallback? _unbind;
  Timer? _wake, _previewWake;
  int _revision = 0, _previewRevision = 0;
  bool _suspended = false, _shutDown = false;
  String? _activeAccount, _frameKey, _previewKey;
  DateTime? _lastReminder, _previewStarted;
  CourseLiveUpdateTimeline? _preview;
  bool Function()? _acceptedSession;

  static bool Function() _academicFence() {
    final guard = ApiClient.instance.captureSession();
    return () {
      try {
        guard.check();
        return true;
      } catch (_) {
        return false;
      }
    };
  }

  Future<void> initialize({Future<void> Function()? onActivate}) async {
    if (!_isSupported()) return;
    if (onActivate != null) _onActivate = onActivate;
    if (ready.value) return;
    if (_shutDown) return;
    final pending = _initializing ??= _backend.initialize(() async {
      if (!_shutDown) await _onActivate?.call();
    });
    try {
      await pending;
      if (!_shutDown) ready.value = true;
    } catch (_) {
      _initializing = null;
      error.value = true;
      rethrow;
    }
  }

  /// Bind once after AppSettings.load. Home's existing reminder sync explicitly
  /// activates the service after login. Cache listeners never lift a logout
  /// fence while the departing account is still present in ApiClient.
  VoidCallback bind(
    AppSettings settings, {
    Future<void> Function()? onActivate,
  }) {
    if (!_isSupported()) return () {};
    _unbind?.call();
    _settings = settings;
    if (onActivate != null) _onActivate = onActivate;
    final inputs = <Listenable>[
      CacheHelper.changes,
      CustomCourseStore.instance,
      settings.courseReminderEnabled,
      settings.courseReminderMinutes,
      settings.courseLiveUpdatesEnabled,
      settings.hiddenCourseSessions,
      settings.autoAdjustCourse,
      settings.west2AdjustmentsAccess,
      settings.localeKey,
    ];
    void update() => unawaited(synchronize(settings, activate: false));
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
      ++_revision;
      _wake?.cancel();
    }

    _unbind = unbind;
    update();
    return unbind;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = _settings;
    if (state == AppLifecycleState.resumed && settings != null) {
      unawaited(synchronize(settings, activate: false));
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final settings = _settings;
    if (settings != null && settings.localeKey.value == 'system') {
      unawaited(synchronize(settings, activate: false));
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

  Future<void> synchronize(
    AppSettings settings, {
    bool activate = false,
  }) async {
    if (!_isSupported() || _shutDown) return;
    if (activate) _suspended = false;
    if (_suspended) return;
    final revision = ++_revision;
    _wake?.cancel();
    final account = _account();
    final sessionCurrent = _sessionFence();
    bool current() =>
        !_shutDown &&
        !_suspended &&
        revision == _revision &&
        account == _account() &&
        sessionCurrent();
    try {
      await initialize();
      if (!current()) return;
      final data = account == null || account.isEmpty
          ? null
          : await _load(settings, account, _now().toUtc());
      if (!current()) return;
      await _serialize(() async {
        if (!current()) return;
        if (_activeAccount != account) {
          await _backend.clear();
          _frameKey = null;
          _lastReminder = null;
        }
        if (!current()) return;
        _activeAccount = account;
        _acceptedSession = sessionCurrent;
        _data = data;
        await _tick(revision);
      });
      if (current()) error.value = false;
    } catch (_) {
      if (!current()) return;
      error.value = true;
      _data = null;
      _frameKey = null;
      nextReminder.value = null;
      // Never continue with plans derived from incomplete/old inputs.
      await _serialize(() async {
        if (current() && ready.value) {
          try {
            await _backend.clear();
          } catch (_) {
            // Keep the error visible; the invalidated plans remain stopped.
          }
        }
      });
      if (current()) _scheduleWake(revision, const Duration(minutes: 1));
    }
  }

  bool _current(int revision) =>
      !_suspended &&
      !_shutDown &&
      revision == _revision &&
      _activeAccount == _account() &&
      (_acceptedSession?.call() ?? false);

  Future<void> _tick(int revision) async {
    if (!_current(revision)) return;
    final data = _data;
    final now = _now().toUtc();
    if (data != null) {
      final due = data.reminders.where((plan) {
        final at = DateTime.fromMillisecondsSinceEpoch(
          plan['at'] as int,
          isUtc: true,
        );
        return !at.isAfter(now) &&
            now.difference(at) <= const Duration(minutes: 1) &&
            (_lastReminder == null || at.isAfter(_lastReminder!));
      }).lastOrNull;
      if (due != null && _current(revision)) {
        _lastReminder = DateTime.fromMillisecondsSinceEpoch(
          due['at'] as int,
          isUtc: true,
        );
        await _backend.show(
          WindowsCourseToast(
            id: reminderNotificationId,
            title: due['title'] as String,
            body: due['body'] as String,
          ),
        );
      }
      if (!_current(revision)) return;
      final frame = data.liveEnabled ? frameAt(data.snapshot, now) : null;
      if (frame == null) {
        if (_frameKey != null) {
          // Per-ID history removal is unavailable in unpackaged builds.
          await _backend.clear();
          _frameKey = null;
        }
      } else {
        final key = frameKey(frame, data.l10n.localeName);
        final toast = courseToast(frame, now: now, l10n: data.l10n);
        if (key != _frameKey) {
          await _backend.show(toast);
          _frameKey = key;
        } else if (frame.state != CourseLiveUpdatePreview.ended) {
          await _backend.update(toast);
        }
      }
      if (!_current(revision)) return;
      final upcoming = data.reminders
          .map(
            (p) => DateTime.fromMillisecondsSinceEpoch(
              p['at'] as int,
              isUtc: true,
            ),
          )
          .where((at) => at.isAfter(now));
      nextReminder.value = upcoming.firstOrNull;
    } else {
      nextReminder.value = null;
    }
    // Also detects a replaced login even when no cached course data changed.
    // Clock/resume delays are evaluated from actual time, never replayed.
    _scheduleWake(revision, _nextDelay(data, now));
  }

  Duration _nextDelay(WindowsCourseNotificationData? data, DateTime now) {
    var next = now.add(const Duration(seconds: 30));
    if (data != null) {
      for (final plan in data.reminders) {
        final at = DateTime.fromMillisecondsSinceEpoch(
          plan['at'] as int,
          isUtc: true,
        );
        if (at.isAfter(now) && at.isBefore(next)) next = at;
      }
      if (data.liveEnabled) {
        for (final day in data.snapshot.days.where((day) => day.known)) {
          final change = CourseLiveUpdateTimeline(day.courses)
              .nextChangeAfter(now);
          if (change != null && change.isBefore(next)) next = change;
          for (final course in day.courses) {
            final clearAt = course.end.add(
              CourseLiveUpdateTimeline.endedLifetime,
            );
            if (clearAt.isAfter(now) && clearAt.isBefore(next)) next = clearAt;
          }
        }
      }
    }
    return next.difference(now);
  }

  void _scheduleWake(int revision, Duration delay) {
    _wake?.cancel();
    _wake = Timer(delay, () async {
      if (_shutDown || _suspended || revision != _revision) return;
      final settings = _settings;
      if (_account() != _activeAccount ||
          (_data == null && _account() != null) ||
          !(_acceptedSession?.call() ?? false)) {
        if (settings != null) {
          await synchronize(settings, activate: false);
        }
        return;
      }
      // Rebuild the finite local plan once the Beijing date changes.
      final generated = _data?.snapshot.generatedAt;
      if (settings != null &&
          generated != null &&
          _beijingDate(generated) != _beijingDate(_now())) {
        await synchronize(settings, activate: false);
        return;
      }
      try {
        await _serialize(() => _tick(revision));
      } catch (_) {
        if (_current(revision)) {
          error.value = true;
          _scheduleWake(revision, const Duration(minutes: 1));
        }
      }
    });
  }

  static String _beijingDate(DateTime now) => now
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 10);

  /// Invalidates every callback synchronously, before waiting for native work.
  /// ApiClient.clearSession already awaits CourseReminderService.cancel().
  Future<void> cancel() async {
    if (!_isSupported()) return;
    ++_revision;
    ++_previewRevision;
    _suspended = true;
    _wake?.cancel();
    _previewWake?.cancel();
    _data = null;
    _preview = null;
    _frameKey = _previewKey = null;
    _activeAccount = null;
    _acceptedSession = null;
    _lastReminder = null;
    nextReminder.value = null;
    await _serialize(() async {
      if (ready.value) {
        try {
          await _backend.clear();
        } catch (_) {
          // Logout and real Exit still cancel every future callback even if
          // Windows cannot clear the previously delivered notification.
          error.value = true;
        }
      }
    });
  }

  /// Real Exit only. Hiding/minimizing to the tray must keep the plans alive.
  Future<void> shutdown() async {
    _shutDown = true;
    _unbind?.call();
    await cancel();
  }

  Future<void> openSettings() async {
    if (_isSupported() &&
        !await launchUrl(Uri.parse('ms-settings:notifications'))) {
      throw StateError('Cannot open Windows notification settings');
    }
  }

  @visibleForTesting
  static CourseLiveUpdateFrame? frameAt(
    NextCourseWidgetSnapshot snapshot,
    DateTime now,
  ) {
    if (!snapshot.signedIn) return null;
    for (final day in snapshot.days) {
      if (day.known &&
          !now.isBefore(day.start) &&
          now.isBefore(day.start.add(const Duration(days: 1)))) {
        return CourseLiveUpdateTimeline(day.courses).at(now);
      }
    }
    return null;
  }

  static String frameKey(CourseLiveUpdateFrame frame, String locale) =>
      jsonEncode([
        locale,
        frame.state.name,
        for (final course in frame.courses)
          [
            course.name,
            course.location,
            course.start.millisecondsSinceEpoch,
            course.end.millisecondsSinceEpoch,
            course.startClass,
            course.endClass,
          ],
      ]);

  @visibleForTesting
  static WindowsCourseToast courseToast(
    CourseLiveUpdateFrame frame, {
    required DateTime now,
    AppLocalizations? l10n,
    int id = courseNotificationId,
  }) {
    final title = switch (frame.state) {
      CourseLiveUpdatePreview.inProgress =>
        l10n?.courseLiveInProgress ?? 'Class in progress',
      CourseLiveUpdatePreview.nextClass => l10n?.courseLiveNext ?? 'Next class',
      CourseLiveUpdatePreview.ended => l10n?.courseLiveEnded ?? 'Class ended',
    };
    final active = frame.state != CourseLiveUpdatePreview.ended;
    final next = frame.state == CourseLiveUpdatePreview.nextClass;
    final target = next ? frame.start : frame.end;
    final remaining = target.difference(now);
    final minutes = (remaining.inMilliseconds / 60000).ceil().clamp(0, 1440);
    final ended = l10n == null
        ? '${frame.part.label} classes finished'
        : switch (frame.part) {
            CourseDayPart.morning => l10n.courseLiveMorningEnded,
            CourseDayPart.afternoon => l10n.courseLiveAfternoonEnded,
            CourseDayPart.evening => l10n.courseLiveEveningEnded,
          };
    String time(DateTime instant) {
      final beijing = instant.toUtc().add(const Duration(hours: 8));
      return '${beijing.hour.toString().padLeft(2, '0')}:${beijing.minute.toString().padLeft(2, '0')}';
    }

    final seconds = remaining.inSeconds.clamp(0, 86400);
    final label =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return WindowsCourseToast(
      id: id,
      title: title,
      body: [
        if (next)
          l10n?.courseLiveStartsInMinutes(minutes) ?? 'Starts in $label',
        for (final course in frame.courses)
          '${course.name} · ${course.location}\n${time(course.start)}–${time(course.end)} (UTC+8)',
        if (!active) ended,
      ].join('\n'),
      progress: active
          ? (now.difference(frame.progressStart).inMilliseconds /
                    frame.progressEnd
                        .difference(frame.progressStart)
                        .inMilliseconds)
                .clamp(0, 1)
          : null,
      progressLabel: active ? label : null,
      progressStatus: title,
    );
  }

  /// Read cached academic data only. The shared Dart models filter adjustments,
  /// hidden sessions and custom courses without using Android snapshot locks.
  static Future<WindowsCourseNotificationData> loadData(
    AppSettings settings,
    String account,
    DateTime now,
  ) async {
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
    final coursesByTerm = <String, List<Course>>{};
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
        if (settings.useWest2Adjustments) {
          courses = CourseService.applyHolidayAdjustments(
            courses,
            (holidays[entry.key] as List?) ?? [],
          );
        }
        coursesByTerm[entry.key] = courses;
      } catch (_) {
        // Leave damaged coverage unknown. Do not announce a false free day.
      }
    }
    final snapshot = NextCourseWidgetSnapshot.build(
      account: account,
      terms: calendar.isEmpty ? [] : SchoolCalendar.fromJson(calendar).terms,
      coursesByTerm: coursesByTerm,
      now: now,
      autoAdjust: settings.autoAdjustCourse.value,
      hiddenSessions: settings.hiddenCourseSessions.value,
      customCourses: CustomCourseStore.instance.value,
      locale: l10n.localeName,
      totalScheduleWeeks: CourseService.totalScheduleWeeks,
    );
    final validCaches = {
      for (final key in coursesByTerm.keys) key: caches[key],
    };
    return WindowsCourseNotificationData(
      snapshot: snapshot,
      reminders: settings.courseReminderEnabled.value
          ? CourseReminderService.buildPlans(
              settings: settings,
              account: account,
              l10n: l10n,
              calendar: calendar,
              caches: validCaches,
              holidays: holidays,
              now: now,
              customCourses: CustomCourseStore.instance.value,
            )
          : [],
      l10n: l10n,
      liveEnabled: settings.courseLiveUpdatesEnabled.value,
    );
  }

  /// Developer tests are separate from the accepted academic plan and toggles.
  Future<void> testNotification({Duration delay = Duration.zero}) async {
    if (!_isSupported() || _shutDown) return;
    final revision = ++_previewRevision;
    _previewWake?.cancel();
    await initialize();
    if (revision != _previewRevision || _shutDown) return;
    Future<void> show() => _serialize(() async {
      if (revision != _previewRevision || _shutDown) return;
      await _backend.show(
        const WindowsCourseToast(
          id: previewNotificationId,
          title: 'Course reminder test',
          body: 'Windows notification delivery is working. Click to restore FZU Assistant.',
        ),
      );
    });
    if (delay == Duration.zero) {
      await show();
    } else {
      _previewWake = Timer(delay, () async {
        try {
          await show();
        } catch (_) {
          if (revision == _previewRevision) error.value = true;
        }
      });
    }
  }

  Future<void> showPreview(CourseLiveUpdatePreview state) async {
    if (!_isSupported() || _shutDown) return;
    final revision = ++_previewRevision;
    _previewWake?.cancel();
    await initialize();
    if (revision != _previewRevision || _shutDown) return;
    final now = _now().toUtc();
    final start = state == CourseLiveUpdatePreview.nextClass
        ? now.add(const Duration(minutes: 5))
        : now.subtract(const Duration(minutes: 20));
    final end = state == CourseLiveUpdatePreview.ended
        ? now
        : start.add(const Duration(minutes: 45));
    _preview = CourseLiveUpdateTimeline([
      NextCourseWidgetEntry(
        name: 'Advanced Mathematics',
        location: 'Teaching Building 3-301',
        start: start,
        end: end,
        startClass: 1,
        endClass: 2,
        week: 1,
      ),
    ]);
    _previewKey = null;
    await _tickPreview(revision);
  }

  Future<void> startPreviewSequence() async {
    if (!_isSupported() || _shutDown) return;
    final revision = ++_previewRevision;
    _previewWake?.cancel();
    await initialize();
    if (revision != _previewRevision || _shutDown) return;
    _previewStarted = _now().toUtc();
    NextCourseWidgetEntry entry(String name, int first, int start, int end) =>
        NextCourseWidgetEntry(
          name: name,
          location: 'Teaching Building 3-301',
          start: _previewStarted!.add(Duration(seconds: start)),
          end: _previewStarted!.add(Duration(seconds: end)),
          startClass: first,
          endClass: first + 1,
          week: 1,
        );
    _preview = CourseLiveUpdateTimeline([
      entry('Advanced Mathematics', 1, 0, 30),
      entry('College Physics', 3, 60, 110),
      entry('Afternoon course', 5, 14400, 17100),
    ]);
    _previewKey = null;
    await _tickPreview(revision);
  }

  Future<void> _tickPreview(int revision) async {
    if (revision != _previewRevision || _shutDown || _preview == null) return;
    final now = _now().toUtc();
    final frame = _preview!.at(now);
    if (frame == null) return;
    await _serialize(() async {
      if (revision != _previewRevision || _shutDown) return;
      final key = frameKey(frame, 'en');
      final toast = courseToast(frame, now: now, id: previewNotificationId);
      if (key != _previewKey) {
        await _backend.show(toast);
        _previewKey = key;
      } else {
        await _backend.update(toast);
      }
    });
    if (revision == _previewRevision && !_shutDown) {
      if (frame.state == CourseLiveUpdatePreview.ended) return;
      _previewWake = Timer(const Duration(seconds: 1), () async {
        try {
          await _tickPreview(revision);
        } catch (_) {
          error.value = true;
        }
      });
    }
  }

  Future<void> clearPreview() async {
    if (!_isSupported()) return;
    ++_previewRevision;
    _previewWake?.cancel();
    _preview = null;
    _previewKey = null;
    await _serialize(() async {
      if (ready.value) await _backend.clear();
      _frameKey = null;
      if (_current(_revision)) await _tick(_revision);
    });
  }
}
