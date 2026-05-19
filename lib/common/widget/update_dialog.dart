import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/half_screen_sheet.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/github_release.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showUpdateSheet(
  BuildContext context, {
  required GitHubRelease release,
  required VoidCallback onSkip,
}) {
  return showHalfScreenSheet(
    context,
    builder: (controller) {
      final l10n = AppLocalizations.of(context)!;
      final colorScheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;

      return ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.system_update, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.newVersionAvailable,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'v${release.version}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Release notes
          Text(
            l10n.releaseNotes,
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              release.body.isEmpty ? '-' : release.body,
              style: textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    onSkip();
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.skipThisVersion),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    launchUrl(
                      Uri.parse(release.htmlUrl),
                      mode: LaunchMode.externalApplication,
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.downloadUpdate),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
