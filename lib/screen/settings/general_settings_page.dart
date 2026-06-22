import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class GeneralSettingsPage extends HookWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.generalSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Section(
            title: l10n.language,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder(
                valueListenable: settings.localeKey,
                builder: (_, key, _) => SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'system',
                      icon: const Icon(Icons.phone_android),
                      label: Text(l10n.followSystem),
                    ),
                    ButtonSegment(
                      value: 'zh',
                      label: Text(AppSettings.labelOf('zh')),
                    ),
                    ButtonSegment(
                      value: 'en',
                      label: Text(AppSettings.labelOf('en')),
                    ),
                  ],
                  selected: {key},
                  onSelectionChanged: (s) => settings.localeKey.value = s.first,
                ),
              ),
            ),
          ),
          Section(
            title: l10n.webEnhancement,
            child: SettingSwitchTile(
              notifier: settings.siteInjectionEnabled,
              title: Text(l10n.siteInjection),
              subtitle: Text(l10n.siteInjectionDescription),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
