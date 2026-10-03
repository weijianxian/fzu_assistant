import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 模拟教务处"会话已失效"的响应：410 + nologin 页面。
class _ExpiredSessionAdapter implements HttpClientAdapter {
  final List<String> requestedUrls = [];

  int get calls => requestedUrls.length;

  bool get requestedVerifyCode =>
      requestedUrls.any((url) => url.contains('verifycode.asp'));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUrls.add(options.uri.toString());
    return ResponseBody.fromString('nologin', 410);
  }

  @override
  void close({bool force = false}) {}
}

/// [_AuthInterceptor.skipExpiryKey] 的值（库内私有，这里按契约硬编码）。
const _skipExpiryKey = '_skipExpiryHandling';

/// 只在 302 的 `Location` 头里带参数、响应体为空的适配器。
/// 用于确认登录参数不依赖 body 里的 "Object moved" 链接。
class _RedirectOnlyAdapter implements HttpClientAdapter {
  _RedirectOnlyAdapter({
    this.studentIdOnPage = '20210001',
    this.failStudentInfo = false,
  });

  /// 学生信息页上 `#ContentPlaceHolder1_LB_xh` 显示的内容。
  final String studentIdOnPage;

  /// 模拟学生信息页请求抛错，验证登录不因此被阻断。
  final bool failStudentInfo;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();

    ResponseBody redirect(String location) => ResponseBody.fromString(
      '',
      302,
      headers: {
        'location': [location],
      },
    );

    if (url.contains('logincheck.asp')) {
      return redirect(
        'https://jwcjwxt2.fzu.edu.cn:81/loginchk_xs.aspx'
        '?token=t0ken&id=123&num=9',
      );
    }
    if (url.contains('SSOLogin')) {
      return ResponseBody.fromString(
        '{"code":200}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (url.contains('loginchk_xs.aspx')) {
      return redirect(
        'https://jwcjwxt2.fzu.edu.cn:81/index.aspx?id=IDENTIFIER&foo=1',
      );
    }
    if (url.contains('StudentInformation.aspx')) {
      if (failStudentInfo) {
        throw const SocketException('connection reset');
      }
      return ResponseBody.fromString(
        '<html><body><span id="ContentPlaceHolder1_LB_xh">'
        '$studentIdOnPage</span></body></html>',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        },
      );
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _EvaluationAdapter extends _RedirectOnlyAdapter {
  final requests = <RequestOptions>[];
  String submitResponse = '';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.uri.path.endsWith('/TeaList.aspx')) {
      return ResponseBody.fromString('''
        <html><body><a href="/login.aspx">重新登录</a>
        <script>function check(info) {
          if (info === 'nologin') { alert('请重新登录'); }
        }</script>
        <a href="TeaEvaluation.aspx?id=OLD&amp;kcmc=数学&amp;jsxm=张老师">评议</a>
        </body></html>
      ''', 200);
    }
    if (options.uri.path.endsWith('/TeaEvaluation.aspx')) {
      if (options.method == 'POST') {
        return ResponseBody.fromString(submitResponse, 200);
      }
      return ResponseBody.fromString('''
        <input id="__VIEWSTATE" value="state">
        <input id="__VIEWSTATEGENERATOR" value="generator">
        <input id="__EVENTVALIDATION" value="validation">
      ''', 200);
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

void _mockStoredCredentials() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
        if (call.method == 'read') return 'mocked';
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'expireCookiesForDebug clears cookies but keeps the client usable',
    () async {
      final api = ApiClient.instance;
      final uri = Uri.parse('https://jwcjwxt2.fzu.edu.cn:81/');
      await api.cookieJar.saveFromResponse(uri, [Cookie('session', 'value')]);

      expect(await api.cookieJar.loadForRequest(uri), isNotEmpty);

      await api.expireCookiesForDebug();

      expect(await api.cookieJar.loadForRequest(uri), isEmpty);
    },
  );

  group('会话失效重登', () {
    late _ExpiredSessionAdapter adapter;
    late HttpClientAdapter originalAdapter;

    setUp(() {
      _mockStoredCredentials();
      // clearSession() 会清理 SharedPreferences 里的业务缓存。
      SharedPreferences.setMockInitialValues({});
      adapter = _ExpiredSessionAdapter();
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
      ApiClient.instance.dio.httpClientAdapter = adapter;
    });

    tearDown(() async {
      await ApiClient.instance.clearSession();
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorageChannel, null);
    });

    test('登录取证请求不受会话过期逻辑拦截，原响应直接返回', () async {
      final response = await ApiClient.instance.dio.get<String>(
        'https://jwcjwxt2.fzu.edu.cn:82/plus/verifycode.asp',
        options: Options(
          responseType: ResponseType.plain,
          extra: const {_skipExpiryKey: true},
        ),
      );

      expect(response.statusCode, 410);
      expect(adapter.calls, 1, reason: '带跳过标记的请求不应触发重登');
    });

    test('重登过程中自身请求再次过期时不会自等待（修复前永久挂起）', () async {
      // 业务请求遇到会话失效 → 触发重登 → 重登内部的取验证码请求同样返回失效。
      // 修复前：该请求会回过头 await 自己所属的那次重登 → 死锁（超时而非报错）。
      await expectLater(
        ApiClient.instance.dio
            .get<String>(
              'https://jwcjwxt2.fzu.edu.cn:81/student/xyzk/jdpm/GPA_sheet.aspx',
              options: Options(responseType: ResponseType.plain),
            )
            .timeout(const Duration(seconds: 10)),
        throwsA(isA<DioException>()),
      );

      expect(
        adapter.requestedVerifyCode,
        isTrue,
        reason: '重登应确实跑到取验证码这一步，而不是因缺少凭据提前退出',
      );
    });

    test('重登失败后不残留 identifier（不能把学号当成 id 用）', () async {
      // 验证码识别失败 → 重登返回 false。修复前 _userId 已被写成学号，
      // 会让 AcademicService 的"未登录"守卫失效并发出 id=学号 的错误请求。
      expect(await ApiClient.instance.relogin(), isFalse);
      expect(ApiClient.instance.userId, isNull);
    });

    test('clearSession 清空 Cookie 与本地会话状态', () async {
      final api = ApiClient.instance;
      final uri = Uri.parse('https://jwcjwxt2.fzu.edu.cn:81/');
      await api.cookieJar.saveFromResponse(uri, [Cookie('session', 'value')]);
      expect(await api.cookieJar.loadForRequest(uri), isNotEmpty);

      await api.clearSession();

      expect(await api.cookieJar.loadForRequest(uri), isEmpty);
      expect(api.userId, isNull);
    });

    test('登录参数优先从 302 的 Location 头解析', () async {
      // 这个适配器的响应体是空的，body 兜底不可能命中，
      // 因此能取到 identifier 就说明走的是 Location 头。
      ApiClient.instance.dio.httpClientAdapter = _RedirectOnlyAdapter();

      await ApiClient.instance.login('20210001', 'secret', '12');

      expect(ApiClient.instance.userId, 'IDENTIFIER');
    });

    test('两类评议列表携带 id 和 bj，正常页面不触发重登', () async {
      final evaluationAdapter = _EvaluationAdapter();
      ApiClient.instance.dio.httpClientAdapter = evaluationAdapter;
      await ApiClient.instance.login('20210001', 'secret', '12');
      evaluationAdapter.requests.clear();

      for (final type in ['xqxk', 'score']) {
        final teachers = await AcademicService().getEvaluationTeachers(type);
        expect(teachers.single.courseName, '数学');
        expect(teachers.single.teacherName, '张老师');
        expect(evaluationAdapter.requests.last.uri.queryParameters, {
          'id': 'IDENTIFIER',
          'bj': type,
        });
      }
      expect(evaluationAdapter.requests, hasLength(2));
    });

    test('评议 GET/POST 使用当前 id 和表单令牌，透出服务器拒绝原因', () async {
      final evaluationAdapter = _EvaluationAdapter();
      ApiClient.instance.dio.httpClientAdapter = evaluationAdapter;
      await ApiClient.instance.login('20210001', 'secret', '12');
      evaluationAdapter.requests.clear();
      final service = AcademicService();
      const params = {'id': 'OLD', 'kcmc': '数学', 'jsxm': '张老师'};

      expect(await service.submitEvaluation(params, '90', '评语', '12'), isTrue);
      for (final request in evaluationAdapter.requests) {
        expect(request.uri.queryParameters['id'], 'IDENTIFIER');
        expect(request.uri.queryParameters['kcmc'], '数学');
      }
      expect(evaluationAdapter.requests.last.data['__VIEWSTATE'], 'state');
      expect(
        evaluationAdapter.requests.last.data['__EVENTVALIDATION'],
        'validation',
      );

      evaluationAdapter.submitResponse = "<script>alert('验证码校验错误');</script>";
      expect(await service.submitEvaluation(params, '90', '评语', '12'), isFalse);
      evaluationAdapter.submitResponse = "<script>alert('评语不能少于20字');</script>";
      await expectLater(
        service.submitEvaluation(params, '90', '评语', '12'),
        throwsA(predicate((error) => error.toString().contains('评语不能少于20字'))),
      );
    });

    test('页面上的学号与登录学号不一致时拒绝这次会话', () async {
      ApiClient.instance.dio.httpClientAdapter = _RedirectOnlyAdapter(
        studentIdOnPage: '20200000',
      );

      await expectLater(
        ApiClient.instance.login('20210001', 'secret', '12'),
        throwsA(isA<Exception>()),
      );

      expect(ApiClient.instance.userId, isNull);
    });

    test('页面取不到学号时不阻断登录', () async {
      ApiClient.instance.dio.httpClientAdapter = _RedirectOnlyAdapter(
        studentIdOnPage: '',
      );

      await ApiClient.instance.login('20210001', 'secret', '12');

      expect(ApiClient.instance.userId, 'IDENTIFIER');
    });

    test('学生信息页请求失败时不阻断登录', () async {
      ApiClient.instance.dio.httpClientAdapter = _RedirectOnlyAdapter(
        failStudentInfo: true,
      );

      await ApiClient.instance.login('20210001', 'secret', '12');

      expect(ApiClient.instance.userId, 'IDENTIFIER');
    });
  });
}
