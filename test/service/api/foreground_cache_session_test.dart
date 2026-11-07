import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/service/academic_changes_service.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/api/session_expired_exception.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/reminder_channel.dart';
import 'academic_changes_fetch_test.dart' show ChangesAdapter;

const _term = '202601';
const _termId = '2026012026083120270124';
const _cacheKeys = [
  SpKeys.cacheCoursesMap,
  SpKeys.cacheExamRoomsMap,
  SpKeys.cacheSchoolCalendar,
  SpKeys.cacheTermEventsMap,
  SpKeys.cacheHolidayAdjustmentsMap,
  AcademicChangesService.storageKey,
];

/// Reuse the login/course/marks fixtures, delaying one successful response.
class _DelayedAdapter extends ChangesAdapter {
  String student = '20230001';
  String identifier = 'SESSION-A';
  String? heldPath, heldMethod;
  final arrived = Completer<void>();
  final release = Completer<void>();
  String? expiryPath, expiryMethod;
  bool expiryAsGbkHtml = false;
  bool expired = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final ResponseBody response;
    if (path.endsWith('/verifycode.asp')) {
      requests.add(options);
      response = ResponseBody.fromBytes(
        img.encodePng(img.Image(width: 48, height: 10)),
        200,
      );
    } else if (!expired &&
        path.endsWith(expiryPath ?? '\u0000') &&
        options.method == expiryMethod) {
      requests.add(options);
      expired = true;
      identifier = 'SESSION-RENEWED';
      response = expiryAsGbkHtml
          ? ResponseBody.fromBytes(gbk.encode('<p>请重新登录</p>'), 200)
          : ResponseBody.fromString('nologin', 410);
    } else if (path.endsWith('/loginchk_xs.aspx')) {
      requests.add(options);
      response = ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['/index.aspx?id=$identifier'],
        },
      );
    } else if (path.endsWith('/StudentInformation.aspx')) {
      requests.add(options);
      response = htmlResponse(
        '<span id="ContentPlaceHolder1_LB_xh">$student</span>',
      );
    } else if (path.endsWith('/xl.asp')) {
      requests.add(options);
      response = ResponseBody.fromBytes(
        gbk.encode(
          options.method == 'GET'
              ? '当前学期：$_term<select name="xq">'
                    '<option value="$_termId">学期</option></select>'
              : '<table></table><table><tr><td>9月1日为开学</td></tr></table>',
        ),
        200,
      );
    } else {
      response = await super.fetch(options, requestStream, cancelFuture);
    }
    if (path.endsWith(heldPath ?? '\u0000') && options.method == heldMethod) {
      heldPath = null;
      arrived.complete();
      await release.future;
    }
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient.instance;
  late HttpClientAdapter previousAdapter;
  late _DelayedAdapter adapter;
  late AcademicService academic;
  late CourseService courses;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mockReminderChannel();
    await AcademicChangesService.instance.clear();
    previousAdapter = api.dio.httpClientAdapter;
    adapter = _DelayedAdapter();
    api.dio.httpClientAdapter = adapter;
    await api.login(adapter.student, 'fixture-only', '1234');
    adapter.requests.clear();
    academic = AcademicService();
    courses = CourseService();
  });

  tearDown(() async {
    if (!adapter.release.isCompleted) adapter.release.complete();
    await api.clearSession();
    api.dio.httpClientAdapter = previousAdapter;
  });

  final requests = [
    (
      name: '课表',
      path: '/xkjg_list.aspx',
      method: 'POST',
      run: () => courses.getCourses(_term, useCache: false),
    ),
    (
      name: '课表表单',
      path: '/xkjg_list.aspx',
      method: 'GET',
      run: () => courses.getCourses(_term, useCache: false),
    ),
    (
      name: '校历缓存',
      path: '/xl.asp',
      method: 'GET',
      run: () => academic.loadOrFetchCalendar(useCache: false),
    ),
    (
      name: '直接校历',
      path: '/xl.asp',
      method: 'GET',
      run: () => academic.getSchoolCalendar(),
    ),
    (
      name: '学期事件缓存',
      path: '/xl.asp',
      method: 'POST',
      run: () => academic.loadOrFetchTermEvents(_termId, useCache: false),
    ),
    (
      name: '直接学期事件',
      path: '/xl.asp',
      method: 'POST',
      run: () => academic.getTermEvents(_termId),
    ),
    (
      name: '成绩变化',
      path: '/score_sheet.aspx',
      method: 'GET',
      run: () => academic.getMarks(),
    ),
    (
      name: '考场缓存与变化',
      path: '/xkjg_list.aspx',
      method: 'POST',
      run: () => academic.getExamRooms(_term, useCache: false),
    ),
    (
      name: '考场表单',
      path: '/xkjg_list.aspx',
      method: 'GET',
      run: () => academic.getExamRooms(_term, useCache: false),
    ),
    (
      name: '首选学期考场表单',
      path: '/xkjg_list.aspx',
      method: 'GET',
      run: () => academic.getExamRoomsForPreferredTerm(_term, useCache: false),
    ),
  ];

  for (final request in requests) {
    for (final transition in [
      '退出',
      '换号但 identifier 相同',
      '同账号新 identifier',
      '同账号同 identifier 手动登录',
      '退出后原账号原 identifier 登录',
    ]) {
      test('${request.name}：$transition 后拒绝旧响应且不改缓存或记录', () async {
        adapter.heldPath = request.path;
        adapter.heldMethod = request.method;
        final result = request.run();
        // Attach the error expectation before releasing the delayed response.
        final rejected = expectLater(
          result,
          throwsA(isA<SessionExpiredException>()),
        );
        await adapter.arrived.future;
        final requestCount = adapter.requests.length;
        if (transition == '退出') {
          await api.clearSession();
        } else {
          if (transition == '退出后原账号原 identifier 登录') {
            await api.clearSession();
          }
          if (transition == '换号但 identifier 相同') {
            adapter.student = '20230002';
          } else {
            adapter.identifier = 'SESSION-B';
          }
          await api.login(adapter.student, 'fixture-only', '1234');
        }
        adapter.requests.clear();
        // Stand in for the current session's inputs; stale responses must
        // neither overwrite these values nor create a change-history baseline.
        final sp = await SharedPreferences.getInstance();
        final marker = jsonEncode({
          'account': api.studentId ?? '',
          'currentSession': true,
        });
        for (final key in _cacheKeys) {
          await sp.setString(key, marker);
        }
        adapter.release.complete();
        await rejected;
        expect(adapter.requests, isEmpty);
        for (final key in _cacheKeys) {
          expect(sp.getString(key), marker, reason: key);
        }
        expect(AcademicChangesService.instance.value, isEmpty);
        if (request.name.contains('表单')) {
          expect(courses.cachedTerms, isEmpty);
          expect(academic.cachedExamTerms, isEmpty);
          expect(requestCount, 1);
        }
      });
    }
  }

  test('正常同会话查询写缓存，缓存模式不增加网络请求或变化记录', () async {
    final fetchedCourses = await courses.getCourses(_term, useCache: false);
    final calendar = await academic.loadOrFetchCalendar(useCache: false);
    final events = await academic.loadOrFetchTermEvents(
      _termId,
      useCache: false,
    );
    final exams = await academic.getExamRooms(_term, useCache: false);
    adapter.score = '90';
    await academic.getMarks();
    expect(fetchedCourses.single.name, '高等数学');
    expect(calendar.currentTerm, _term);
    expect(calendar.terms.single.startDate, '2026-08-31');
    expect(events.events.single.name, '开学');
    expect(exams.single.courseName, '高等数学');
    expect(adapter.requests, hasLength(7));

    final sp = await SharedPreferences.getInstance();
    final history = sp.getString(AcademicChangesService.storageKey);
    expect(history, isNotNull);
    api.usingCachedSession.value = true;
    adapter.requests.clear();
    expect(
      (await courses.getCourses(_term, useCache: false)).single.toJson(),
      fetchedCourses.single.toJson(),
    );
    expect(
      (await academic.loadOrFetchCalendar(useCache: false)).toJson(),
      calendar.toJson(),
    );
    expect(
      (await academic.loadOrFetchTermEvents(_termId, useCache: false)).toJson(),
      events.toJson(),
    );
    expect(
      (await academic.getExamRooms(_term, useCache: false)).single.toJson(),
      exams.single.toJson(),
    );
    expect(adapter.requests, isEmpty);
    expect(sp.getString(AcademicChangesService.storageKey), history);
    expect(AcademicChangesService.instance.value, isEmpty);
  });

  test('persistCache false 保持不写课表缓存', () async {
    final result = await courses.getCourses(
      _term,
      useCache: false,
      persistCache: false,
    );
    expect(result.single.name, '高等数学');
    expect(
      (await SharedPreferences.getInstance()).getString(SpKeys.cacheCoursesMap),
      isNull,
    );
    expect(adapter.requests, hasLength(2));
  });

  test('退出后公开调休旧响应也不回写小组件输入或返回旧课表', () async {
    await courses.getCourses(_term, useCache: false);
    final holidayArrived = Completer<void>();
    final holidayResponse = Completer<void>();
    final holidayDio = Dio();
    holidayDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          holidayArrived.complete();
          await holidayResponse.future;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {'code': 10000, 'data': <dynamic>[]},
            ),
          );
        },
      ),
    );
    final result = CourseService(holidayClient: holidayDio)
        .getCourses(_term, west2AdjustmentsEnabled: true);
    final rejected = expectLater(
      result,
      throwsA(isA<SessionExpiredException>()),
    );
    await holidayArrived.future;
    await api.clearSession();
    holidayResponse.complete();
    await rejected;
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString(SpKeys.cacheCoursesMap), isNull);
    expect(sp.getString(SpKeys.cacheHolidayAdjustmentsMap), isNull);
    holidayDio.close();
  });

  for (final target in ['课表表单', '课表提交', '校历', 'GBK校历']) {
    test('$target 自动续会话后首次调用即可返回数据并写缓存', () async {
      await AuthStorage().saveCredentials(adapter.student, 'fixture-only');
      final session = api.captureSession();
      adapter.expiryPath = target.startsWith('课表')
          ? '/xkjg_list.aspx'
          : '/xl.asp';
      adapter.expiryMethod = target == '课表提交' ? 'POST' : 'GET';
      adapter.expiryAsGbkHtml = target == 'GBK校历';
      if (target.startsWith('课表')) {
        expect(
          (await courses.getCourses(_term, useCache: false)).single.name,
          '高等数学',
        );
      } else {
        expect(
          (await academic.loadOrFetchCalendar(useCache: false)).currentTerm,
          _term,
        );
      }
      expect(adapter.expired, isTrue);
      expect(api.userId, 'SESSION-RENEWED');
      expect(session.check, returnsNormally);
      expect(
        adapter.requests.where((r) => r.uri.path.endsWith('/logincheck.asp')),
        hasLength(1),
      );
      final retried = adapter.requests.where(
        (r) =>
            r.uri.path.endsWith(adapter.expiryPath!) &&
            r.method == adapter.expiryMethod,
      );
      expect(retried, hasLength(2));
      expect(retried.last.queryParameters['id'], 'SESSION-RENEWED');
      final sp = await SharedPreferences.getInstance();
      expect(
        sp.getString(
          target.startsWith('课表')
              ? SpKeys.cacheCoursesMap
              : SpKeys.cacheSchoolCalendar,
        ),
        isNotNull,
      );
    });
  }

  for (final termCache in [false, true]) {
    test('提交${termCache ? "学期缓存" : "整份校历"}等待 SP 时手动登录使 guard 拒绝落盘', () async {
      final sp = await SharedPreferences.getInstance();
      final key = termCache
          ? SpKeys.cacheCoursesMap
          : SpKeys.cacheSchoolCalendar;
      await sp.setString(key, '{"current":true}');
      final session = api.captureSession();
      final before = CacheHelper.changes.value;
      session.check();
      final saving = termCache
          ? CacheHelper.saveForKey(key, _term, {
              'courses': <dynamic>[],
            }, guard: session.check)
          : CacheHelper.saveMap(key, {
              'currentTerm': _term,
              'terms': <dynamic>[],
            }, guard: session.check);
      final rejected = expectLater(
        saving,
        throwsA(isA<SessionExpiredException>()),
      );
      // Same account AND identifier: only the explicit generation changed.
      await api.login(adapter.student, 'fixture-only', '1234');
      await rejected;
      expect(sp.getString(key), '{"current":true}');
      expect(CacheHelper.changes.value, before);
    });
  }

  test('同账号手动 relogin 使原代次失效，自动 refresh 保留当前代次', () async {
    await AuthStorage().saveCredentials(adapter.student, 'fixture-only');
    final before = api.captureSession();
    expect(await api.relogin(), isTrue);
    expect(before.check, throwsA(isA<SessionExpiredException>()));
    final renewed = api.captureSession();
    adapter.identifier = 'SESSION-RENEWED';
    expect(await api.refreshSession(), isTrue);
    expect(renewed.check, returnsNormally);
  });

  test('旧过期响应在换号后不为新账号触发自动重登', () async {
    await AuthStorage().saveCredentials(adapter.student, 'fixture-only');
    adapter.expiryPath = adapter.heldPath = '/xl.asp';
    adapter.expiryMethod = adapter.heldMethod = 'GET';
    final rejected = expectLater(
      academic.loadOrFetchCalendar(useCache: false),
      throwsA(isA<SessionExpiredException>()),
    );
    await adapter.arrived.future;
    adapter.student = '20230002';
    await api.login(adapter.student, 'fixture-only', '1234');
    adapter.requests.clear();
    adapter.release.complete();
    await rejected;
    expect(adapter.requests, isEmpty);
    expect(api.studentId, '20230002');
  });

  test('自动重登在途时手动登录，旧重登不得恢复或清空新会话', () async {
    await AuthStorage().saveCredentials(adapter.student, 'fixture-only');
    adapter.expiryPath = '/xl.asp';
    adapter.expiryMethod = 'GET';
    adapter.heldPath = '/verifycode.asp';
    adapter.heldMethod = 'GET';
    final rejected = expectLater(
      academic.loadOrFetchCalendar(useCache: false),
      throwsA(isA<SessionExpiredException>()),
    );
    await adapter.arrived.future;
    adapter.student = '20230002';
    adapter.identifier = 'SESSION-MANUAL';
    await api.login(adapter.student, 'fixture-only', '1234');
    adapter.requests.clear();
    adapter.release.complete();
    await rejected;
    expect(api.studentId, '20230002');
    expect(api.userId, 'SESSION-MANUAL');
    expect(adapter.requests, isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getString(
        SpKeys.cacheSchoolCalendar,
      ),
      isNull,
    );
  });
}
