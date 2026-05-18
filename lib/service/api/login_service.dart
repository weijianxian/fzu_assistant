import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/captcha_solver.dart';

class LoginResult {
  final String id;
  final String cookies;
  LoginResult({required this.id, required this.cookies});
}

/// 登录服务，委托 ApiClient 处理 HTTP
class LoginService {
  static const _urls = {
    'verifyCode': 'https://jwcjwxt2.fzu.edu.cn:82/plus/verifycode.asp',
  };

  Dio get _dio => ApiClient.instance.dio;

  Future<Uint8List> getCaptcha() async {
    final resp = await _dio.get<List<int>>(
      _urls['verifyCode']!,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(resp.data!);
  }

  Future<(Uint8List, int?)> getCaptchaWithSolution() async {
    final image = await getCaptcha();
    return (image, CaptchaSolver.solve(image));
  }

  Future<LoginResult> login(
    String username,
    String password,
    String captcha,
  ) async {
    await ApiClient.instance.login(username, password, captcha);

    final cookies = await ApiClient.instance.cookieJar.loadForRequest(
      Uri.parse('https://jwcjwxt2.fzu.edu.cn'),
    );
    final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');

    return LoginResult(id: username, cookies: cookieStr);
  }
}
