import 'package:flutter/material.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';

class SettingsPermissionTile extends StatelessWidget {
  const SettingsPermissionTile({
    super.key,
    required this.title,
    this.purpose,
    required this.granted,
    required this.onTap,
  });

  final String title;
  final String? purpose;
  final bool? granted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = granted == null
        ? l10n.reminderPermissionLoading
        : granted!
        ? l10n.reminderPermissionGranted
        : l10n.reminderPermissionDenied;
    return ListTile(
      leading: Icon(
        granted == true ? Icons.check_circle_outline : Icons.lock_outline,
      ),
      title: Text(title),
      subtitle: Text(purpose == null ? state : '$state · $purpose'),
      trailing: const Icon(Icons.open_in_new),
      onTap: onTap,
    );
  }
}
