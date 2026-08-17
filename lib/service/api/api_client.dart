import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/captcha_solver.dart';
import 'package:fzu_assistant/service/api/session_expired_exception.dart';

class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': 'https://jwch.fzu.edu.cn',
          'Origin': 'https://jwch.fzu.edu.cn',
          'X-Requested-With': 'XMLHttpRequest',
        },
        followRedirects: false,
        validateStatus: (_) => true,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    _cookieJar = CookieJar();
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (_, _, _) => true;
      return client;
    };
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  static final instance = ApiClient._();

  late final Dio _dio;
  late final CookieJar _cookieJar;
  Completer<bool>? _reloginCompleter;
  String? _userId;

  Dio get dio => _dio;
  CookieJar get cookieJar => _cookieJar;
  String? get userId => _userId;

  /// 仅供开发者工具模拟 Cookie 过期。
  ///
  /// 保留当前 identifier 和安全存储中的凭据，使下一个教务请求
  /// 收到未登录响应，从而完整验证自动重登与请求重试链路。
  Future<void> expireCookiesForDebug() => _cookieJar.deleteAll();

  static const _urls = {
    'loginCheck': 'https://jwcjwxt2.fzu.edu.cn:82/logincheck.asp',
    'verifyCode': 'https://jwcjwxt2.fzu.edu.cn:82/plus/verifycode.asp',
    'ssoLogin': 'https://jwcjwxt2.fzu.edu.cn/Sfrz/SSOLogin',
    'loginCheckXs': 'https://jwcjwxt2.fzu.edu.cn:81/loginchk_xs.aspx',
  };

  // ─── 工具 ───

  String _md5_16(String s) =>
      md5.convert(utf8.encode(s)).toString().substring(8, 24);

  String _strip(String s) => s.replaceAll(RegExp(r'\s+'), '');

  // ─── 登录 ───

  Future<(Uint8List, int?)> getCaptchaWithSolution() async {
    final response = await _dio.get<List<int>>(
      _urls['verifyCode']!,
      options: Options(responseType: ResponseType.bytes),
    );
    final image = Uint8List.fromList(response.data!);
    return (image, CaptchaSolver.solve(image));
  }

  Future<void> login(String user, String pass, String captcha) async {
    // Step 1: loginCheck
    final checkResp = await _dio.post<List<int>>(
      _urls['loginCheck']!,
      data: {'muser': user, 'passwd': _md5_16(pass), 'Verifycode': captcha},
      options: Options(responseType: ResponseType.bytes),
    );
    final checkBody = _strip(
      utf8.decode(checkResp.data!, allowMalformed: true),
    );

    if (checkResp.statusCode != 302) {
      throw Exception('登录失败');
    }

    final token = RegExp(r'token=([^&]+)').firstMatch(checkBody)?.group(1);
    if (token == null) throw Exception('教务处未返回有效 Token');

    // Step 2: SSOLogin
    final ssoResp = await _dio.post(_urls['ssoLogin']!, data: {'token': token});
    final ssoJson = ssoResp.data is String
        ? jsonDecode(_strip(ssoResp.data as String))
        : ssoResp.data;
    if (ssoJson['code'] != 200) {
      throw Exception('SSOLogin 失败');
    }

    // Step 3: finishLogin
    final id = RegExp(r'id=([^&]+)').firstMatch(checkBody)?.group(1);
    final num = RegExp(r'num=([^&]+)').firstMatch(checkBody)?.group(1);
    if (id == null || num == null) throw Exception('登录参数缺失');

    final finishUrl =
        '${_urls['loginCheckXs']}?id=$id&num=$num'
        '&ssourl=https://jwcjwxt2.fzu.edu.cn'
        '&hosturl=https://jwcjwxt2.fzu.edu.cn:81&ssologin=';

    final finishResp = await _dio.get<List<int>>(
      finishUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final finishBody = utf8.decode(finishResp.data!, allowMalformed: true);
    final userId = RegExp(r'id=([^&]+)').firstMatch(finishBody)?.group(1);
    if (userId == null) throw Exception('用户 ID 获取失败');
    _userId = userId;
  }

  /// 读取凭据 + 自动识别验证码 + 登录
  Future<bool> relogin() async {
    final auth = AuthStorage();
    final creds = await auth.loadCredentials();
    if (creds == null) return false;

    try {
      _userId = creds.username;

      final (_, solution) = await getCaptchaWithSolution();
      if (solution == null) return false;

      await login(creds.username, creds.password, solution.toString());
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── 供拦截器调用 ───

  /// 同一时刻只执行一次重登，并让并发请求共用结果。
  Future<bool> refreshSession() async {
    final pending = _reloginCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<bool>();
    _reloginCompleter = completer;
    try {
      final ok = await relogin();
      completer.complete(ok);
      return ok;
    } catch (_) {
      completer.complete(false);
      return false;
    } finally {
      if (identical(_reloginCompleter, completer)) {
        _reloginCompleter = null;
      }
    }
  }

  Future<Response<T>> retry<T>(RequestOptions options) {
    // Identifier 会在重登后变更，不能原样重放旧 id。
    _refreshIdentifier(options);
    options.extra = {
      ...options.extra,
      _AuthInterceptor.sessionRetriedKey: true,
    };
    return _dio.fetch(options);
  }

  void _refreshIdentifier(RequestOptions options) {
    if (options.queryParameters.containsKey('id') && _userId != null) {
      options.queryParameters = {...options.queryParameters, 'id': _userId};
    }
  }
}

/// 检测 session 过期 → 自动重登 → 最多重试一次请求。
class _AuthInterceptor extends Interceptor {
  static const sessionRetriedKey = '_sessionRetried';

  final ApiClient _api;
  _AuthInterceptor(this._api);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 业务层可能在重登前已经构造了参数，发送前统一刷新 id。
    _api._refreshIdentifier(options);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_isNologin(response)) {
      if (response.requestOptions.extra[sessionRetriedKey] == true) {
        handler.reject(_expiredError(response.requestOptions));
        return;
      }
      _handleExpired(response.requestOptions, handler);
      return;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is SessionExpiredException) {
      if (err.requestOptions.extra[sessionRetriedKey] == true) {
        handler.next(err);
        return;
      }
      _handleExpiredError(err.requestOptions, handler);
      return;
    }
    handler.next(err);
  }

  bool _isNologin(Response response) {
    try {
      if (SessionExpiryDetector.isRedirect(
        response.statusCode,
        response.headers.value('Location'),
      )) {
        return true;
      }
      return SessionExpiryDetector.isPayload(response.data);
    } catch (_) {}
    return false;
  }

  Future<void> _handleExpired(
    RequestOptions options,
    ResponseInterceptorHandler handler,
  ) async {
    try {
      final ok = await _api.refreshSession();
      if (ok) {
        handler.resolve(await _api.retry(options));
      } else {
        handler.reject(_expiredError(options));
      }
    } catch (_) {
      handler.reject(_expiredError(options));
    }
  }

  DioException _expiredError(RequestOptions options) => DioException(
    requestOptions: options,
    type: DioExceptionType.unknown,
    error: 'Session expired and re-login failed',
  );

  Future<void> _handleExpiredError(
    RequestOptions options,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final ok = await _api.refreshSession();
      if (ok) {
        handler.resolve(await _api.retry(options));
      } else {
        handler.reject(_expiredError(options));
      }
    } catch (_) {
      handler.reject(_expiredError(options));
    }
  }
}
