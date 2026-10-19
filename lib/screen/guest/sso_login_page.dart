import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';
import 'package:fzu_assistant/service/auth_storage.dart';

class SsoLoginPage extends HookWidget {
  const SsoLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final account = useTextEditingController();
    final password = useTextEditingController();
    final busy = useState(false);
    final error = useState<String?>(null);
    useEffect(() {
      AuthStorage().loadCredentials().then((credentials) {
        if (context.mounted && account.text.isEmpty) {
          account.text = credentials?.username ?? '';
        }
      });
      return null;
    }, const []);

    Future<void> login() async {
      if (busy.value) return;
      busy.value = true;
      error.value = null;
      try {
        await SsoService.instance.login(
          account.text,
          password.text,
          onSmsRequired: (phone, tip, sendSms) async {
            if (!context.mounted) return null;
            return showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  _SmsDialog(phone: phone, tip: tip, sendSms: sendSms),
            );
          },
        );
        if (context.mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (context.mounted) error.value = e.toString();
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return PopScope(
      canPop: !busy.value,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.ssoLogin)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Text(l10n.ssoLoginDescription),
                const SizedBox(height: 24),
                TextField(
                  controller: account,
                  enabled: !busy.value,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(labelText: l10n.studentId),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  enabled: !busy.value,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(labelText: l10n.password),
                  onSubmitted: (_) => login(),
                ),
                if (error.value != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      error.value!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy.value ? null : login,
                  child: busy.value
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmsDialog extends HookWidget {
  const _SmsDialog({
    required this.phone,
    required this.tip,
    required this.sendSms,
  });
  final String phone, tip;
  final Future<void> Function() sendSms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final code = useTextEditingController();
    final busy = useState(false);
    final error = useState<String?>(null);
    final sent = useState(false);
    return AlertDialog(
      title: Text(l10n.ssoSmsVerification),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$tip\n$phone'),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: InputDecoration(labelText: l10n.captcha),
            ),
            TextButton(
              onPressed: busy.value || sent.value
                  ? null
                  : () async {
                      busy.value = true;
                      error.value = null;
                      try {
                        await sendSms();
                        if (context.mounted) sent.value = true;
                      } catch (e) {
                        if (context.mounted) error.value = e.toString();
                      } finally {
                        if (context.mounted) busy.value = false;
                      }
                    },
              child: Text(sent.value ? l10n.ssoSmsSent : l10n.ssoSendSms),
            ),
            if (error.value != null) Text(error.value!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy.value ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.learningCancel),
        ),
        FilledButton(
          onPressed: busy.value
              ? null
              : () {
                  if (code.text.trim().isNotEmpty) {
                    Navigator.of(context).pop(code.text.trim());
                  }
                },
          child: Text(l10n.learningConfirm),
        ),
      ],
    );
  }
}
