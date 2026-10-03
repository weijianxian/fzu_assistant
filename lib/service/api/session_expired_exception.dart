import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

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
    if (html.trim().toLowerCase() == 'nologin') return true;
    try {
      final payload = jsonDecode(html);
      if (payload is Map && payload['info'] == 'nologin') return true;
    } on FormatException {
      // HTML 页面继续检查可见提示和弹窗，不能把脚本中的标记当成过期。
    }

    final doc = html_parser.parse(html);
    for (final script in doc.querySelectorAll('script')) {
      // 只认直接执行的提示；事件处理函数里定义的过期分支不算过期响应。
      final alert = RegExp(
        r'''^\s*(?:window\.)?alert\s*\(\s*['"]([^'"]*)['"]\s*\)''',
      ).firstMatch(script.text);
      if (alert != null && _isExpiryMessage(alert.group(1)!)) {
        return true;
      }
      script.remove();
    }
    // 导航中的“重新登录”链接并不意味着会话已经过期。
    for (final element in doc.querySelectorAll('a, style')) {
      element.remove();
    }
    return _isExpiryMessage(doc.body?.text ?? '');
  }

  static bool _isExpiryMessage(String text) =>
      text.trim().toLowerCase() == 'nologin' ||
      text.contains('重新登录') ||
      text.contains('处理URL失败');
}
