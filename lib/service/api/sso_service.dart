import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:html/parser.dart' as html;
import 'package:pointycastle/export.dart';

typedef SmsVerification = Future<String?> Function(
  String phone,
  String tip,
  Future<void> Function() sendSms,
);

/// Protocol adapted from west2-online/fzuhelper-app lib/sso-login.ts.
/// SSO cookies are isolated from the academic session and stored per account.
class SsoService {
  SsoService({Dio? dio}) : dio = dio ?? Dio() {
    this.dio.options
      ..followRedirects = false
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 30)
      ..validateStatus = (status) => status != null && status < 500;
    this.dio.interceptors.add(CookieManager(_cookies));
  }

  static final instance = SsoService();
  static const loginUrl = 'https://sso.fzu.edu.cn/login';
  static const studyAuthorizeUrl =
      'https://sso.fzu.edu.cn/oauth2.0/authorize?response_type=code&client_id=wlwxt&redirect_uri=http://aiot.fzu.edu.cn/api/admin/sso/getIbsToken';
  static const userAgent =
      'Mozilla/5.0 (iPad; CPU OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 appId/cn.edu.fzu.fdxypa appScheme/kysk-fdxy-app hengfeng/fdxyappzs appType/2 ruijie-facecamera';
  final Dio dio;
  final _cookies = CookieJar();
  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  Future<String> _key(String kind) async {
    final account = (await AuthStorage().loadCredentials())?.username;
    if (account == null) throw Exception('请先登录教务账号');
    return 'fzu_sso_${Uri.encodeComponent(account)}_$kind';
  }

  Future<String?> loadStudyToken() async =>
      _storage.read(key: await _key('study_token'));

  Future<void> saveStudyToken(String token) async =>
      _storage.write(key: await _key('study_token'), value: token);

  Future<void> clearStudyToken() async =>
      _storage.delete(key: await _key('study_token'));

  Future<String?> loadCampusToken() async =>
      _storage.read(key: await _key('campus_token'));

  Future<void> clearCampusToken() async =>
      _storage.delete(key: await _key('campus_token'));

  Future<void> logout() async {
    await clearCampusToken();
    await _storage.delete(key: await _key('study_token'));
    await _storage.delete(key: await _key('cookie'));
    await _cookies.deleteAll();
  }

  static String encrypt(String text, String base64Key) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      ECBBlockCipher(AESEngine()),
    );
    cipher.init(
      true,
      PaddedBlockCipherParameters<KeyParameter, Null>(
        KeyParameter(base64Decode(base64Key)),
        null,
      ),
    );
    return base64Encode(cipher.process(Uint8List.fromList(utf8.encode(text))));
  }

  static Map<String, String> csrfHeaders() {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final key = List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    final encoded = base64Encode(utf8.encode(key));
    final half = encoded.length ~/ 2;
    return {
      'Csrf-Key': key,
      'Csrf-Value': md5
          .convert(
            utf8.encode(
              '${encoded.substring(0, half)}$encoded${encoded.substring(half)}',
            ),
          )
          .toString(),
    };
  }

  Future<void> login(
    String username,
    String password, {
    required SmsVerification onSmsRequired,
    bool loadStudyToken = true,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      throw Exception('账号密码不能为空');
    }
    await _cookies.deleteAll();
    final page = await dio.get<String>(loginUrl);
    final document = html.parse(page.data);
    final key = document.getElementById('login-croypto')?.text.trim();
    final execution = document
        .getElementById('login-page-flowkey')
        ?.text
        .trim();
    if (key == null || key.isEmpty || execution == null || execution.isEmpty) {
      throw Exception('无法从统一认证页面提取密钥，请稍后重试');
    }
    final form = <String, String>{
      'username': username.trim(),
      'type': 'UsernamePassword',
      '_eventId': 'submit',
      'geolocation': '',
      'execution': execution,
      'captcha_code': '',
      'croypto': key,
      'password': encrypt(password, key),
      'captcha_payload': encrypt('{}', key),
    };
    Future<Response<String>> submit(Map<String, String> data) =>
        dio.post<String>(
          loginUrl,
          data: data,
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
    var response = await submit(form);
    final challenge = html.parse(response.data);
    if (challenge.getElementById('current-login-type')?.text.trim() ==
        'smsLogin') {
      final phone = challenge.getElementById('phone-number')?.text.trim();
      if (phone == null || phone.isEmpty) throw Exception('未找到手机验证号码');
      final tip =
          challenge.getElementById('second-auth-tip')?.text.trim() ?? '';
      final code = await onSmsRequired(phone, tip, () async {
        final result = await dio.post<Map<String, dynamic>>(
          'https://sso.fzu.edu.cn/api/protected/sms/publicNoToken/sendSmsCode',
          data: {'businessNo': '0008', 'phone': phone},
          options: Options(
            headers: csrfHeaders(),
            contentType: Headers.jsonContentType,
          ),
        );
        if (result.data?['code'].toString() != '200') {
          throw Exception(result.data?['msg'] ?? '验证码发送失败');
        }
      });
      if (code == null || code.trim().isEmpty) throw Exception('已取消手机验证');
      final verified = await dio.post<Map<String, dynamic>>(
        'https://sso.fzu.edu.cn/api/protected/sms/checkToken',
        data: {
          'phone': phone,
          'token': code.trim(),
          'delete': 'false',
          'trustDevice': 'false',
        },
        options: Options(
          headers: csrfHeaders(),
          contentType: Headers.jsonContentType,
        ),
      );
      if (verified.data?['code'].toString() != '200') {
        throw Exception(verified.data?['msg'] ?? '验证码验证失败');
      }
      response = await submit({
        'username': username.trim(),
        'password': code.trim(),
        'type': 'smsLogin',
        '_eventId': 'submit',
        'geolocation': '',
        'execution':
            challenge.getElementById('login-page-flowkey')?.text.trim() ??
            execution,
        'captcha_code': '',
        'trustDevice': 'false',
      });
    }
    final cookies = await _cookies.loadForRequest(Uri.parse(loginUrl));
    final ticket = cookies
        .where((cookie) => cookie.name == 'SOURCEID_TGC')
        .firstOrNull;
    if (ticket == null || ticket.value.isEmpty) {
      final message = html
          .parse(response.data)
          .querySelector('.error-message, #msg')
          ?.text
          .trim();
      throw Exception(
        message?.isNotEmpty == true ? message : '登录失败，请检查统一认证账号密码或验证码',
      );
    }
    await _storage.write(key: await _key('cookie'), value: ticket.value);
    await clearStudyToken();
    await clearCampusToken();
    if (loadStudyToken) await getStudyToken();
  }

  Future<String> getCampusToken() async {
    // Capture the account before the redirect chain so a late response cannot
    // write the old account's token into a newly selected account.
    final tokenKey = await _key('campus_token');
    final cookieKey = await _key('cookie');
    final cookie = await _storage.read(key: cookieKey);
    if (cookie == null || cookie.isEmpty) throw const SsoLoginRequired();
    await _cookies.deleteAll();
    await _cookies.saveFromResponse(Uri.parse(loginUrl), [
      Cookie('SOURCEID_TGC', cookie),
    ]);
    final target = Uri.https('xcx.fzu.edu.cn', '/berserker-base/redirect', {
      'appId': '16',
      'nodeId': '15',
      'type': 'app',
    });
    final service = Uri.https(
      'xcx.fzu.edu.cn',
      '/berserker-auth/cas/login/ruiJie',
      {'targetUrl': target.toString()},
    );
    var url = Uri.parse(loginUrl)
        .replace(queryParameters: {'service': service.toString()});
    for (var hop = 0; hop < 12; hop++) {
      if (url.scheme != 'https' ||
          !{'sso.fzu.edu.cn', 'xcx.fzu.edu.cn'}.contains(url.host)) {
        throw Exception('统一认证返回了不支持的跳转地址');
      }
      final token =
          url.queryParameters['synjones-auth'] ??
          Uri.tryParse(url.fragment)?.queryParameters['synjones-auth'];
      if (url.host == 'xcx.fzu.edu.cn' && token != null && token.isNotEmpty) {
        if (tokenKey != await _key('campus_token') ||
            cookie != await _storage.read(key: cookieKey)) {
          throw const SsoLoginRequired();
        }
        await _storage.write(key: tokenKey, value: token);
        return token;
      }
      final response = await dio.getUri<String>(
        url,
        options: Options(headers: {'User-Agent': userAgent}),
      );
      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        if (url.host == 'sso.fzu.edu.cn') throw const SsoLoginRequired();
        throw Exception('一卡通未返回登录 token');
      }
      url = url.resolve(location);
    }
    throw Exception('一卡通登录跳转次数过多');
  }

  Future<String> getStudyToken() async {
    final cookie = await _storage.read(key: await _key('cookie'));
    if (cookie == null || cookie.isEmpty) throw const SsoLoginRequired();
    await _cookies.deleteAll();
    await _cookies.saveFromResponse(Uri.parse(loginUrl), [
      Cookie('SOURCEID_TGC', cookie),
    ]);
    var url = Uri.parse(studyAuthorizeUrl);
    for (var hop = 0; hop < 12; hop++) {
      // Never send SSO cookies to another host; CookieManager scopes them.
      if (!{'sso.fzu.edu.cn', 'aiot.fzu.edu.cn'}.contains(url.host) ||
          !{'https', 'http'}.contains(url.scheme)) {
        throw Exception('统一认证返回了不支持的跳转地址');
      }
      final token =
          url.queryParameters['token'] ??
          Uri.tryParse(url.fragment)?.queryParameters['token'];
      if (url.host == 'aiot.fzu.edu.cn' && token != null && token.isNotEmpty) {
        await saveStudyToken(token);
        return token;
      }
      // The published OAuth callback uses HTTP; prefer TLS for the same endpoint.
      if (url.host == 'aiot.fzu.edu.cn' && url.scheme == 'http') {
        url = url.replace(scheme: 'https');
      }
      final response = await dio.getUri<String>(
        url,
        options: Options(headers: {'User-Agent': userAgent}),
      );
      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        if (url.host == 'sso.fzu.edu.cn') throw const SsoLoginRequired();
        throw Exception('学习中心未返回登录 token');
      }
      url = url.resolve(location);
    }
    throw Exception('学习中心登录跳转次数过多');
  }
}

class SsoLoginRequired implements Exception {
  const SsoLoginRequired();
  @override
  String toString() => '统一认证登录状态已过期，请重新登录';
}
