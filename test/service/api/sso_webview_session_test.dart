import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/webview_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'fzu_username': 'student-a',
      'fzu_password': 'academic-password',
      'fzu_sso_student-a_cookie': 'sso-ticket-a',
      'fzu_sso_student-b_cookie': 'sso-ticket-b',
    });
  });

  test('WebView reads only the current academic account SSO ticket', () async {
    final service = SsoService();
    addTearDown(() => service.dio.close(force: true));
    expect(await service.loadWebViewCookie(), 'sso-ticket-a');
    await AuthStorage().saveCredentials('student-b', 'password-b');
    expect(await service.loadWebViewCookie(), 'sso-ticket-b');
    await AuthStorage().saveCredentials('student-c', 'password-c');
    await expectLater(
      service.loadWebViewCookie(),
      throwsA(isA<SsoLoginRequired>()),
    );
    expect(await service.loadStudyToken(), isNull);
    expect(await service.loadCampusToken(), isNull);
  });

  test('logout invalidates immediately and clears the shared browser store after queued injections', () async {
    final injectionStarted = Completer<void>();
    final releaseInjection = Completer<void>();
    final events = <String>[];
    final injection = serializeWebViewCookies(() async {
      events.add('injection-start');
      injectionStarted.complete();
      await releaseInjection.future;
      events.add('injection-end');
    });
    await injectionStarted.future;
    final service = SsoService(
      clearWebViewCookies: () => serializeWebViewCookies(() async {
        events.add('clear');
      }),
    );
    addTearDown(() => service.dio.close(force: true));
    final previousRevision = service.sessionRevision.value;
    final logout = service.logout();
    expect(service.sessionRevision.value, greaterThan(previousRevision));
    await expectLater(
      service.loadWebViewCookie(),
      throwsA(isA<SsoLoginRequired>()),
    );
    expect(events, ['injection-start']);
    releaseInjection.complete();
    await Future.wait([injection, logout]);
    expect(events, ['injection-start', 'injection-end', 'clear']);
    await expectLater(
      service.loadWebViewCookie(),
      throwsA(isA<SsoLoginRequired>()),
    );
    expect((await AuthStorage().loadCredentials())?.username, 'student-a');
    await AuthStorage().saveCredentials('student-b', 'password-b');
    expect(await service.loadWebViewCookie(), 'sso-ticket-b');
  });

  test(
    'a failed cookie operation does not block the next logout cleanup',
    () async {
      await expectLater(
        serializeWebViewCookies(() async {
          throw StateError('native store failure');
        }),
        throwsStateError,
      );
      var cleared = false;
      await serializeWebViewCookies(() async {
        cleared = true;
      });
      expect(cleared, isTrue);
    },
  );
  test('native cleanup first stops every mounted SSO browser', () async {
    final stopped = <String>[];
    final removeA = registerSsoBrowser(() async {
      stopped.add('a');
    });
    final removeB = registerSsoBrowser(() async {
      stopped.add('b');
    });
    await clearNativeWebViewCookies();
    expect(stopped, ['a', 'b']);
    removeA();
    removeB();
    await clearNativeWebViewCookies();
    expect(stopped, ['a', 'b']);
  });
}
