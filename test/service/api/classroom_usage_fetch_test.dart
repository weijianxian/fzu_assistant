import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/classroom_usage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/lectures_fixture.dart';
import '../../fixtures/reminder_channel.dart';
import 'classroom_usage_service_test.dart' show usageFixture;

class _Adapter extends LecturesFixtureAdapter {
  int version = 0;
  final usageRequests = <RequestOptions>[];
  Completer<void>? hold;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!options.uri.path.endsWith('/kbcx_zb.aspx')) {
      return super.fetch(options, requestStream, cancelFuture);
    }
    usageRequests.add(options);
    if (options.method == 'POST') {
      final data = options.data as Map;
      expect(data['__VIEWSTATE'], 'view-$version');
      expect(data['__EVENTVALIDATION'], 'valid-$version');
    }
    version++;
    if (hold != null) await hold!.future;
    return htmlResponse('''
      <input type="hidden" name="__VIEWSTATE" value="view-$version">
      <input type="hidden" name="__EVENTVALIDATION" value="valid-$version">
      <select id="xnxqdpl"><option value="202601" selected>2026秋</option></select>
      <select id="xqdpl"><option value="01">旗山校区</option></select>
      <select id="jxldpl"><option value="east">公共教学楼东1</option></select>
      ${usageFixture()}
    ''');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient.instance;
  late HttpClientAdapter previous;
  late _Adapter adapter;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    mockReminderChannel();
    previous = api.dio.httpClientAdapter;
    adapter = _Adapter();
    api.dio.httpClientAdapter = adapter;
    await api.login('20230001', 'classroom-test-pass', '1234');
  });
  tearDown(() async {
    await api.clearSession();
    api.dio.httpClientAdapter = previous;
  });
  test('复用教务会话、校区真实值及每次响应的新表单令牌', () async {
    final rooms = await ClassroomUsageService().usage(
      '2026-11-09',
      '01',
      'east',
    );
    expect(rooms.single.occupied(1), isTrue);
    expect(adapter.usageRequests.length, 3);
    for (final request in adapter.usageRequests) {
      expect(request.queryParameters['id'], 'LECTURE-IDENTIFIER');
    }
    final data = adapter.usageRequests.last.data as Map;
    expect(data['ctl00\$xqdpl'], '01');
    expect(data['ctl00\$jxldpl'], 'east');
    expect(data['ctl00\$TB_rq'], '2026-11-09');
    expect(data['ctl00\$xnxqdpl'], '202601');
    expect(data['ctl00\$jsdpl'], '');
  });
  test('退出后的在途响应不能继续提交表单或显示旧账号结果', () async {
    adapter.hold = Completer<void>();
    final pending = ClassroomUsageService().usage('2026-11-09', '01', 'east');
    final checked = expectLater(pending, throwsA(isA<Exception>()));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await api.clearSession();
    adapter.hold!.complete();
    await checked;
    expect(adapter.usageRequests.where((r) => r.method == 'POST'), isEmpty);
  });
}
