import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/calendar_export.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/calendar_export_service.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lectures_fixture.dart';
import '../fixtures/reminder_channel.dart';
import '../model/calendar_export_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient.instance;
  late HttpClientAdapter previousAdapter;
  late LecturesFixtureAdapter adapter;
  late Directory directory;
  late CalendarExportService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mockReminderChannel();
    previousAdapter = api.dio.httpClientAdapter;
    adapter = LecturesFixtureAdapter();
    api.dio.httpClientAdapter = adapter;
    await api.login('20230001', 'fixture-password', '1234');
    adapter.requests.clear();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      SpKeys.cacheSchoolCalendar,
      jsonEncode({
        'currentTerm': fixture.term.term,
        'terms': [fixture.term.toJson()],
      }),
    );
    await sp.setString(
      SpKeys.cacheCoursesMap,
      jsonEncode({
        fixture.term.term: {
          'courses': [fixture.sample().toJson()],
          'updatedAt': DateTime.utc(2026, 11, 1).millisecondsSinceEpoch,
        },
      }),
    );
    await sp.setString(
      CustomCourseStore.storageKey,
      jsonEncode([
        CustomCourse(
          id: 'mine',
          account: '20230001',
          term: fixture.term.term,
          name: '自定义',
          startClass: 3,
          endClass: 4,
          startWeek: 1,
          endWeek: 1,
          weekday: 2,
        ).toJson(),
        CustomCourse(
          id: 'other',
          account: '20230002',
          term: fixture.term.term,
          name: '其他账号',
          startClass: 3,
          endClass: 4,
          startWeek: 1,
          endWeek: 1,
          weekday: 2,
        ).toJson(),
      ]),
    );
    directory = await Directory.systemTemp.createTemp('fzu-calendar-test-');
    service = CalendarExportService(directory: () async => directory);
  });
  tearDown(() async {
    await api.clearSession();
    api.dio.httpClientAdapter = previousAdapter;
    await directory.delete(recursive: true);
  });

  test('仅使用本地缓存与当前账号自定义课程，生成可打开的 UTF-8 ICS', () async {
    final source = await service.load(
      account: '20230001',
      preferredTerm: fixture.term.term,
      useWest2Adjustments: false,
    );
    expect(source.courses.map((c) => c.name), ['数学', '自定义']);
    expect(source.updatedAt, DateTime.utc(2026, 11, 1));
    final result = CalendarExport.build(
      account: source.account,
      term: source.term,
      courses: source.courses,
      hiddenSessions: [],
      autoAdjust: true,
      includeExams: true,
      reminderMinutes: 0,
      calendarName: '课表',
      generatedAt: DateTime.utc(2026, 11),
    );
    final file = await service.save(result, source);
    expect(file.path, startsWith(directory.path));
    expect(file.path, endsWith('.ics'));
    expect(await file.readAsString(), result.content);
    expect(result.eventCount, 3);
    expect(adapter.requests, isEmpty);
    expect((await service.save(result, source)).path, file.path);
  });

  test('缺少课表不导出只有自定义课程的误导快照，退出后拒绝保存旧内容', () async {
    final source = await service.load(
      account: '20230001',
      preferredTerm: fixture.term.term,
      useWest2Adjustments: false,
    );
    await (await SharedPreferences.getInstance()).remove(
      SpKeys.cacheCoursesMap,
    );
    await expectLater(
      service.load(
        account: '20230001',
        preferredTerm: fixture.term.term,
        useWest2Adjustments: false,
      ),
      throwsStateError,
    );
    await api.clearSession();
    await expectLater(
      service.save(fixture.export([]), source),
      throwsStateError,
    );
    expect(await directory.list().length, 0);
  });
}
