import 'package:flutter/material.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/l10n/locale_provider.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localeState = LocaleProvider.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.language)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
            child: Text(
              AppLocalizations.of(context)!.language,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ValueListenableBuilder(
              valueListenable: localeState.localeKey,
              builder: (_, key, _) => SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'system',
                    icon: const Icon(Icons.phone_android),
                    label: Text(AppLocalizations.of(context)!.followSystem),
                  ),
                  ButtonSegment(
                    value: 'zh',
                    label: Text(LocaleState.labelOf('zh')),
                  ),
                  ButtonSegment(
                    value: 'en',
                    label: Text(LocaleState.labelOf('en')),
                  ),
                ],
                selected: {key},
                onSelectionChanged: (s) =>
                    localeState.localeKey.value = s.first,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
