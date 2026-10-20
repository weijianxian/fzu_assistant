import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';
import 'package:fzu_assistant/service/auth_storage.dart';

typedef AccountStatus = ({String? academicAccount, bool ssoSignedIn});

class AccountService {
  AccountService({
    AuthStorage? auth,
    SsoService? sso,
    Future<void> Function()? clearAcademicSession,
  }) : auth = auth ?? AuthStorage(),
       sso = sso ?? SsoService.instance,
       _clearAcademicSession =
           clearAcademicSession ?? ApiClient.instance.clearSession;
  static final instance = AccountService();
  final AuthStorage auth;
  final SsoService sso;
  final Future<void> Function() _clearAcademicSession;

  Future<AccountStatus> loadStatus() async {
    final account = (await auth.loadCredentials())?.username;
    return (
      academicAccount: account,
      ssoSignedIn: account != null && await sso.hasSession(),
    );
  }

  Future<void> logoutSso() => sso.logout();

  Future<void> logoutAcademic() async {
    // SSO storage is keyed by the academic account, so clear it first.
    if (await auth.loadCredentials() != null) await sso.logout();
    await _clearAcademicSession();
    await auth.clearCredentials();
  }
}
