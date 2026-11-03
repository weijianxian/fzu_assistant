import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/reminder_channel.dart';

/// Every response carries different WebForms state. Reusing GET tokens in a
/// later POST is rejected, just as it is by the official server.
class _PlanAdapter implements HttpClientAdapter {
  String collegeName = '计算机与大数据学院';
  bool matchingCollege = true;
  bool matchingMajor = true;
  final requests = <RequestOptions>[];
  final postedForms = <Map<String, String>>[];

  String fields(int version) =>
      '''
    <input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" value="state-$version">
    <input type="hidden" name="__VIEWSTATEGENERATOR" id="__VIEWSTATEGENERATOR" value="generator-$version">
    <input type="hidden" name="__EVENTVALIDATION" id="__EVENTVALIDATION" value="validation-$version">
  ''';

  ResponseBody html(String body) => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: ['text/html; charset=utf-8'],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    ResponseBody redirect(String location) => ResponseBody.fromString(
      '',
      302,
      headers: {
        'location': [location],
        'set-cookie': ['ASP.NET_SessionId=fixture-session; Path=/; HttpOnly'],
      },
    );
    if (path.endsWith('logincheck.asp')) {
      return redirect('/loginchk_xs.aspx?token=fixture-token&id=initial&num=9');
    }
    if (path.endsWith('SSOLogin')) {
      return ResponseBody.fromString(
        '{"code":200}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (path.endsWith('loginchk_xs.aspx')) {
      return redirect('/index.aspx?id=CURRENT-IDENTIFIER');
    }
    requests.add(options);
    expect(options.queryParameters['id'], 'CURRENT-IDENTIFIER');
    expect(
      options.headers['cookie'],
      contains('ASP.NET_SessionId=fixture-session'),
    );
    if (path.endsWith('StudentInformation.aspx')) {
      return html('''
        <span id="ContentPlaceHolder1_LB_xh">20230001</span>
        <span id="ContentPlaceHolder1_LB_nj">2023</span>
        <span id="ContentPlaceHolder1_LB_xymc">$collegeName</span>
        <span id="ContentPlaceHolder1_LB_zymc">计算机科学与技术</span>
      ''');
    }
    if (path.endsWith('pyjh_list.aspx') && options.method == 'GET') {
      return html('''${fields(1)}
        <select name="ctl00\$xymcdpl" id="xymcdpl">
          <option value="unrelated-college">其他学院</option>
          <option value="CS">${matchingCollege ? '计算机与大数据学院' : '另一个学院'}</option>
        </select>
      ''');
    }
    if (path.endsWith('pyjh_list.aspx') && options.method == 'POST') {
      final bytes = await requestStream!.expand((part) => part).toList();
      final form = Uri.splitQueryString(utf8.decode(bytes));
      postedForms.add(form);
      final version = postedForms.length;
      expect(form['__VIEWSTATE'], 'state-$version');
      expect(form['__VIEWSTATEGENERATOR'], 'generator-$version');
      expect(form['__EVENTVALIDATION'], 'validation-$version');
      expect(form['ctl00\$njdpl'], '2023');
      expect(form['ctl00\$zylbdpl'], '本专业');
      expect(form['ctl00\$ContentPlaceHolder1\$BT_submit'], '确定');
      expect(form['__EVENTARGUMENT'], '');
      if (matchingCollege && version == 1) {
        expect(form['ctl00\$xymcdpl'], 'CS');
        expect(form['__EVENTTARGET'], 'ctl00\$njdpl');
        expect(form['ctl00\$dldpl'], '<-全部->');
        expect(form['ctl00\$zymcdpl'], '<-全部->');
        expect(form['ctl00\$ContentPlaceHolder1\$DDL_syxw'], '<-全部->');
        return html('''${fields(2)}
          <select name="ctl00\$zymcdpl" id="zymcdpl">
            <option value="other-major">计算机技术</option>
            <option value="CS01">${matchingMajor ? '计算机科学与技术' : '网络工程'}</option>
          </select>
        ''');
      }
      expect(form['__EVENTTARGET'], '');
      expect(form.containsKey('ctl00\$xymcdpl'), isFalse);
      expect(form['ctl00\$dldpl'], '【全部】');
      expect(form['ctl00\$zymcdpl'], '【全部】');
      expect(form['ctl00\$ContentPlaceHolder1\$DDL_syxw'], '【全部】');
      return html('''${fields(version + 1)}
        <table>
          <tr><td>（工学）计算机技术</td><td><a href="pyfa_wrong.aspx">查看</a></td></tr>
          <tr><td>（工学）计算机科学与技术</td>
            <td><a href="javascript:pop1('pyfa_bzy.aspx?nj=2023&amp;zyh=CS02&amp;id=OLD-ID')">查看</a></td></tr>
        </table>
      ''');
    }
    throw StateError(
      'Unexpected fixture request: ${options.method} ${options.uri}',
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient.instance;
  late HttpClientAdapter previousAdapter;
  late _PlanAdapter adapter;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    mockReminderChannel();
    previousAdapter = api.dio.httpClientAdapter;
    adapter = _PlanAdapter();
    api.dio.httpClientAdapter = adapter;
    await api.login('20230001', 'fixture-password', '1234');
    adapter.requests.clear();
  });
  tearDown(() async {
    await api.clearSession();
    api.dio.httpClientAdapter = previousAdapter;
  });

  test('GET/POST matches exact college and major and keeps the live user identifier', () async {
    final result = Uri.parse(await AcademicService().getCultivatePlan());
    expect(result.path, '/pyfa/pyjh/pyfa_bzy.aspx');
    expect(result.queryParameters, {
      'nj': '2023',
      'xyh': 'CS',
      'zyh': 'CS01',
      'zylb': '本专业',
      'id': 'CURRENT-IDENTIFIER',
    });
    expect(adapter.postedForms, hasLength(1));
    expect(adapter.requests.map((request) => request.method), [
      'GET',
      'GET',
      'POST',
    ]);
  });

  test(
    'renamed mathematics/computing college uses the reference alias match',
    () async {
      adapter.collegeName = '数学与计算机学院';
      final result = Uri.parse(await AcademicService().getCultivatePlan());
      expect(result.queryParameters['xyh'], 'CS');
      expect(result.queryParameters['zyh'], 'CS01');
    },
  );

  test('fallback after an unmatched major uses new POST tokens and replaces old link identifiers', () async {
    adapter.matchingMajor = false;
    final result = Uri.parse(await AcademicService().getCultivatePlan());
    expect(adapter.postedForms, hasLength(2));
    expect(adapter.postedForms.last['__VIEWSTATE'], 'state-2');
    expect(result.queryParameters['zyh'], 'CS02');
    expect(result.queryParameters['id'], 'CURRENT-IDENTIFIER');
  });

  test('missing college submits grade-only fallback directly with initial GET tokens', () async {
    adapter.matchingCollege = false;
    final result = Uri.parse(await AcademicService().getCultivatePlan());
    expect(adapter.postedForms, hasLength(1));
    expect(adapter.postedForms.single['__VIEWSTATE'], 'state-1');
    expect(result.queryParameters['zyh'], 'CS02');
    expect(result.queryParameters['id'], 'CURRENT-IDENTIFIER');
  });
}
