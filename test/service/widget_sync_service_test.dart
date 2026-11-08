import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/calendar_sync.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/service/android_task_scheduler.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lectures_fixture.dart';
import '../fixtures/reminder_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final now = DateTime.utc(2026, 11, 5, 15);
  const term = CalTerm(
    termId: '2026012026090120270120',
    schoolYear: '2026',
    term: '202601',
    startDate: '2026-09-01',
    endDate: '2027-01-20',
  );
  final calendar = SchoolCalendar(currentTerm: '202601', terms: [term]);
  final calls = <MethodCall>[];
  Map<String, dynamic>? commit;
  var accepted = true;
  var valid = true;

  setUp(() {
    calls.clear();
    commit = null;
    accepted = true;
    valid = true;
    SharedPreferences.setMockInitialValues({
      SpKeys.cacheCoursesMap: jsonEncode({
        '202601': {'courses': [], 'updatedAt': 1},
        '202501': {'courses': []},
      }),
    });
    messenger.setMockMethodCallHandler(WidgetSyncService.channel, (call) async {
      calls.add(call);
      if (call.method == 'prepare') {
        return valid
            ? {
                'baseline': {'flutter.cache_courses_map': 'captured'},
              }
            : null;
      }
      if (call.method == 'commit') {
        commit = Map<String, dynamic>.from(call.arguments as Map);
        return accepted;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(WidgetSyncService.channel, null);
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'nightly exact alarm uses Beijing time across midnight and year end',
    () {
      expect(
        AndroidTaskScheduler.nextWidgetSync(
          DateTime.utc(2026, 11, 5, 14, 59),
          23 * 60,
        ),
        DateTime.utc(2026, 11, 5, 15),
      );
      expect(
        AndroidTaskScheduler.nextWidgetSync(now, 23 * 60),
        DateTime.utc(2026, 11, 6, 15),
      );
      expect(
        AndroidTaskScheduler.nextWidgetSync(
          DateTime.utc(2026, 12, 31, 15),
          23 * 60,
        ),
        DateTime.utc(2027, 1, 1, 15),
      );
    },
  );

  test('each generation schedules its own alarm identity', () async {
    AndroidAlarmManager.setTestOverrides(
      getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
    );
    final identities = <int>[];
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
      call,
    ) async {
      if (call.method == 'Alarm.oneShotAt') {
        identities.add((call.arguments as List).first as int);
      }
      return true;
    });
    for (final id in [1000001, 1000002]) {
      await AndroidTaskScheduler.scheduleWidgetSync(
        generation: '$id',
        minutes: 1380,
        alarmId: id,
      );
    }
    expect(identities, [1000001, 1000002]);
  });

  test(
    'logout still cancels Android alarm if native storage revocation fails',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final canceled = <int>[];
      messenger.setMockMethodCallHandler(WidgetSyncService.channel, (
        call,
      ) async {
        throw PlatformException(code: 'disk_failure');
      });
      messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
        call,
      ) async {
        if (call.method == 'Alarm.cancel') {
          canceled.add((call.arguments as List).first as int);
        }
        return true;
      });
      await WidgetSyncService().cancel();
      expect(canceled, contains(AndroidTaskScheduler.widgetSyncTaskId));
    },
  );

  test(
    'nightly alarm uses independent exact wakeup reboot-restored task',
    () async {
      AndroidAlarmManager.setTestOverrides(
        getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
      );
      final alarms = <MethodCall>[];
      messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
        call,
      ) async {
        alarms.add(call);
        return true;
      });
      await AndroidTaskScheduler.scheduleWidgetSync(
        generation: 'new-session',
        minutes: 23 * 60,
      );
      final arguments =
          alarms
                  .singleWhere((call) => call.method == 'Alarm.oneShotAt')
                  .arguments
              as List;
      expect(arguments[0], AndroidTaskScheduler.widgetSyncTaskId);
      for (final index in [2, 3, 4, 6]) {
        expect(arguments[index], isTrue);
      }
      expect(arguments[8], {'generation': 'new-session', 'task': 'widgetSync'});
    },
  );

  test(
    'canceled background generation does not schedule or access credentials',
    () async {
      messenger.setMockMethodCallHandler(WidgetSyncService.channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'getState'
            ? {'generation': 'current', 'enabled': true}
            : null;
      });
      await WidgetSyncService.runBackground('canceled');
      expect(calls.map((call) => call.method), ['getState']);
    },
  );

  test(
    'background wake lock is released even when prepared work is obsolete',
    () async {
      final alarms = <MethodCall>[];
      AndroidAlarmManager.setTestOverrides(
        getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
      );
      messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
        call,
      ) async {
        alarms.add(call);
        return true;
      });
      messenger.setMockMethodCallHandler(WidgetSyncService.channel, (
        call,
      ) async {
        calls.add(call);
        return switch (call.method) {
          'getState' => {
            'generation': 'current',
            'enabled': true,
            'minutes': 1380,
          },
          'acquireWakeLock' => true,
          _ => null,
        };
      });
      await WidgetSyncService.runBackground('current');
      expect(alarms.map((call) => call.method), [
        'AlarmService.start',
        'Alarm.oneShotAt',
      ]);
      expect(calls.map((call) => call.method), [
        'getState',
        'acquireWakeLock',
        'prepare',
        'releaseWakeLock',
      ]);
    },
  );

  test(
    'stages caches and credential-free snapshot in a single fenced commit',
    () async {
      final ok = await refreshWidgetData(
        'generation',
        now: now,
        authenticate: () async => 'account-private',
        fetchCalendar: () async => calendar,
        fetchCourses: (term) async => [
          Course(
            type: '必修',
            name: '算法设计',
            credits: '3',
            electiveType: '',
            examType: '',
            teacher: '',
            rawExamTime: '',
            remark: '',
            scheduleRules: [
              CourseScheduleRule(
                location: '西3-101',
                startClass: 1,
                endClass: 2,
                startWeek: 1,
                endWeek: 19,
                weekday: 5,
                single: true,
                double: true,
              ),
            ],
            adjustRules: [],
          ),
        ],
      );
      expect(ok, isTrue);
      expect(commit!['baseline'], {'flutter.cache_courses_map': 'captured'});
      final writes = commit!['writes'] as Map;
      final courses =
          jsonDecode(writes[SpKeys.cacheCoursesMap] as String) as Map;
      expect(courses.keys, containsAll(['202501', '202601']));
      expect(courses['202601']['updatedAt'], now.millisecondsSinceEpoch);
      final snapshot = commit!['snapshot'] as String;
      expect(snapshot, contains('算法设计'));
      expect(snapshot, isNot(contains('account-private')));
      expect(snapshot, isNot(contains('teacher')));
      // The worker does not mutate the shared cache before native acceptance.
      expect(
        jsonDecode(
          (await SharedPreferences.getInstance()).getString(
            SpKeys.cacheCoursesMap,
          )!,
        )['202601']['updatedAt'],
        1,
      );
    },
  );

  test('login/network failures keep prior caches and snapshot', () async {
    final ok = await refreshWidgetData(
      'generation',
      authenticate: () async => null,
      fetchCalendar: () async => throw StateError('must not fetch'),
    );
    expect(ok, isFalse);
    expect(commit, isNull);
    expect(calls.map((c) => c.method), ['prepare', 'markFailed']);
    expect(
      (await SharedPreferences.getInstance()).getString(SpKeys.cacheCoursesMap),
      contains('"updatedAt":1'),
    );
  });

  test('calendar disabled still refreshes caches and widget with one fetch per source', () async {
    var authentications = 0;
    var calendars = 0;
    final fetchedTerms = <String>[];
    expect(
      await refreshWidgetData(
        'generation',
        now: now,
        authenticate: () async {
          authentications++;
          return 'account';
        },
        fetchCalendar: () async {
          calendars++;
          return calendar;
        },
        fetchCourses: (term) async {
          fetchedTerms.add(term);
          return [];
        },
      ),
      isTrue,
    );
    expect(authentications, 1);
    expect(calendars, 1);
    expect(fetchedTerms, ['202601']);
    expect(commit!.containsKey('calendar'), isFalse);
    expect(commit!['writes'], contains(SpKeys.cacheCoursesMap));
    expect(commit!['snapshot'], isA<String>());
    expect(calls.map((call) => call.method), ['prepare', 'commit']);
  });

  test(
    'stale generation stops before login; refused commits do not retry',
    () async {
      valid = false;
      expect(
        await refreshWidgetData(
          'stale',
          authenticate: () async => throw StateError('must not sign in'),
        ),
        isFalse,
      );
      expect(calls.map((c) => c.method), ['prepare']);
      valid = true;
      accepted = false;
      calls.clear();
      expect(
        await refreshWidgetData(
          'generation',
          now: now,
          authenticate: () async => 'account',
          fetchCalendar: () async => calendar,
          fetchCourses: (_) async => [],
        ),
        isFalse,
      );
      expect(calls.map((c) => c.method), ['prepare', 'commit']);
    },
  );

  test('refresh chooses actual date terms and the upcoming term', () {
    final summer = SchoolCalendar(
      currentTerm: 'old-ui-term',
      terms: [
        term,
        const CalTerm(
          termId: 'next',
          schoolYear: '2027',
          term: '202602',
          startDate: '2027-02-01',
          endDate: '2027-07-01',
        ),
      ],
    );
    expect(widgetRefreshTerms(summer, DateTime.utc(2027, 1, 20, 15)), [
      '202601',
      '202602',
    ]);
  });

  test('calendar uses the same complete refresh and never includes historical cache terms', () async {
    messenger.setMockMethodCallHandler(WidgetSyncService.channel, (call) async {
      calls.add(call);
      if (call.method == 'prepare') {
        return {
          'baseline': {'captured': true},
          'calendar': {
            'enabled': true,
            'owner': calendarAccountKey('account'),
            'includeExams': false,
            'reminder': 30,
          },
        };
      }
      if (call.method == 'commit') {
        commit = Map<String, dynamic>.from(call.arguments as Map);
        return true;
      }
      return null;
    });
    expect(
      await refreshWidgetData(
        'generation',
        now: now,
        authenticate: () async => 'account',
        fetchCalendar: () async => calendar,
        fetchCourses: (_) async => [],
      ),
      isTrue,
    );
    final payload = commit!['calendar'] as Map;
    expect(payload['terms'], ['202601']);
    expect(payload['events'], isEmpty);
    expect(payload['owner'], calendarAccountKey('account'));
    expect(payload.toString(), isNot(contains('202501')));
  });

  test(
    'shared nightly schedule re-arms tomorrow even if refresh cannot prepare',
    () async {
      AndroidAlarmManager.setTestOverrides(
        getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
      );
      final alarms = <MethodCall>[];
      messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
        call,
      ) async {
        alarms.add(call);
        return true;
      });
      messenger.setMockMethodCallHandler(WidgetSyncService.channel, (
        call,
      ) async {
        calls.add(call);
        return switch (call.method) {
          'getState' => {
            'generation': 'calendar',
            'enabled': true,
            'calendarEnabled': true,
            'minutes': 1380,
          },
          'acquireWakeLock' => true,
          _ => null,
        };
      });
      await WidgetSyncService.runBackground('calendar');
      expect(alarms.map((call) => call.method), contains('Alarm.oneShotAt'));
      expect(calls.map((call) => call.method), [
        'getState',
        'acquireWakeLock',
        'prepare',
        'releaseWakeLock',
      ]);
    },
  );

  test(
    'shared automatic off prevents calendar from rearming a background task',
    () async {
      messenger.setMockMethodCallHandler(WidgetSyncService.channel, (
        call,
      ) async {
        calls.add(call);
        return {
          'generation': 'paused',
          'enabled': false,
          'calendarEnabled': true,
        };
      });
      await WidgetSyncService.runBackground('paused');
      expect(calls.map((call) => call.method), ['getState']);
    },
  );

  test(
    'changing nightly settings replaces the live-course alarm generation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({
        SpKeys.courseLiveUpdatesEnabled: true,
      });
      AndroidAlarmManager.setTestOverrides(
        getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
      );
      mockReminderChannel();
      final api = ApiClient.instance;
      final previousAdapter = api.dio.httpClientAdapter;
      api.dio.httpClientAdapter = LecturesFixtureAdapter();
      final state = <String, dynamic>{'enabled': false, 'minutes': 1380};
      final instant = DateTime.now().toUtc();
      final snapshot = jsonEncode({
        'version': 1,
        'signedIn': true,
        'locale': 'en',
        'days': [
          {
            'start': instant
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch,
            'known': true,
            'courses': [
              {
                'name': 'Upcoming class',
                'location': 'Room A',
                'start': instant
                    .add(const Duration(minutes: 10))
                    .millisecondsSinceEpoch,
                'end': instant
                    .add(const Duration(minutes: 55))
                    .millisecondsSinceEpoch,
                'startClass': 1,
                'endClass': 1,
              },
            ],
          },
        ],
      });
      final alarms = <Map>[];
      final service = WidgetSyncService();
      messenger.setMockMethodCallHandler(WidgetSyncService.channel, (
        call,
      ) async {
        if (call.method == 'getState') return state;
        if (call.method == 'configure') {
          state.addAll(Map<String, dynamic>.from(call.arguments as Map));
        }
        if (call.method == 'readLiveUpdateSnapshot') {
          return {'generation': state['generation'], 'snapshot': snapshot};
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async =>
            [
              'getNotificationChannels',
              'getActiveNotifications',
            ].contains(call.method)
            ? []
            : true,
      );
      messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
        call,
      ) async {
        if (call.method == 'Alarm.oneShotAt') {
          final args = call.arguments as List;
          if (args.first == AndroidTaskScheduler.courseLiveTaskId) {
            alarms.add(args[8] as Map);
          }
        }
        return true;
      });
      try {
        await api.login('20230001', 'test-only', '1234');
        await service.configure(enabled: false, minutes: 1380);
        final firstGeneration = state['generation'];
        await service.configure(minutes: 1320);
        expect(alarms.map((alarm) => alarm['generation']), [
          firstGeneration,
          state['generation'],
        ]);
        expect(state['generation'], isNot(firstGeneration));
        expect(
          alarms.every((alarm) => alarm['task'] == 'courseLiveUpdate'),
          isTrue,
        );
      } finally {
        await api.clearSession();
        api.dio.httpClientAdapter = previousAdapter;
        service.enabled.dispose();
        service.minutes.dispose();
        service.status.dispose();
        messenger.setMockMethodCallHandler(CourseReminderService.channel, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          null,
        );
      }
    },
  );

  test('manual refresh reserves before reconciliation and works with automatic sync and exact alarms off', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterSecureStorage.setMockInitialValues({});
    mockReminderChannel();
    final api = ApiClient.instance;
    final previousAdapter = api.dio.httpClientAdapter;
    api.dio.httpClientAdapter = LecturesFixtureAdapter();
    final state = <String, dynamic>{
      'enabled': false,
      'calendarEnabled': true,
      'minutes': 1380,
    };
    final alarms = <String>[];
    final entered = Completer<void>();
    final finish = Completer<bool>();
    var refreshes = 0;
    final service = WidgetSyncService(
      refresh: (_) async {
        refreshes++;
        entered.complete();
        return finish.future;
      },
    );
    messenger.setMockMethodCallHandler(WidgetSyncService.channel, (call) async {
      if (call.method == 'getState') return state;
      if (call.method == 'configure') {
        state.addAll(Map<String, dynamic>.from(call.arguments as Map));
      }
      return null;
    });
    messenger.setMockMethodCallHandler(CourseReminderService.channel, (
      _,
    ) async {
      return {'notifications': false, 'exact': false};
    });
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
      call,
    ) async {
      alarms.add(call.method);
      return true;
    });
    try {
      await api.login('20230001', 'test-only', '1234');
      final first = service.refreshNow();
      expect(await service.refreshNow(), isFalse);
      await entered.future;
      expect(refreshes, 1);
      expect(service.status.value.running, isTrue);
      expect(service.status.value.nextAt, isNull);
      expect(alarms, isNot(contains('Alarm.oneShotAt')));
      finish.complete(true);
      expect(await first, isTrue);
      expect(service.status.value.running, isFalse);
      expect(service.enabled.value, isFalse);
      expect(service.status.value.exactAllowed, isFalse);
    } finally {
      await api.clearSession();
      api.dio.httpClientAdapter = previousAdapter;
      service.enabled.dispose();
      service.minutes.dispose();
      service.status.dispose();
      messenger.setMockMethodCallHandler(CourseReminderService.channel, null);
    }
  });
}
