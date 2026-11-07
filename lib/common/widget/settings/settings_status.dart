import 'package:flutter/material.dart';

class SettingsStatus extends StatelessWidget {
  const SettingsStatus({
    super.key,
    required this.title,
    this.details = const [],
    this.action,
    this.footer,
    this.isError = false,
  });

  final String title;
  final List<String> details;
  final Widget? action, footer;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: isError ? theme.colorScheme.error : null,
              ),
            ),
          ),
          for (final detail in details)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (action != null) ...[const SizedBox(height: 12), action!],
          if (footer != null) ...[const SizedBox(height: 8), footer!],
        ],
      ),
    );
  }
}
