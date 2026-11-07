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

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.generalSettings)),
      body: AppListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SettingsSection.list(
            title: l10n.settingsGeneralSection,
            children: [
              ValueListenableBuilder(
                valueListenable: settings.localeKey,
                builder: (_, key, _) => SettingsChoiceTile<String>(
                  leading: const Icon(Icons.language),
                  title: l10n.language,
                  choices: [
                    SettingsChoice(value: 'system', label: l10n.followSystem),
                    SettingsChoice(
                      value: 'zh',
                      label: AppSettings.labelOf('zh'),
                    ),
                    SettingsChoice(
                      value: 'en',
                      label: AppSettings.labelOf('en'),
                    ),
                  ],
                  value: key,
                  onChanged: (value) => settings.localeKey.value = value,
                ),
              ),
              SettingSwitchTile(
                secondary: const Icon(Icons.web_outlined),
                notifier: settings.siteInjectionEnabled,
                title: Text(l10n.siteInjection),
                subtitle: Text(l10n.siteInjectionDescription),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
