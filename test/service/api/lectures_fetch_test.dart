import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/session_expired_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/lectures_fixture.dart';
import '../../fixtures/reminder_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient.instance;
  late HttpClientAdapter previousAdapter;
  late LecturesFixtureAdapter adapter;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    mockReminderChannel();
    previousAdapter = api.dio.httpClientAdapter;
    adapter = LecturesFixtureAdapter();
    api.dio.httpClientAdapter = adapter;
    await api.login('20230001', 'fixture-password', '1234');
    adapter.requests.clear();
  });

  tearDown(() async {
    await api.clearSession();
    api.dio.httpClientAdapter = previousAdapter;
  });

  test(
    'GET uses the official URL, live identifier, cookie and shared parser',
    () async {
      final lectures = await AcademicService().getLectures();
      expect(lectures, hasLength(1));
      expect(lectures.single.title, '人工智能与校园生活');
      expect(lectures.single.startTime, DateTime.utc(2026, 11, 5, 11, 30));
      expect(adapter.lectureRequests, hasLength(1));
      final request = adapter.lectureRequests.single;
      expect(request.method, 'GET');
      expect(
        request.uri,
        Uri.parse(AcademicService.lecturesUrl)
            .replace(queryParameters: {'id': 'LECTURE-IDENTIFIER'}),
      );
      expect(request.queryParameters, {'id': 'LECTURE-IDENTIFIER'});
      expect(
        request.headers['cookie'],
        contains('ASP.NET_SessionId=lecture-fixture'),
      );
      expect(request.responseType, ResponseType.bytes);
    },
  );

  test('GBK fallback retains the shared authenticated request path', () async {
    adapter.encodeGbk = true;
    final lectures = await AcademicService().getLectures();
    expect(lectures.single.category, '科技');
    expect(lectures.single.title, '人工智能与校园生活');
    expect(lectures.single.speaker, '李老师');
    expect(lectures.single.location, '旗山校区图书馆报告厅');
    expect(lectures.single.attendanceStatus, '已听取');
    expect(adapter.lectureRequests, hasLength(2));
    for (final request in adapter.lectureRequests) {
      expect(request.queryParameters['id'], 'LECTURE-IDENTIFIER');
      expect(
        request.headers['cookie'],
        contains('ASP.NET_SessionId=lecture-fixture'),
      );
    }
  });

  test('logged-out calls fail before issuing a lecture request', () async {
    await api.clearSession();
    await expectLater(
      AcademicService().getLectures(),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('未登录'),
        ),
      ),
    );
    expect(adapter.lectureRequests, isEmpty);
  });

  test(
    'cache-only sessions do not send a stale identifier or empty request',
    () async {
      api.usingCachedSession.value = true;
      await expectLater(
        AcademicService().getLectures(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('缓存模式'),
          ),
        ),
      );
      expect(adapter.lectureRequests, isEmpty);
    },
  );

  test('an authenticated empty table is a successful empty result', () async {
    adapter.lecturesHtml =
        '<table id="ContentPlaceHolder1_DataList_xxk">'
        '<tr><td colspan="7">暂无报名记录</td></tr></table>';
    expect(await AcademicService().getLectures(), isEmpty);
  });

  test('missing tables and transport failures remain failed queries', () async {
    adapter.lecturesHtml = '<html><body>暂时无法提供服务</body></html>';
    await expectLater(
      AcademicService().getLectures(),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('未找到已报名讲座表格'),
        ),
      ),
    );
    adapter.failLectureRequests = true;
    await expectLater(
      AcademicService().getLectures(),
      throwsA(isA<DioException>()),
    );
  });

  test(
    'a login form with HTTP 200 cannot be treated as no registrations',
    () async {
      adapter.lecturesHtml =
          '<form><input type="password" name="password"></form>';
      await expectLater(
        AcademicService().getLectures(),
        throwsA(isA<SessionExpiredException>()),
      );
    },
  );

  test(
    'shared session-expiry handling rejects nologin instead of parsing it',
    () async {
      adapter.lecturesHtml = 'nologin';
      await expectLater(
        AcademicService().getLectures(),
        throwsA(isA<DioException>()),
      );
      expect(adapter.lectureRequests, hasLength(1));
    },
  );

  test('a GBK session-expiry page also remains an error', () async {
    adapter.encodeGbk = true;
    adapter.lecturesHtml = '<p>请重新登录后再查询</p>';
    await expectLater(
      AcademicService().getLectures(),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(adapter.lectureRequests, hasLength(2));
  });
}
