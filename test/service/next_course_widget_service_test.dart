import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/next_course_widget_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Use the existing plugin's test backend to simulate another engine's writes.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../fixtures/reminder_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final now = DateTime.utc(2026, 9, 13, 16);
  late NextCourseWidgetService service;
  late AppSettings settings;
  final calls = <MethodCall>[];
  final calendar = const SchoolCalendar(
    currentTerm: '202601',
    terms: [
      CalTerm(
        termId: 'fall',
        schoolYear: '2026',
        term: '202601',
        startDate: '2026-09-07',
        endDate: '2027-01-17',
      ),
    ],
  ).toJson();
  final courses = {
    '202601': {
      'courses': [
        Course.fromJson({
          'name': '高数',
          'scheduleRules': [
            const CourseScheduleRule(
              location: '东 301',
              startClass: 1,
              endClass: 2,
              startWeek: 1,
              endWeek: 19,
              weekday: 1,
              single: true,
              double: true,
            ).toJson(),
          ],
        }).toJson(),
      ],
    },
  };
  void seedCaches() {
    SharedPreferences.setMockInitialValues({
      SpKeys.cacheSchoolCalendar: jsonEncode(calendar),
      SpKeys.cacheCoursesMap: jsonEncode(courses),
    });
  }

  Future<void> writeCoursesFromBackground(String name) async {
    final updated = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(courses)) as Map,
    );
    ((updated['202601'] as Map)['courses'] as List).single['name'] = name;
    await SharedPreferencesStorePlatform.instance.setValue(
      'String',
      'flutter.${SpKeys.cacheCoursesMap}',
      jsonEncode(updated),
    );
  }

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mockReminderChannel();
    messenger.setMockMethodCallHandler(
      NextCourseWidgetService.backgroundChannel,
      (call) async => null,
    );
    FlutterSecureStorage.setMockInitialValues({});
    seedCaches();
    final storage = AuthStorage();
    await storage.saveCredentials('student', 'test-only');
    await storage.saveAcademicSession({
      'studentId': 'student',
      'userId': 'cached-identifier',
      'cookies': ['session=test; Path=/'],
    });
    expect(await ApiClient.instance.restoreCachedSession(), isTrue);
    service = NextCourseWidgetService(now: () => now);
    settings = AppSettings();
    calls.clear();
    messenger.setMockMethodCallHandler(NextCourseWidgetService.channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'requestPin' ? true : null;
    });
  });
  tearDown(() async {
    await service.clear();
    await ApiClient.instance.clearSession();
    settings.dispose();
    service.error.dispose();
    service.snapshot.dispose();
    messenger.setMockMethodCallHandler(NextCourseWidgetService.channel, null);
    messenger.setMockMethodCallHandler(
      NextCourseWidgetService.backgroundChannel,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'uses cached actual term even when the visible timetable selects history',
    () async {
      settings.selectedSemesterKey.value = '202501';
      settings.localeKey.value = 'en';
      await service.sync(settings);
      final snapshot = service.snapshot.value!;
      expect(snapshot.select(now).courses.single.name, '高数');
      expect(snapshot.locale, 'en');
      expect(calls.single.method, 'setSnapshot');
      final raw = calls.single.arguments as String;
      expect(raw, isNot(contains('student')));
      expect(raw, isNot(contains('cached-identifier')));
      expect(raw, isNot(contains('session=test')));
      expect(service.error.value, isFalse);
    },
  );

  test('a foreground course cache write refreshes the bound widget without fetching', () async {
    final unbind = service.bind(settings);
    addTearDown(unbind);
    await service.sync(settings);
    calls.clear();
    final updated = Completer<void>();
    void changed() {
      if (service.snapshot.value?.select(now).courses.single.name == '前台刷新课程') {
        if (!updated.isCompleted) updated.complete();
      }
    }

    service.snapshot.addListener(changed);
    addTearDown(() => service.snapshot.removeListener(changed));
    final cache = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(courses)) as Map,
    );
    ((cache['202601'] as Map)['courses'] as List).single['name'] = '前台刷新课程';
    await CacheHelper.saveMap(SpKeys.cacheCoursesMap, cache);
    await updated.future.timeout(const Duration(seconds: 5));
    expect(calls.map((call) => call.method), ['setSnapshot']);
    expect(service.snapshot.value!.select(now).courses.single.name, '前台刷新课程');
  });

  group('local calendar publication', () {
    Map<String, Object> calendarConfig({
      bool enabled = true,
      bool granted = true,
      String account = 'student',
    }) => {
      'enabled': enabled,
      'granted': granted,
      'owner': calendarAccountKey(account),
      'includeExams': false,
      'reminder': 30,
    };

    final publications = <Map<String, dynamic>>[];
    late Map<String, Object> config;
    final nativeCalls = <String>[];

    setUp(() {
      publications.clear();
      nativeCalls.clear();
      config = calendarConfig();
      messenger.setMockMethodCallHandler(
        NextCourseWidgetService.backgroundChannel,
        (call) async {
          nativeCalls.add(call.method);
          if (call.method == 'readInputs') {
            return {
              'baseline': {'revision': 'captured'},
              'calendar': config,
            };
          }
          if (call.method == 'publishSnapshot') {
            publications.add(Map<String, dynamic>.from(call.arguments as Map));
            return true;
          }
          throw StateError('Local publication must not use ${call.method}');
        },
      );
    });

    test(
      'enabled calendar uses the widget cache and captured settings',
      () async {
        await service.sync(settings);
        final publication = publications.single;
        final payload = publication['calendar'] as Map;
        expect(
          publication.keys,
          unorderedEquals(['baseline', 'snapshot', 'calendar']),
        );
        expect(publication['baseline'], {'revision': 'captured'});
        expect(payload['owner'], calendarAccountKey('student'));
        expect(payload['terms'], ['202601']);
        final events = payload['events'] as List;
        expect(events, isNotEmpty);
        expect(events.every((event) => event['title'] == '高数'), isTrue);
        expect(events.every((event) => event['reminder'] == 30), isTrue);
        expect(events.every((event) => event['rrule'] != null), isTrue);
        expect(service.snapshot.value!.select(now).courses.single.name, '高数');
        expect(nativeCalls, ['readInputs', 'publishSnapshot']);
        expect(calls, isEmpty);
      },
    );

    for (final scenario in ['default', 'disabled', 'denied', 'other account']) {
      test('$scenario never supplies a calendar write', () async {
        config = switch (scenario) {
          'default' => {},
          'disabled' => calendarConfig(enabled: false),
          'denied' => calendarConfig(granted: false),
          _ => calendarConfig(account: 'another-student'),
        };
        await service.sync(settings);
        expect(publications.single.containsKey('calendar'), isFalse);
        expect(service.snapshot.value!.select(now).courses.single.name, '高数');
        expect(nativeCalls, ['readInputs', 'publishSnapshot']);
      });
    }

    test(
      'a foreground course cache change updates both local payloads',
      () async {
        final unbind = service.bind(settings);
        addTearDown(unbind);
        await service.sync(settings);
        publications.clear();
        final updated = Completer<void>();
        void changed() {
          if (service.snapshot.value?.select(now).courses.single.name ==
                  '本地更新课程' &&
              !updated.isCompleted) {
            updated.complete();
          }
        }

        service.snapshot.addListener(changed);
        addTearDown(() => service.snapshot.removeListener(changed));
        final cache = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(courses)) as Map,
        );
        ((cache['202601'] as Map)['courses'] as List).single['name'] = '本地更新课程';
        await CacheHelper.saveMap(SpKeys.cacheCoursesMap, cache);
        await updated.future.timeout(const Duration(seconds: 5));
        expect(publications, hasLength(1));
        final publication = publications.single;
        expect(publication['snapshot'], contains('本地更新课程'));
        expect(jsonEncode(publication['calendar']), contains('本地更新课程'));
        expect(
          nativeCalls,
          everyElement(isIn(['readInputs', 'publishSnapshot'])),
        );
      },
    );

    test(
      'disable during a build rejects the old payload and rebuilds without it',
      () async {
        var reads = 0;
        messenger.setMockMethodCallHandler(
          NextCourseWidgetService.backgroundChannel,
          (call) async {
            if (call.method == 'readInputs') {
              return {
                'baseline': {'revision': ++reads},
                'calendar': config,
              };
            }
            if (call.method == 'publishSnapshot') {
              publications.add(
                Map<String, dynamic>.from(call.arguments as Map),
              );
              if (publications.length == 1) {
                config = calendarConfig(enabled: false);
                return false;
              }
              return true;
            }
            throw StateError('Unexpected method ${call.method}');
          },
        );
        await service.sync(settings);
        expect(publications, hasLength(2));
        expect(publications.first.containsKey('calendar'), isTrue);
        expect(publications.last.containsKey('calendar'), isFalse);
        expect(service.error.value, isFalse);
      },
    );

    test('missing and damaged course terms preserve calendar events', () async {
      for (final cache in [
        <String, Object>{},
        {
          '202601': {'courses': 'damaged'},
        },
      ]) {
        publications.clear();
        await CacheHelper.saveMap(SpKeys.cacheCoursesMap, cache);
        await service.sync(settings);
        expect(publications.single.containsKey('calendar'), isFalse);
        expect(service.error.value, isFalse);
        expect(
          service.snapshot.value!.select(now).state,
          NextCourseWidgetState.unknown,
        );
      }
    });

    test('empty complete term can remove obsolete managed events', () async {
      await CacheHelper.saveMap(SpKeys.cacheCoursesMap, {
        '202601': {'courses': []},
      });
      await service.sync(settings);
      final payload = publications.single['calendar'] as Map;
      expect(payload['terms'], ['202601']);
      expect(payload['events'], isEmpty);
    });

    test(
      'only cached current and nearby terms enter the replacement',
      () async {
        await CacheHelper.saveMap(SpKeys.cacheSchoolCalendar, {
          ...calendar,
          'terms': [
            ...(calendar['terms'] as List),
            const CalTerm(
              termId: 'history',
              schoolYear: '2025',
              term: '202501',
              startDate: '2025-09-01',
              endDate: '2026-01-20',
            ).toJson(),
            const CalTerm(
              termId: 'future',
              schoolYear: '2027',
              term: '202602',
              startDate: '2027-02-01',
              endDate: '2027-07-01',
            ).toJson(),
          ],
        });
        await CacheHelper.saveMap(SpKeys.cacheCoursesMap, {
          ...courses,
          '202501': courses['202601'],
          '202602': courses['202601'],
        });
        await service.sync(settings);
        expect((publications.single['calendar'] as Map)['terms'], ['202601']);
      },
    );

    test(
      'logout while reading inputs cannot publish a calendar payload',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        messenger.setMockMethodCallHandler(
          NextCourseWidgetService.backgroundChannel,
          (call) async {
            nativeCalls.add(call.method);
            if (call.method == 'readInputs') {
              entered.complete();
              await release.future;
              return {
                'baseline': {'revision': 'old-account'},
                'calendar': config,
              };
            }
            throw StateError('Logout must fence ${call.method}');
          },
        );
        final syncing = service.sync(settings);
        await entered.future;
        await service.clear();
        release.complete();
        await syncing;
        expect(nativeCalls, ['readInputs']);
        expect(calls.map((call) => call.method), ['clear']);
        expect(service.snapshot.value, isNull);
      },
    );
  });

  test(
    'public holiday cache is used only after explicit feature permission',
    () async {
      await CacheHelper.saveMap(SpKeys.cacheHolidayAdjustmentsMap, {
        '202601': [
          {'enabled': true, 'from_week': 2, 'from_weekday': 1, 'to_date': ''},
        ],
      });
      await service.sync(settings);
      expect(service.snapshot.value!.days.first.courses, isNotEmpty);
      settings.west2AdjustmentsAccess.value = FeatureAccess.allow;
      await service.sync(settings);
      expect(service.snapshot.value!.days.first.courses, isEmpty);
      settings.autoAdjustCourse.value = false;
      await service.sync(settings);
      expect(service.snapshot.value!.days.first.courses, isNotEmpty);
    },
  );

  test(
    'clear waits behind an in-flight native write and leaves no snapshot',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      messenger.setMockMethodCallHandler(NextCourseWidgetService.channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'setSnapshot') {
          entered.complete();
          await release.future;
        }
        return null;
      });
      final syncing = service.sync(settings);
      await entered.future;
      final clearing = service.clear();
      release.complete();
      await Future.wait([syncing, clearing]);
      expect(calls.map((call) => call.method), ['setSnapshot', 'clear']);
      expect(service.snapshot.value, isNull);
    },
  );

  test(
    'logout suspends listeners until authenticated Home explicitly syncs',
    () async {
      final unbind = service.bind(settings);
      await service.sync(settings);
      await service.clear();
      calls.clear();
      settings.hiddenCourseSessions.value = [];
      CacheHelper.changes.value++;
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
      await service.sync(settings);
      expect(calls.single.method, 'setSnapshot');
      unbind();
    },
  );

  test('signed-out cached data cannot populate a native snapshot', () async {
    await ApiClient.instance.clearSession();
    seedCaches();
    calls.clear();
    await service.sync(settings);
    final snapshot = service.snapshot.value!;
    expect(snapshot.signedIn, isFalse);
    expect(snapshot.days.every((day) => day.courses.isEmpty), isTrue);
    expect(snapshot.select(now).state, NextCourseWidgetState.signedOut);
    expect(calls.single.arguments, isNot(contains('高数')));
  });

  test(
    'damaged cached data becomes unknown or invalidated, never no classes',
    () async {
      await CacheHelper.saveMap(SpKeys.cacheCoursesMap, {
        '202601': {'courses': 'damaged'},
      });
      await service.sync(settings);
      expect(
        service.snapshot.value!.select(now).state,
        NextCourseWidgetState.unknown,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(SpKeys.cacheSchoolCalendar, 'not json');
      calls.clear();
      await service.sync(settings);
      expect(service.error.value, isTrue);
      expect(service.snapshot.value, isNull);
      expect(calls.single.method, 'invalidate');
    },
  );

  test('native clear failures never block the academic logout flow', () async {
    await service.sync(settings);
    calls.clear();
    messenger.setMockMethodCallHandler(NextCourseWidgetService.channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'clear') {
        throw PlatformException(code: 'storage_unavailable');
      }
      return null;
    });
    await expectLater(service.clear(), completes);
    expect(service.snapshot.value, isNull);
    expect(service.error.value, isTrue);
    expect(calls.map((call) => call.method), ['clear', 'invalidate']);
  });

  test('pinning defaults to square and reports launcher support', () async {
    expect(await service.requestPin(), isTrue);
    expect(calls.single.method, 'requestPin');
    expect(calls.single.arguments, {'variant': 'square'});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    expect(await service.requestPin(), isFalse);
    expect(calls, isEmpty);
  });

  test('each pin variant selects its corresponding native provider', () async {
    for (final variant in NextCourseWidgetVariant.values) {
      expect(await service.requestPin(variant: variant), isTrue);
    }
    expect(calls.map((call) => call.arguments), [
      {'variant': 'compact'},
      {'variant': 'square'},
      {'variant': 'timetable'},
    ]);
    expect(calls.every((call) => call.method == 'requestPin'), isTrue);
  });

  test('unavailable pin handlers return false for every widget size', () async {
    messenger.setMockMethodCallHandler(NextCourseWidgetService.channel, (
      call,
    ) async {
      throw PlatformException(code: 'unsupported');
    });
    for (final variant in NextCourseWidgetVariant.values) {
      expect(await service.requestPin(variant: variant), isFalse);
    }
  });

  test(
    'only valid actual-term cache timestamps describe source freshness',
    () async {
      final updated = now.subtract(const Duration(hours: 5));
      for (final raw in [
        updated.millisecondsSinceEpoch,
        updated.toIso8601String(),
      ]) {
        await CacheHelper.saveMap(SpKeys.cacheCoursesMap, {
          '202601': {...courses['202601']!, 'updatedAt': raw},
          '202501': {
            ...courses['202601']!,
            'updatedAt': now.millisecondsSinceEpoch,
          },
        });
        settings.selectedSemesterKey.value = '202501';
        await service.sync(settings);
        expect(service.snapshot.value!.sourceUpdatedAt, updated);
        final json = jsonDecode(calls.last.arguments as String) as Map;
        expect(json['sourceUpdatedAt'], updated.millisecondsSinceEpoch);
        expect(service.snapshot.value!.select(now).courses, hasLength(1));
      }
      for (final invalid in [
        null,
        'not a date',
        '2026-09-13T08:00:00',
        -1,
        9223372036854775807,
        now.add(const Duration(days: 1)).millisecondsSinceEpoch,
      ]) {
        await CacheHelper.saveMap(SpKeys.cacheCoursesMap, {
          '202601': {...courses['202601']!, 'updatedAt': invalid},
        });
        await service.sync(settings);
        expect(service.snapshot.value!.sourceUpdatedAt, isNull);
        expect(service.snapshot.value!.select(now).courses, hasLength(1));
        expect(service.error.value, isFalse);
      }
    },
  );

  test(
    'captures native inputs before reloading foreground preferences',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final cached = preferences.getString(SpKeys.cacheCoursesMap);
      final guardedCalls = <String>[];
      const baseline = {
        'opaque-inputs': ['revision-2', null, false],
        'configuration': {'locale': 'system'},
      };
      messenger.setMockMethodCallHandler(
        NextCourseWidgetService.backgroundChannel,
        (call) async {
          guardedCalls.add(call.method);
          if (call.method == 'readInputs') {
            expect(preferences.getString(SpKeys.cacheCoursesMap), cached);
            await writeCoursesFromBackground('后台最新课程');
            // Disk changed, but this isolate still sees the old cache.
            expect(preferences.getString(SpKeys.cacheCoursesMap), cached);
            return {'baseline': baseline};
          }
          if (call.method == 'publishSnapshot') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            expect(args['baseline'], baseline);
            expect(args.keys, unorderedEquals(['baseline', 'snapshot']));
            expect(args['snapshot'], contains('后台最新课程'));
            return true;
          }
          return null;
        },
      );

      await service.sync(settings);

      expect(guardedCalls, ['readInputs', 'publishSnapshot']);
      expect(service.snapshot.value!.select(now).courses.single.name, '后台最新课程');
      expect(preferences.getString(SpKeys.cacheCoursesMap), contains('后台最新课程'));
      expect(calls, isEmpty);
      expect(service.error.value, isFalse);
    },
  );

  test('native snapshot uses captured custom courses and settings before memory catches up', () async {
    final official = Course.fromJson(
      Map<String, dynamic>.from(
        (courses['202601']!['courses'] as List).single as Map,
      ),
    );
    final moved = Course.fromJson({
      ...official.toJson(),
      'name': '调到周二',
      'scheduleRules': [
        const CourseScheduleRule(
          location: '东 301',
          startClass: 5,
          endClass: 6,
          startWeek: 1,
          endWeek: 19,
          weekday: 1,
          single: true,
          double: true,
        ).toJson(),
      ],
      'adjustRules': [
        const CourseAdjustRule(
          oldWeek: 2,
          oldWeekday: 1,
          oldStartClass: 5,
          oldEndClass: 6,
          newWeek: 2,
          newWeekday: 2,
          newStartClass: 5,
          newEndClass: 6,
          newLocation: '西 102',
        ).toJson(),
      ],
    });
    await CacheHelper.saveMap(SpKeys.cacheCoursesMap, {
      '202601': {
        'courses': [official.toJson(), moved.toJson()],
      },
    });
    CustomCourse custom(String name) => CustomCourse(
      id: name,
      account: 'student',
      term: '202601',
      name: name,
      weekday: 1,
      startClass: 3,
      endClass: 4,
      startWeek: 1,
      endWeek: 19,
    );
    HiddenCourseSession hidden(Course course, int start, int end) =>
        HiddenCourseSession(
          account: 'student',
          term: '202601',
          courseKey: HiddenCourseSession.keyForCourse(course),
          name: course.name,
          teacher: course.teacher,
          location: '',
          week: 2,
          weekday: 1,
          startClass: start,
          endClass: end,
        );
    final nativeCustom = custom('基线自定义课程');
    final store = CustomCourseStore.instance;
    final previous = store.value;
    addTearDown(() => store.value = previous);
    store.value = [custom('尚未更新的内存课程')];
    settings.autoAdjustCourse.value = false;
    settings.localeKey.value = 'zh';
    settings.hiddenCourseSessions.value = [
      hidden(nativeCustom.toCourse(), 3, 4),
    ];
    final baseline = {
      'flutter.${CustomCourseStore.storageKey}': jsonEncode([
        nativeCustom.toJson(),
      ]),
      'flutter.${SpKeys.hiddenCourseSessions}': jsonEncode([
        {'invalid': true},
        hidden(official, 1, 2).toJson(),
      ]),
      'flutter.${SpKeys.autoAdjustCourse}': true,
      'flutter.${SpKeys.west2AdjustmentsAccess}': 'hide',
      'flutter.${SpKeys.localeKey}': 'en',
    };
    messenger.setMockMethodCallHandler(
      NextCourseWidgetService.backgroundChannel,
      (call) async {
        if (call.method == 'readInputs') return {'baseline': baseline};
        if (call.method == 'publishSnapshot') {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          expect(args['baseline'], baseline);
          expect(args['snapshot'], contains('基线自定义课程'));
          expect(args['snapshot'], isNot(contains('尚未更新的内存课程')));
          return true;
        }
        return null;
      },
    );

    await service.sync(settings);

    final snapshot = service.snapshot.value!;
    expect(snapshot.days.first.courses.single.name, '基线自定义课程');
    expect(snapshot.days[1].courses.single.name, '调到周二');
    expect(snapshot.days[1].courses.single.location, '西 102');
    expect(snapshot.locale, 'en');
    expect(settings.autoAdjustCourse.value, isFalse);
    expect(settings.localeKey.value, 'zh');
    expect(store.value.single.name, '尚未更新的内存课程');
    expect(calls, isEmpty);
    expect(service.error.value, isFalse);
  });

  test(
    'native west2 access follows captured permission and legacy migration',
    () async {
      await CacheHelper.saveMap(SpKeys.cacheHolidayAdjustmentsMap, {
        '202601': [
          {'enabled': true, 'from_week': 2, 'from_weekday': 1, 'to_date': ''},
        ],
      });
      settings.west2AdjustmentsAccess.value = FeatureAccess.hide;
      for (final (access, legacy, suppressed) in [
        ('allow', false, true),
        ('hide', true, false),
        ('tip', true, false),
        ('invalid', true, false),
        (null, true, true),
        (null, false, false),
      ]) {
        final baseline = {
          'flutter.${SpKeys.west2AdjustmentsAccess}': access,
          'flutter.${SpKeys.west2AdjustmentsEnabled}': legacy,
        };
        messenger.setMockMethodCallHandler(
          NextCourseWidgetService.backgroundChannel,
          (call) async => switch (call.method) {
            'readInputs' => {'baseline': baseline},
            'publishSnapshot' => true,
            _ => null,
          },
        );

        await service.sync(settings);

        expect(
          service.snapshot.value!.days.first.courses.isEmpty,
          suppressed,
          reason: 'captured access=$access, legacy=$legacy',
        );
        expect(service.error.value, isFalse);
      }
      expect(calls, isEmpty);
    },
  );

  test(
    'null native baseline keeps local custom course and locale behavior',
    () async {
      final store = CustomCourseStore.instance;
      final previous = store.value;
      addTearDown(() => store.value = previous);
      store.value = [
        CustomCourse(
          id: 'local',
          account: 'student',
          term: '202601',
          name: '旧宿主本地课程',
          weekday: 1,
          startClass: 3,
          endClass: 4,
          startWeek: 1,
          endWeek: 19,
        ),
      ];
      settings.localeKey.value = 'en';

      await service.sync(settings);

      expect(
        service.snapshot.value!.days.first.courses.map((course) => course.name),
        ['高数', '旧宿主本地课程'],
      );
      expect(service.snapshot.value!.locale, 'en');
      expect(calls.single.method, 'setSnapshot');
    },
  );

  test(
    'refused foreground snapshot rebuilds with the latest background cache',
    () async {
      await service.sync(settings);
      final previous = service.snapshot.value;
      calls.clear();
      var reads = 0;
      final published = <Map>[];
      final visible = <NextCourseWidgetSnapshot?>[];
      void recordVisible() => visible.add(service.snapshot.value);
      service.snapshot.addListener(recordVisible);
      addTearDown(() => service.snapshot.removeListener(recordVisible));
      messenger.setMockMethodCallHandler(
        NextCourseWidgetService.backgroundChannel,
        (call) async {
          if (call.method == 'readInputs') {
            reads++;
            return {
              'baseline': {'revision': reads},
            };
          }
          if (call.method == 'publishSnapshot') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            expect(args['baseline'], {'revision': reads});
            published.add(jsonDecode(args['snapshot'] as String) as Map);
            if (published.length == 1) {
              expect(service.snapshot.value, same(previous));
              await writeCoursesFromBackground('后台提交的新课');
              return false;
            }
            return true;
          }
          return null;
        },
      );

      await service.sync(settings);

      expect(reads, 2);
      expect(published, hasLength(2));
      expect(jsonEncode(published.first), contains('高数'));
      expect(jsonEncode(published.last), contains('后台提交的新课'));
      expect(visible, hasLength(1));
      expect(visible.single!.select(now).courses.single.name, '后台提交的新课');
      expect(calls, isEmpty);
      expect(service.error.value, isFalse);
    },
  );

  test(
    'repeated native refusal is bounded and preserves the accepted snapshot',
    () async {
      await service.sync(settings);
      final previous = service.snapshot.value;
      calls.clear();
      var reads = 0;
      var publications = 0;
      messenger.setMockMethodCallHandler(
        NextCourseWidgetService.backgroundChannel,
        (call) async {
          if (call.method == 'readInputs') {
            return {
              'baseline': {'revision': ++reads},
            };
          }
          if (call.method == 'publishSnapshot') {
            publications++;
            return false;
          }
          return null;
        },
      );

      await service.sync(settings);

      expect(reads, 3);
      expect(publications, 3);
      expect(service.snapshot.value, same(previous));
      expect(service.error.value, isFalse);
      // In particular, rejection never falls back to unguarded publication or
      // invalidates the background worker's already accepted native snapshot.
      expect(calls, isEmpty);
    },
  );

  test(
    'logout fences a refused in-flight publish and prevents its retry',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final guardedCalls = <String>[];
      messenger.setMockMethodCallHandler(
        NextCourseWidgetService.backgroundChannel,
        (call) async {
          guardedCalls.add(call.method);
          if (call.method == 'readInputs') {
            return {
              'baseline': {'revision': 1},
            };
          }
          if (call.method == 'publishSnapshot') {
            entered.complete();
            await release.future;
            return false;
          }
          return null;
        },
      );

      final syncing = service.sync(settings);
      await entered.future;
      final clearing = service.clear();
      expect(calls, isEmpty);
      release.complete();
      await Future.wait([syncing, clearing]);

      expect(guardedCalls, ['readInputs', 'publishSnapshot']);
      expect(calls.map((call) => call.method), ['clear']);
      expect(service.snapshot.value, isNull);
      expect(service.error.value, isFalse);
    },
  );

  test('missing native input bridge retains legacy host support', () async {
    messenger.setMockMethodCallHandler(
      NextCourseWidgetService.backgroundChannel,
      (call) async {
        throw MissingPluginException('Older native host');
      },
    );

    await service.sync(settings);

    expect(calls.single.method, 'setSnapshot');
    expect(service.snapshot.value!.select(now).courses.single.name, '高数');
    expect(service.error.value, isFalse);
  });

  test(
    'logout while reading native inputs cannot publish or rebuild',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final guardedCalls = <String>[];
      messenger.setMockMethodCallHandler(
        NextCourseWidgetService.backgroundChannel,
        (call) async {
          guardedCalls.add(call.method);
          if (call.method == 'readInputs') {
            entered.complete();
            await release.future;
            return {
              'baseline': {'revision': 1},
            };
          }
          return true;
        },
      );

      final syncing = service.sync(settings);
      await entered.future;
      await service.clear();
      release.complete();
      await syncing;

      expect(guardedCalls, ['readInputs']);
      expect(calls.map((call) => call.method), ['clear']);
      expect(service.snapshot.value, isNull);
      expect(service.error.value, isFalse);
    },
  );

  test('missing publish method retains legacy host support', () async {
    messenger.setMockMethodCallHandler(
      NextCourseWidgetService.backgroundChannel,
      (call) async {
        if (call.method == 'readInputs') {
          return {
            'baseline': {'revision': 1},
          };
        }
        throw MissingPluginException('Older native host');
      },
    );

    await service.sync(settings);

    expect(calls.single.method, 'setSnapshot');
    expect(service.snapshot.value!.select(now).courses.single.name, '高数');
    expect(service.error.value, isFalse);
  });
}
