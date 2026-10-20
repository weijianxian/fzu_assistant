import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/account_service.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';
import 'package:fzu_assistant/service/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SsoService sso;
  late AccountService accounts;
  var academicClears = 0;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'fzu_username': 'academic-a',
      'fzu_password': 'password',
      for (final account in ['academic-a', 'academic-b'])
        for (final key in ['cookie', 'study_token', 'campus_token'])
          'fzu_sso_${account}_$key': 'fake-$key',
    });
    sso = SsoService();
    academicClears = 0;
    accounts = AccountService(
      sso: sso,
      clearAcademicSession: () async {
        expect((await AuthStorage().loadCredentials())?.username, 'academic-a');
        expect(await sso.hasSession(), isFalse);
        academicClears++;
      },
    );
  });
  tearDown(() => sso.dio.close(force: true));
  test('SSO logout clears its three sessions and leaves academic and other accounts intact', () async {
    expect(await accounts.loadStatus(), (
      academicAccount: 'academic-a',
      ssoSignedIn: true,
    ));
    await accounts.logoutSso();
    expect(await accounts.loadStatus(), (
      academicAccount: 'academic-a',
      ssoSignedIn: false,
    ));
    expect(await sso.loadStudyToken(), isNull);
    expect(await sso.loadCampusToken(), isNull);
    expect(academicClears, 0);
    await AuthStorage().saveCredentials('academic-b', 'password');
    expect(await sso.hasSession(), isTrue);
    expect(await sso.loadStudyToken(), 'fake-study_token');
    expect(await sso.loadCampusToken(), 'fake-campus_token');
  });
  test(
    'academic logout clears account-scoped SSO before removing credentials',
    () async {
      await accounts.logoutAcademic();
      expect(await accounts.loadStatus(), (
        academicAccount: null,
        ssoSignedIn: false,
      ));
      expect(academicClears, 1);
      await AuthStorage().saveCredentials('academic-a', 'password');
      expect(await sso.hasSession(), isFalse);
      expect(await sso.loadStudyToken(), isNull);
      expect(await sso.loadCampusToken(), isNull);
    },
  );
  test('a remaining business token counts as an SSO session even without its cookie', () async {
    await accounts.logoutSso();
    await sso.saveStudyToken('business-session');
    expect((await accounts.loadStatus()).ssoSignedIn, isTrue);
  });
  test(
    'failed academic cleanup retains credentials so logout can be retried',
    () async {
      final failing = AccountService(
        sso: sso,
        clearAcademicSession: () async => throw StateError('cleanup failed'),
      );
      await expectLater(failing.logoutAcademic(), throwsStateError);
      expect((await accounts.loadStatus()).academicAccount, 'academic-a');
      expect((await accounts.loadStatus()).ssoSignedIn, isFalse);
    },
  );
}
