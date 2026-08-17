import 'dart:convert';

class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() =>
      'SessionExpiredException: session expired, re-login required';
}

/// 教务系统的会话失效响应并不统一：部分接口返回 410/nologin，
/// 部分接口返回 302 到 error.asp?id=300，还有部分旧页面直接输出中文提示。
abstract final class SessionExpiryDetector {
  static bool isRedirect(int? statusCode, String? location) {
    if (statusCode == 410) return true;
    if (statusCode != 302 || location == null) return false;

    final normalized = location.toLowerCase();
    return normalized.contains('error.asp') &&
        RegExp(r'(?:[?&])id=300(?:&|$)').hasMatch(normalized);
  }

  static bool isPayload(Object? payload) {
    if (payload is Map) return payload['info'] == 'nologin';

    if (payload is List<int>) {
      return isHtml(utf8.decode(payload, allowMalformed: true));
    }
    return payload is String && isHtml(payload);
  }

  static bool isHtml(String html) {
    final normalized = html.toLowerCase();
    return normalized.contains('nologin') ||
        html.contains('重新登录') ||
        html.contains('处理URL失败');
  }
}
