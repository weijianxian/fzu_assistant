import 'package:flutter/material.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';

Future<void> showLearningSeatGuide(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(AppLocalizations.of(context)!.learningSeatGuide),
      ),
      body: SafeArea(
        top: false,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 8,
          child: Image.asset(
            'assets/learning_center/seat-guide.jpg',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            semanticLabel: AppLocalizations.of(context)!.learningSeatGuide,
          ),
        ),
      ),
    ),
  ),
);

Future<bool> confirmLearningAction(
  BuildContext context,
  String title,
  String detail,
) async {
  final l10n = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.learningCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.learningConfirm),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> showLearningError(BuildContext context, Object error) async {
  if (!context.mounted) return;
  if (error is SsoLoginRequired) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.ssoSessionExpired)),
    );
    await context.pushNamed(AppRoutes.ssoLogin);
    return;
  }
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(error.toString())));
}

class LearningLoginPrompt extends StatelessWidget {
  const LearningLoginPrompt({super.key, required this.onLogin});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(l10n.ssoLoginDescription),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login),
            label: Text(l10n.ssoLogin),
          ),
        ],
      ),
    );
  }
}
