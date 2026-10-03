import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/captcha_solver.dart';
import 'package:fzu_assistant/service/api/session_expired_exception.dart';
import 'package:html/parser.dart' as html_parser;

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
    'studentInfo':
        'https://jwcjwxt2.fzu.edu.cn:81/jcxx/xsxx/StudentInformation.aspx',
  };

  // ─── 工具 ───

  String _md5_16(String s) =>
      md5.convert(utf8.encode(s)).toString().substring(8, 24);

  String _strip(String s) => s.replaceAll(RegExp(r'\s+'), '');

  /// 登录取证链路专用选项。
  ///
  /// 这些请求的职责本身就是重建会话，因此必须跳过
  /// "会话过期 → 重登 → 重试"：重登期间 [_reloginCompleter] 尚未完成，
  /// 若它们再触发 [refreshSession]，就会 await 自己所属的那次重登而永久挂起。
  static Options _loginFlowOptions({
    ResponseType responseType = ResponseType.json,
  }) => Options(
    responseType: responseType,
    extra: const {_AuthInterceptor.skipExpiryKey: true},
  );

  // ─── 登录 ───

  Future<(Uint8List, int?)> getCaptchaWithSolution() async {
    final response = await _dio.get<List<int>>(
      _urls['verifyCode']!,
      options: _loginFlowOptions(responseType: ResponseType.bytes),
    );
    final image = Uint8List.fromList(response.data!);
    return (image, CaptchaSolver.solve(image));
  }

  Future<void> login(String user, String pass, String captcha) async {
    // 登录成功前不持有 identifier：残留的旧值会被 _refreshIdentifier
    // 当成有效 id 发出去，导致"未登录"守卫失效。
    _userId = null;

    // Step 1: loginCheck
    final checkResp = await _dio.post<List<int>>(
      _urls['loginCheck']!,
      data: {'muser': user, 'passwd': _md5_16(pass), 'Verifycode': captcha},
      options: _loginFlowOptions(responseType: ResponseType.bytes),
    );

    if (checkResp.statusCode != 302) {
      throw Exception('登录失败');
    }

    final token = _redirectParam(checkResp, 'token');
    if (token == null) throw Exception('教务处未返回有效 Token');

    // Step 2: SSOLogin
    final ssoResp = await _dio.post(
      _urls['ssoLogin']!,
      data: {'token': token},
      options: _loginFlowOptions(),
    );
    final ssoJson = ssoResp.data is String
        ? jsonDecode(_strip(ssoResp.data as String))
        : ssoResp.data;
    if (ssoJson['code'] != 200) {
      throw Exception('SSOLogin 失败');
    }

    // Step 3: finishLogin
    final id = _redirectParam(checkResp, 'id');
    final num = _redirectParam(checkResp, 'num');
    if (id == null || num == null) throw Exception('登录参数缺失');

    final finishUrl =
        '${_urls['loginCheckXs']}?id=$id&num=$num'
        '&ssourl=https://jwcjwxt2.fzu.edu.cn'
        '&hosturl=https://jwcjwxt2.fzu.edu.cn:81&ssologin=';

    final finishResp = await _dio.get<List<int>>(
      finishUrl,
      options: _loginFlowOptions(responseType: ResponseType.bytes),
    );
    final userId = _redirectParam(finishResp, 'id');
    if (userId == null) throw Exception('用户 ID 获取失败');
    _userId = userId;

    await _verifySessionOwner(user);
  }

  /// 校验这次会话确实属于 [studentId]（防串号）。
  ///
  /// identifier 与 Cookie 绑定，两者不匹配时后续请求会读到别人的数据。
  /// jwch 的 CheckSession 同样拿 StudentInformation.aspx 上的学号做比对。
  /// 请求失败或页面结构变化导致取不到学号时不阻断登录，只做"能确认才拦"。
  Future<void> _verifySessionOwner(String studentId) async {
    final String? actual;
    try {
      final resp = await _dio.get<List<int>>(
        _urls['studentInfo']!,
        queryParameters: {'id': _userId},
        options: _loginFlowOptions(responseType: ResponseType.bytes),
      );
      final doc = html_parser.parse(
        utf8.decode(resp.data ?? const [], allowMalformed: true),
      );
      actual = doc.getElementById('ContentPlaceHolder1_LB_xh')?.text.trim();
    } catch (_) {
      // 校验本身不是登录的硬门槛：拿不到学号就跳过，不把登录搞挂。
      return;
    }

    if (actual == null || actual.isEmpty || actual == studentId) return;

    _userId = null;
    throw Exception('登录会话与学号不一致，请重新登录');
  }

  /// 取 302 跳转目标里的查询参数。
  ///
  /// 教务处禁用了跟随重定向后，跳转目标既出现在 `Location` 头，也出现在
  /// ASP.NET 的 "Object moved" 页面链接里。Location 才是权威来源，
  /// body 只作兜底（jwch 也是从重定向串里取 token/id/num 的）。
  String? _redirectParam(Response<List<int>> response, String name) {
    final pattern = RegExp('$name=([^&]+)');

    final location = response.headers.value('Location');
    if (location != null) {
      final fromHeader = pattern.firstMatch(location);
      if (fromHeader != null) return _decodeParam(fromHeader.group(1));
    }

    final body = _strip(
      utf8.decode(response.data ?? const [], allowMalformed: true),
    );
    return _decodeParam(pattern.firstMatch(body)?.group(1));
  }

  /// 对跳转参数做一次 URL 解码；教务处生成的 token/id/num 都是安全字符，
  /// 即便遇到不规范的百分号编码也原样返回，不因此中断登录。
  static String? _decodeParam(String? value) {
    if (value == null) return null;
    try {
      return Uri.decodeComponent(value);
    } on FormatException {
      return value;
    }
  }

  /// 读取凭据 + 自动识别验证码 + 登录
  Future<bool> relogin() async {
    final auth = AuthStorage();
    final creds = await auth.loadCredentials();
    if (creds == null) return false;

    // identifier 只有登录成功后才存在。登录过程中保持 null，
    // 避免登录失败后把学号当成教务处 identifier 继续发请求。
    _userId = null;
    try {
      final (_, solution) = await getCaptchaWithSolution();
      if (solution == null) return false;

      await login(creds.username, creds.password, solution.toString());
      return true;
    } catch (_) {
      _userId = null;
      return false;
    }
  }

  /// 退出登录：清除 identifier、Cookie 与账号相关的本地缓存。
  ///
  /// 课程/考场缓存只按学期分片、不含账号维度，不清会读到上一个账号的数据。
  Future<void> clearSession() async {
    _userId = null;
    await _cookieJar.deleteAll();
    await CacheHelper.removeAll(SpKeys.userScopedCacheKeys);
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

  /// 标记"正在重建会话"的请求（登录取证链路），使其跳过过期重登处理。
  static const skipExpiryKey = '_skipExpiryHandling';

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
    if (!_needsSessionRetry(response.requestOptions) || !_isNologin(response)) {
      handler.next(response);
      return;
    }
    if (response.requestOptions.extra[sessionRetriedKey] == true) {
      handler.reject(_expiredError(response.requestOptions));
      return;
    }
    _handleExpired(response.requestOptions, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is! SessionExpiredException ||
        !_needsSessionRetry(err.requestOptions)) {
      handler.next(err);
      return;
    }
    if (err.requestOptions.extra[sessionRetriedKey] == true) {
      handler.next(err);
      return;
    }
    _handleExpiredError(err.requestOptions, handler);
  }

  /// 登录链路的请求自带跳过标记：它们正在重建会话，
  /// 不能再回头 await 自己所属的那次重登。
  static bool _needsSessionRetry(RequestOptions options) =>
      options.extra[skipExpiryKey] != true;

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
