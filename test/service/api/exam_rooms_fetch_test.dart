import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/lectures_fixture.dart';
import '../../fixtures/reminder_channel.dart';

class ExamAdapter extends LecturesFixtureAdapter {
  bool fail = false;
  String page = '''
    <table id="ContentPlaceHolder1_DataList_xxk">
      <tr><td>header</td></tr><tr><td>columns</td></tr>
      <tr style="background:white">
        <td>必修</td><td>高等数学</td><td></td><td></td><td><span>3</span></td>
        <td>必修</td><td>考试</td><td>李老师</td><td></td>
        <td>2026年11月6日14:00-16:00旗山 数计3-404</td><td></td><td></td>
      </tr>
    </table>
  ''';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!options.uri.path.endsWith('/xkjg_list.aspx')) {
      return super.fetch(options, requestStream, cancelFuture);
    }
    requests.add(options);
    if (fail) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'fixture failure',
      );
    }
    if (options.method == 'GET') {
      return htmlResponse('''
        <input id="__VIEWSTATE" name="__VIEWSTATE" value="fresh-view" />
        <input id="__EVENTVALIDATION" name="__EVENTVALIDATION" value="fresh-validation" />
        <select id="ContentPlaceHolder1_DDL_xnxq">
          <option value="202601">2026秋</option>
        </select>
      ''');
    }
    return htmlResponse(page);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient.instance;
  late HttpClientAdapter previousAdapter;
  late ExamAdapter adapter;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    mockReminderChannel();
    previousAdapter = api.dio.httpClientAdapter;
    adapter = ExamAdapter();
    api.dio.httpClientAdapter = adapter;
    await api.login('20230001', 'fixture-password', '1234');
    adapter.requests.clear();
  });
  tearDown(() async {
    await api.clearSession();
    api.dio.httpClientAdapter = previousAdapter;
  });

  test('考场仅请求选课页面，复用当前表单令牌、identifier 和 Cookie', () async {
    final service = AcademicService();
    final (term, exams) = await service.getExamRoomsForPreferredTerm(
      '202601',
      useCache: false,
    );
    expect(term, '202601');
    expect(exams.single.courseName, '高等数学');
    expect(exams.single.location, '旗山 数计3-404');
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.map((r) => r.method), ['GET', 'POST']);
    for (final request in adapter.requests) {
      expect(request.uri.path, endsWith('/wdxk/xkjg_list.aspx'));
      expect(request.queryParameters['id'], 'LECTURE-IDENTIFIER');
      expect(request.headers['cookie'], contains('lecture-fixture'));
    }
    final form = adapter.requests.last.data as Map;
    expect(form['__VIEWSTATE'], 'fresh-view');
    expect(form['__EVENTVALIDATION'], 'fresh-validation');
    expect(form['ctl00\$ContentPlaceHolder1\$DDL_xnxq'], '202601');

    adapter.fail = true;
    await expectLater(
      service.getExamRooms('202601', useCache: false),
      throwsA(isA<Exception>()),
    );
    api.usingCachedSession.value = true;
    expect(
      (await service.getExamRooms('202601')).single.location,
      exams.single.location,
    );
  });

  test('缺失有效课表报错，不把上次考场缓存清空', () async {
    final service = AcademicService();
    await service.getExamRooms('202601', useCache: false);
    adapter.page = '<html>unexpected response</html>';
    await expectLater(
      service.getExamRooms('202601', useCache: false),
      throwsStateError,
    );
    api.usingCachedSession.value = true;
    final exams = await service.getExamRooms('202601');
    expect(exams.single.courseName, '高等数学');
  });
}
