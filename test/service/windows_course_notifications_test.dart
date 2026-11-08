import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/course_live_update.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/windows_course_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backend implements WindowsToastBackend {
  final shown = <WindowsCourseToast>[];
  final updates = <WindowsCourseToast>[];
  int cleared = 0, initialized = 0;
  Future<void> Function()? activate;
  Completer<void>? initialization, showing;
  bool failShow = false;

  @override
  Future<void> initialize(Future<void> Function() onActivate) async {
    initialized++;
    activate = onActivate;
    await initialization?.future;
  }

  @override
  Future<void> show(WindowsCourseToast toast) async {
    await showing?.future;
    if (failShow) throw StateError('unavailable');
    shown.add(toast);
  }

  @override
  Future<void> update(WindowsCourseToast toast) async => updates.add(toast);

  @override
  Future<void> clear() async => cleared++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final day = DateTime.utc(2026, 11, 8, 16); // Beijing Monday, Nov 9.
  final firstStart = DateTime.utc(2026, 11, 9, 0, 20);
  final firstEnd = DateTime.utc(2026, 11, 9, 1, 55);
  final secondStart = DateTime.utc(2026, 11, 9, 2, 20);
  final secondEnd = DateTime.utc(2026, 11, 9, 3, 55);
  late AppSettings settings;
  late AppLocalizations l10n;
  late _Backend backend;
  late WindowsCourseNotifications service;
  late DateTime now;
  String? account;
  var sessionCurrent = true;
  late WindowsCourseNotificationData data;

  NextCourseWidgetEntry entry(
    String name,
    DateTime start,
    DateTime end,
    int first,
  ) => NextCourseWidgetEntry(
    name: name,
    location: 'East classroom',
    start: start,
    end: end,
    startClass: first,
    endClass: first + 1,
    week: 1,
  );

  WindowsCourseNotificationData plan({
    List<NextCourseWidgetEntry>? courses,
    List<Map<String, Object>> reminders = const [],
    bool stages = true,
    bool known = true,
  }) => WindowsCourseNotificationData(
    snapshot: NextCourseWidgetSnapshot(
      generatedAt: now,
      days: [
        NextCourseWidgetDay(
          start: day,
          known: known,
          courses:
              courses ??
              [
                entry('Mathematics', firstStart, firstEnd, 1),
                entry('Physics', secondStart, secondEnd, 3),
                entry(
                  'Afternoon',
                  day.add(const Duration(hours: 14)),
                  day.add(const Duration(hours: 15)),
                  5,
                ),
              ],
        ),
      ],
    ),
    reminders: reminders,
    l10n: l10n,
    liveEnabled: stages,
  );

  WindowsCourseNotifications make({
    Future<WindowsCourseNotificationData> Function(
      AppSettings,
      String,
      DateTime,
    )?
    load,
  }) => WindowsCourseNotifications(
    backend: backend,
    now: () => now,
    account: () => account,
    sessionFence: () =>
        () => sessionCurrent,
    isSupported: () => true,
    load: load ?? (_, _, _) async => data,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = AppSettings();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    backend = _Backend();
    now = firstStart.subtract(const Duration(seconds: 1));
    account = 'student';
    sessionCurrent = true;
    data = plan();
    service = make();
  });
  tearDown(() async {
    await service.shutdown();
    settings.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  void notificationTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        // Widget-test invariants run before package:test tearDown. Stop the
        // resident service inside the fake-clock scope, including failed tests.
        await service.shutdown();
        debugDefaultTargetPlatformOverride = null;
        await tester.pump();
      }
    });
  }

  notificationTest(
    'real stages follow current clock, update progress silently and end at morning boundary',
    (tester) async {
      await service.synchronize(settings);
      expect(backend.shown.last.title, l10n.courseLiveNext);
      now = firstStart;
      await tester.pump(const Duration(seconds: 1));
      expect(backend.shown.last.title, l10n.courseLiveInProgress);
      expect(backend.shown.last.progress, 0);
      final banners = backend.shown.length;
      now = firstStart.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
      expect(backend.shown.length, banners);
      expect(backend.updates.last.progress, greaterThan(0));
      expect(backend.updates.last.progress, lessThan(1));

      // Simulate resume after a long sleep. Only the frame at the actual clock is
      // delivered; elapsed classes are not replayed in a burst.
      now = firstEnd;
      await tester.pump(const Duration(seconds: 30));
      expect(backend.shown.last.title, l10n.courseLiveNext);
      expect(backend.shown.last.body, contains('Physics'));
      now = secondStart;
      await tester.pump(const Duration(seconds: 30));
      expect(backend.shown.last.title, l10n.courseLiveInProgress);
      expect(backend.shown.last.body, contains('Physics'));
      now = secondEnd;
      await tester.pump(const Duration(seconds: 30));
      expect(backend.shown.last.title, l10n.courseLiveEnded);
      expect(backend.shown.last.body, contains(l10n.courseLiveMorningEnded));
      expect(backend.shown.last.body, isNot(contains('Afternoon')));
    },
  );

  notificationTest('tomorrow reminder is sent once at its Beijing instant', (
    tester,
  ) async {
    final at = now.add(const Duration(seconds: 10));
    data = plan(
      stages: false,
      reminders: [
        {
          'at': at.millisecondsSinceEpoch,
          'title': 'Tomorrow',
          'body': '08:20 Mathematics',
        },
      ],
    );
    await service.synchronize(settings);
    expect(service.nextReminder.value, at);
    now = at;
    await tester.pump(const Duration(seconds: 10));
    expect(
      backend.shown.single.id,
      WindowsCourseNotifications.reminderNotificationId,
    );
    expect(backend.shown.single.body, '08:20 Mathematics');
    now = at.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    await service.synchronize(settings);
    expect(backend.shown.length, 1);
    expect(service.nextReminder.value, isNull);
  });

  notificationTest('a stale wake does not replay an old tomorrow reminder', (
    tester,
  ) async {
    final at = now.add(const Duration(seconds: 5));
    data = plan(
      stages: false,
      reminders: [
        {'at': at.millisecondsSinceEpoch, 'title': 'Tomorrow', 'body': 'stale'},
      ],
    );
    await service.synchronize(settings);
    now = at.add(const Duration(hours: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(backend.shown, isEmpty);
  });

  notificationTest(
    'logout cancels resident plans, delayed tests and cache listeners until activation',
    (tester) async {
      final unbind = service.bind(settings);
      await service.synchronize(settings);
      await service.testNotification(delay: const Duration(minutes: 1));
      await service.cancel();
      final shown = backend.shown.length;
      final cleared = backend.cleared;
      settings.courseLiveUpdatesEnabled.value = true;
      CacheHelper.changes.value++;
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await service.synchronize(
        settings,
      ); // A late, ordinary old-Home callback.
      now = firstStart;
      await tester.pump(const Duration(minutes: 1));
      expect(backend.shown.length, shown);
      expect(backend.cleared, cleared);
      expect(service.nextReminder.value, isNull);
      await service.synchronize(settings, activate: true);
      expect(backend.shown.length, shown + 1);
      unbind();
    },
  );

  notificationTest('cancel fences a cache read already in flight', (
    tester,
  ) async {
    final pending = Completer<WindowsCourseNotificationData>();
    service = make(load: (_, _, _) => pending.future);
    final syncing = service.synchronize(settings);
    await tester.pump();
    await service.cancel();
    pending.complete(data);
    await syncing;
    expect(backend.shown, isEmpty);
    expect(service.nextReminder.value, isNull);
  });

  notificationTest(
    'different account cannot publish a preceding account snapshot',
    (tester) async {
      final pending = Completer<WindowsCourseNotificationData>();
      service = make(load: (_, _, _) => pending.future);
      final syncing = service.synchronize(settings);
      await tester.pump();
      account = 'other';
      pending.complete(data);
      await syncing;
      expect(backend.shown, isEmpty);
      expect(backend.updates, isEmpty);
    },
  );

  notificationTest('a changed session fences a same-account read', (
    tester,
  ) async {
    final pending = Completer<WindowsCourseNotificationData>();
    service = make(load: (_, _, _) => pending.future);
    final syncing = service.synchronize(settings);
    await tester.pump();
    sessionCurrent = false;
    pending.complete(data);
    await syncing;
    expect(backend.shown, isEmpty);
  });

  notificationTest(
    'in-flight show is followed by logout clear, with no later callbacks',
    (tester) async {
      backend.showing = Completer<void>();
      final syncing = service.synchronize(settings);
      await tester.pump();
      final cancelling = service.cancel();
      backend.showing!.complete();
      await syncing;
      await cancelling;
      final shown = backend.shown.length;
      final cleared = backend.cleared;
      now = secondStart;
      await tester.pump(const Duration(hours: 2));
      expect(backend.shown.length, shown);
      expect(backend.cleared, cleared);
      expect(cleared, greaterThan(1));
    },
  );

  notificationTest(
    'formal toggles suppress actual plans without requiring Android permission',
    (tester) async {
      data = plan(stages: false);
      await service.synchronize(settings);
      now = firstStart;
      await tester.pump(const Duration(seconds: 30));
      expect(backend.shown, isEmpty);
      data = plan();
      await service.synchronize(settings);
      expect(backend.shown.last.title, l10n.courseLiveInProgress);
      data = plan(stages: false);
      await service.synchronize(settings);
      expect(backend.cleared, greaterThan(1));
    },
  );

  notificationTest(
    'cache and locale changes rebuild a resident plan without foreground restoration',
    (tester) async {
      var loads = 0;
      service = make(
        load: (_, _, _) async {
          loads++;
          return data;
        },
      );
      final unbind = service.bind(settings);
      await service.synchronize(settings);
      final before = loads;
      settings.localeKey.value = 'zh';
      await tester.pump();
      expect(loads, greaterThan(before));
      final afterLocale = loads;
      settings.hiddenCourseSessions.value = [];
      await tester.pump();
      expect(loads, greaterThan(afterLocale));
      unbind();
    },
  );

  notificationTest(
    'full Windows preview reaches four states and never crosses lunch',
    (tester) async {
      await service.startPreviewSequence();
      expect(backend.shown.last.title, 'Class in progress');
      expect(backend.shown.last.progress, 0);
      for (var second = 1; second <= 110; second++) {
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(backend.shown.map((toast) => toast.title), [
        'Class in progress',
        'Next class',
        'Class in progress',
        'Class ended',
      ]);
      expect(backend.shown.last.body, contains('Morning classes finished'));
      expect(backend.shown.last.body, isNot(contains('Afternoon course')));
      expect(backend.updates.first.progress, closeTo(1 / 30, 0.0001));
    },
  );

  notificationTest(
    'clear test stops its sequence and restores a formal course',
    (tester) async {
      now = firstStart;
      await service.synchronize(settings);
      await service.startPreviewSequence();
      await service.clearPreview();
      expect(
        backend.shown.last.id,
        WindowsCourseNotifications.courseNotificationId,
      );
      final banners = backend.shown.length;
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 2));
      expect(backend.shown.length, banners);
      expect(
        backend.updates.every(
          (toast) =>
              toast.id == WindowsCourseNotifications.courseNotificationId,
        ),
        isTrue,
      );
    },
  );

  notificationTest(
    'manual course preview advances progress through data-only updates',
    (tester) async {
      await service.showPreview(CourseLiveUpdatePreview.inProgress);
      final initialProgress = backend.shown.single.progress!;
      final banners = backend.shown.length;
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(backend.updates.single.progress, greaterThan(initialProgress));
      expect(backend.shown.length, banners);
    },
  );

  notificationTest('shutdown fences initialization and prevents reactivation', (
    tester,
  ) async {
    backend.initialization = Completer<void>();
    final preview = service.testNotification();
    await tester.pump();
    await service.shutdown();
    backend.initialization!.complete();
    await preview;
    await service.synchronize(settings);
    expect(backend.shown, isEmpty);
    expect(service.ready.value, isFalse);
  });

  notificationTest(
    'notification clicks use injected existing-window callback once',
    (tester) async {
      var restored = 0;
      await service.initialize(onActivate: () async => restored++);
      await service.initialize(onActivate: () async => restored++);
      await backend.activate!();
      expect(restored, 1);
      expect(backend.initialized, 1);
      await service.shutdown();
      await backend.activate!();
      expect(restored, 1);
    },
  );

  notificationTest('unknown snapshot coverage sends no course stages', (
    tester,
  ) async {
    data = plan(known: false);
    await service.synchronize(settings);
    expect(backend.shown, isEmpty);
  });

  notificationTest(
    'failed read automatically re-shows the same recovered stage',
    (tester) async {
      now = firstStart.add(const Duration(minutes: 1));
      var fail = false;
      service = make(
        load: (_, _, _) async {
          if (fail) throw const FormatException('damaged cache');
          return data;
        },
      );
      final unbind = service.bind(settings);
      await service.synchronize(settings);
      final before = backend.shown.length;
      expect(backend.shown.last.title, l10n.courseLiveInProgress);
      fail = true;
      await service.synchronize(settings);
      expect(service.error.value, isTrue);
      expect(service.nextReminder.value, isNull);
      fail = false;
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(service.error.value, isFalse);
      expect(backend.shown.length, before + 1);
      expect(backend.shown.last.title, l10n.courseLiveInProgress);
      expect(backend.shown.last.progress, greaterThan(0));
      unbind();
    },
  );

  notificationTest(
    'switching stages off during failure prevents recovery from republishing',
    (tester) async {
      now = firstStart;
      settings.courseLiveUpdatesEnabled.value = true;
      var fail = false;
      service = make(
        load: (settings, _, _) async {
          if (fail) throw const FormatException('damaged cache');
          return plan(stages: settings.courseLiveUpdatesEnabled.value);
        },
      );
      final unbind = service.bind(settings);
      await service.synchronize(settings);
      final before = backend.shown.length;
      fail = true;
      await service.synchronize(settings);
      fail = false;
      settings.courseLiveUpdatesEnabled.value = false;
      await tester.pump();
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(backend.shown.length, before);
      expect(service.error.value, isFalse);
      unbind();
    },
  );

  notificationTest(
    'an old-account failed read cannot clear the newer account toast',
    (tester) async {
      now = firstStart;
      final staleRead = Completer<WindowsCourseNotificationData>();
      service = make(
        load: (_, user, _) async {
          if (user == 'student') return staleRead.future;
          return plan(
            courses: [entry('Other account course', firstStart, firstEnd, 1)],
          );
        },
      );
      final old = service.synchronize(settings);
      await tester.pump();
      account = 'other';
      await service.synchronize(settings);
      final clears = backend.cleared;
      staleRead.completeError(const FormatException('old failed cache'));
      await old;
      expect(backend.cleared, clears);
      expect(backend.shown.single.body, contains('Other account course'));
      expect(service.error.value, isFalse);
    },
  );

  notificationTest(
    'Windows has no Android reminder or permission MethodChannel calls',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final channel in [
        CourseReminderService.channel,
        AndroidPermissionsService.channel,
      ]) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      }
      expect(CourseReminderService.supported, isTrue);
      expect(CourseReminderService.androidSupported, isFalse);
      expect(await CourseReminderService.instance.isXiaomiDevice(), isFalse);
      expect(await CourseReminderService.instance.permissions(), {
        'notifications': false,
        'exact': false,
      });
      await CourseReminderService.instance.requestPermission('requestExact');
      expect(await AndroidPermissionsService.load(), isEmpty);
      await AndroidPermissionsService.openSettings();
      expect(calls, isEmpty);
    },
  );

  test('Windows local loader reuses hidden/custom filtering and Beijing tomorrow data', () async {
    final term = const CalTerm(
      termId: 't',
      schoolYear: '2026',
      term: '202601',
      startDate: '2026-11-09',
      endDate: '2027-01-17',
    );
    final course = Course.fromJson({
      'name': 'Academic',
      'scheduleRules': [
        const CourseScheduleRule(
          location: 'A',
          startClass: 1,
          endClass: 2,
          startWeek: 1,
          endWeek: 19,
          weekday: 1,
          single: true,
          double: true,
        ).toJson(),
      ],
    });
    SharedPreferences.setMockInitialValues({
      SpKeys.cacheSchoolCalendar: jsonEncode(
        SchoolCalendar(currentTerm: term.term, terms: [term]).toJson(),
      ),
      SpKeys.cacheCoursesMap: jsonEncode({
        term.term: {
          'courses': [course.toJson()],
        },
      }),
    });
    final custom = CustomCourse(
      id: 'local',
      account: 'student',
      term: term.term,
      name: 'Local',
      startClass: 3,
      endClass: 4,
      startWeek: 1,
      endWeek: 19,
      weekday: 1,
    );
    CustomCourseStore.instance.value = [
      custom,
      CustomCourse(
        id: 'other',
        account: 'other',
        term: term.term,
        name: 'Other account',
        startClass: 3,
        endClass: 4,
        startWeek: 1,
        endWeek: 19,
        weekday: 1,
      ),
    ];
    addTearDown(() => CustomCourseStore.instance.value = []);
    settings.localeKey.value = 'en';
    settings.courseReminderEnabled.value = true;
    settings.hiddenCourseSessions.value = [
      HiddenCourseSession(
        account: 'student',
        term: term.term,
        week: 1,
        weekday: 1,
        courseKey: HiddenCourseSession.keyForCourse(course),
        name: course.name,
        teacher: course.teacher,
        location: 'A',
        startClass: 1,
        endClass: 2,
      ),
    ];
    final loaded = await WindowsCourseNotifications.loadData(
      settings,
      'student',
      DateTime.utc(2026, 11, 8, 12),
    );
    final monday = loaded.snapshot.days.firstWhere(
      (day) => day.start == thisDay(term),
    );
    expect(monday.courses.map((course) => course.name), ['Local']);
    expect(
      loaded.reminders.first['at'],
      DateTime.utc(2026, 11, 8, 13).millisecondsSinceEpoch,
    );
    expect(loaded.reminders.first['body'], contains('Local'));
    expect(loaded.reminders.first['body'], isNot(contains('Academic')));
    expect(loaded.reminders.first['body'], isNot(contains('Other account')));
  });
}

DateTime thisDay(CalTerm term) =>
    DateTime.parse('${term.startDate}T00:00:00Z')
        .subtract(const Duration(hours: 8));
