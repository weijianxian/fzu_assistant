import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/account_service.dart';

class AccountManagementPage extends HookWidget {
  const AccountManagementPage({super.key, this.service});
  final AccountService? service;

  @override
  Widget build(BuildContext context) {
    final api = service ?? AccountService.instance;
    final l10n = AppLocalizations.of(context)!;
    final status = useAsyncData(api.loadStatus);
    final busy = useState(false);

    Future<void> logout(bool academic) async {
      if (busy.value) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.logout),
          content: Text(
            academic
                ? l10n.accountAcademicLogoutDescription
                : l10n.ssoLogoutDescription,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.learningCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.learningConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      busy.value = true;
      try {
        if (academic) {
          await api.logoutAcademic();
          if (context.mounted) context.replaceAllNamed(AppRoutes.login);
        } else {
          await api.logoutSso();
          if (context.mounted) await status.refresh();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
          await status.refresh();
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return PopScope(
      canPop: !busy.value,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.accountManagement)),
        body: status.loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: status.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (status.error != null)
                      ListTile(
                        title: Text(status.error!),
                        trailing: TextButton(
                          onPressed: status.refresh,
                          child: Text(l10n.retry),
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text(l10n.accountAcademic),
                      subtitle: Text(
                        status.data?.academicAccount ?? l10n.accountSignedOut,
                      ),
                      trailing: TextButton(
                        onPressed:
                            busy.value || status.data?.academicAccount == null
                            ? null
                            : () => logout(true),
                        child: Text(l10n.logout),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.account_circle_outlined),
                      title: Text(l10n.accountSso),
                      subtitle: Text(
                        status.data?.ssoSignedIn == true
                            ? l10n.accountSsoDescription
                            : l10n.accountSignedOut,
                      ),
                      trailing: TextButton(
                        onPressed:
                            busy.value || status.data?.ssoSignedIn != true
                            ? null
                            : () => logout(false),
                        child: Text(l10n.logout),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
