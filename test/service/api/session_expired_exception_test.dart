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
  });
}
