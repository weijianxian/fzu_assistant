import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';
import 'package:fzu_assistant/service/auth_storage.dart';

class _SsoAdapter implements HttpClientAdapter {
  bool sms = false;
  bool reject = false;
  bool expire = false;
  bool foreignRedirect = false;
  final requests = <RequestOptions>[];
  final bodies = <RequestOptions, String>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      bodies[options] = utf8.decode(
        await requestStream.expand((part) => part).toList(),
      );
    }
    final path = options.uri.path;
    ResponseBody response(
      String body, {
      int status = 200,
      String? location,
      String? cookie,
      bool json = false,
    }) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [
          json ? Headers.jsonContentType : 'text/html; charset=utf-8',
        ],
        if (location != null) 'location': [location],
        if (cookie != null) 'set-cookie': [cookie],
      },
    );
    if (path == '/login' && options.method == 'GET') {
      return response(
        '<p id="login-croypto">MDEyMzQ1Njc4OWFiY2RlZg==</p><p id="login-page-flowkey">flow1</p>',
        cookie: 'SESSION=session1; Path=/; Secure; HttpOnly',
      );
    }
    if (path == '/login' && options.method == 'POST') {
      final body = Uri.splitQueryString(bodies[options]!);
      if (reject) return response('<div id="msg">账号或密码错误</div>');
      if (sms && body['type'] != 'smsLogin') {
        return response(
          '<p id="current-login-type">smsLogin</p><p id="phone-number">138****0000</p><p id="second-auth-tip">手机验证</p><p id="login-page-flowkey">flow2</p>',
        );
      }
      return response(
        '',
        status: 302,
        location: 'https://sso.fzu.edu.cn/',
        cookie: 'SOURCEID_TGC=fake-ticket; Path=/; Secure; HttpOnly',
      );
    }
    if (path.endsWith('/sendSmsCode') || path.endsWith('/checkToken')) {
      return response('{"code":200}', json: true);
    }
    if (path == '/oauth2.0/authorize') {
      if (expire) return response('<form>Login required</form>');
      return response(
        '',
        status: 302,
        location: foreignRedirect
            ? 'https://example.com/steal'
            : '/oauth2.0/continue',
        cookie: 'SESSION=oauth-session; Path=/; Secure',
      );
    }
    if (path == '/oauth2.0/continue') {
      return response(
        '',
        status: 302,
        location:
            'http://aiot.fzu.edu.cn/api/admin/sso/getIbsToken?code=fake-code',
      );
    }
    if (path == '/api/admin/sso/getIbsToken') {
      return response(
        '',
        status: 302,
        location: '/ibs/#/?token=fake-study-token&userId=123',
      );
    }
    return response('', status: 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _SsoAdapter adapter;
  late SsoService service;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().saveCredentials('academic-a', 'academic-password');
    adapter = _SsoAdapter();
    service = SsoService(dio: Dio()..httpClientAdapter = adapter);
  });
  tearDown(() => service.dio.close(force: true));

  Future<void> login() => service.login(
    'sso-user',
    'password',
    onSmsRequired: (_, _, _) async => null,
  );

  test('AES ECB PKCS7 matches independently computed .NET ciphertext', () {
    expect(
      SsoService.encrypt('password', 'MDEyMzQ1Njc4OWFiY2RlZg=='),
      'R4lDIBO/32oRLZSjtsPrGQ==',
    );
  });
  test('CSRF header follows the reference concatenation and MD5 algorithm', () {
    final headers = SsoService.csrfHeaders();
    final key = headers['Csrf-Key']!;
    expect(key, matches(RegExp(r'^[A-Za-z0-9]{32}$')));
    final base64 = base64Encode(utf8.encode(key));
    final half = base64.length ~/ 2;
    expect(
      headers['Csrf-Value'],
      md5
          .convert(
            utf8.encode(
              '${base64.substring(0, half)}$base64${base64.substring(half)}',
            ),
          )
          .toString(),
    );
  });
  test('login encrypts password, follows relative redirects and parses fragment token', () async {
    await login();
    expect(await service.loadStudyToken(), 'fake-study-token');
    final post = adapter.requests.firstWhere((r) => r.method == 'POST');
    final data = Uri.splitQueryString(adapter.bodies[post]!);
    expect(data['password'], 'R4lDIBO/32oRLZSjtsPrGQ==');
    expect(data['execution'], 'flow1');
    expect(post.headers['cookie'], contains('SESSION=session1'));
    final callback = adapter.requests.firstWhere(
      (r) => r.uri.host == 'aiot.fzu.edu.cn',
    );
    expect(callback.headers['cookie'] ?? '', isNot(contains('SOURCEID_TGC')));
    expect(
      adapter.requests.any((r) => r.uri.fragment.contains('token')),
      isFalse,
    );
    expect(
      (await AuthStorage().loadCredentials())?.password,
      'academic-password',
    );
  });
  test(
    'SMS sends and verifies code with CSRF, then submits updated execution',
    () async {
      adapter.sms = true;
      await service.login(
        'sso-user',
        'password',
        onSmsRequired: (phone, tip, send) async {
          expect(phone, '138****0000');
          await send();
          return '123456';
        },
      );
      expect(await service.loadStudyToken(), 'fake-study-token');
      final verification = adapter.requests.firstWhere(
        (r) => r.uri.path.endsWith('/checkToken'),
      );
      expect(verification.headers['Csrf-Key'], isNotEmpty);
      final lastPost = adapter.requests.lastWhere(
        (r) => r.uri.path == '/login' && r.method == 'POST',
      );
      final data = Uri.splitQueryString(adapter.bodies[lastPost]!);
      expect(data['execution'], 'flow2');
      expect(data['type'], 'smsLogin');
      expect(data['password'], '123456');
    },
  );
  test('cancelled SMS verification does not obtain a study token', () async {
    adapter.sms = true;
    await expectLater(login(), throwsException);
    expect(await service.loadStudyToken(), isNull);
  });
  test('wrong password preserves academic credentials', () async {
    adapter.reject = true;
    await expectLater(login(), throwsException);
    expect(await service.loadStudyToken(), isNull);
    expect((await AuthStorage().loadCredentials())?.username, 'academic-a');
  });
  test(
    'stored SSO cookie renews study token and reports expired login',
    () async {
      await login();
      await service.clearStudyToken();
      expect(await service.getStudyToken(), 'fake-study-token');
      adapter.expire = true;
      await expectLater(
        service.getStudyToken(),
        throwsA(isA<SsoLoginRequired>()),
      );
    },
  );
  test('OAuth rejects foreign-host redirects', () async {
    adapter.foreignRedirect = true;
    await expectLater(login(), throwsException);
    expect(adapter.requests.any((r) => r.uri.host == 'example.com'), isFalse);
  });
  test('study token and SSO cookie are isolated by academic account and cleared on logout', () async {
    await login();
    await AuthStorage().saveCredentials('academic-b', 'other-password');
    expect(await service.loadStudyToken(), isNull);
    await expectLater(
      service.getStudyToken(),
      throwsA(isA<SsoLoginRequired>()),
    );
    await AuthStorage().saveCredentials('academic-a', 'academic-password');
    expect(await service.loadStudyToken(), 'fake-study-token');
    await service.logout();
    expect(await service.loadStudyToken(), isNull);
    await expectLater(
      service.getStudyToken(),
      throwsA(isA<SsoLoginRequired>()),
    );
  });
}
