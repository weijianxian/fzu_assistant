import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/session_expired_exception.dart';

void main() {
  group('SessionExpiryDetector.isRedirect', () {
    test('detects the session-expired status and redirect', () {
      expect(SessionExpiryDetector.isRedirect(410, null), isTrue);
      expect(
        SessionExpiryDetector.isRedirect(302, '/error.asp?id=300'),
        isTrue,
      );
      expect(
        SessionExpiryDetector.isRedirect(
          302,
          'https://jwcjwxt2.fzu.edu.cn:82/error.asp?foo=1&id=300',
        ),
        isTrue,
      );
    });

    test('does not treat evaluation redirects as session expiry', () {
      expect(
        SessionExpiryDetector.isRedirect(
          302,
          '/student/jscp/TeaEvaluation.aspx?id=300',
        ),
        isFalse,
      );
      expect(SessionExpiryDetector.isRedirect(200, null), isFalse);
    });
  });

  group('SessionExpiryDetector.isPayload', () {
    test('detects all known expiry payload formats', () {
      expect(SessionExpiryDetector.isPayload({'info': 'nologin'}), isTrue);
      expect(SessionExpiryDetector.isPayload('{"info":"nologin"}'), isTrue);
      expect(
        SessionExpiryDetector.isPayload(utf8.encode('<p>请重新登录</p>')),
        isTrue,
      );
      expect(SessionExpiryDetector.isPayload('<p>处理URL失败</p>'), isTrue);
    });

    test('ignores normal responses', () {
      expect(SessionExpiryDetector.isPayload({'info': 'ok'}), isFalse);
      expect(SessionExpiryDetector.isPayload('<html>GPA</html>'), isFalse);
      expect(SessionExpiryDetector.isPayload(<int>[1, 2, 3]), isFalse);
    });

    test('评议页面的重登链接和未登录处理脚本不代表会话失效', () {
      expect(
        SessionExpiryDetector.isHtml('''
          <html><body><a href="/login.aspx">重新登录</a>
          <script>function check(info) {
            if (info === 'nologin') { alert('请重新登录'); }
          }</script><a href="TeaEvaluation.aspx">评议</a></body></html>
        '''),
        isFalse,
      );
      expect(
        SessionExpiryDetector.isHtml('''
          <html><body><a href="/login.aspx">重新登录</a>
          <script>const expired = 'nologin';</script>
          <a href="TeaEvaluation.aspx">评议</a></body></html>
        '''),
        isFalse,
      );
    });

    test('仍识别会话失效弹窗', () {
      expect(
        SessionExpiryDetector.isHtml("<script>alert('请重新登录');</script>"),
        isTrue,
      );
    });
  });
}
