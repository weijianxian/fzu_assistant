import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
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

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

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

    tearDown(() {
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
  });
}
