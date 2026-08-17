import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/settings/home_settings_page.dart';
import 'package:fzu_assistant/screen/settings/general_settings_page.dart';
import 'package:fzu_assistant/screen/settings/advanced_settings_page.dart';
import 'package:fzu_assistant/screen/settings/theme/theme_section.dart';

class SettingsPage extends HookWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ChevronListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(l10n.homeSettings),
            subtitle: Text(l10n.homeSettingsSubtitle),
            onTap: () => context.push(const HomeSettingsPage()),
          ),
          ChevronListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.generalSettings),
            subtitle: Text(l10n.generalSettingsSubtitle),
            onTap: () => context.push(const GeneralSettingsPage()),
          ),
          ChevronListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.themeSettings),
            subtitle: Text(l10n.themeSettingsSubtitle),
            onTap: () => context.push(const ThemeSection()),
          ),
          ChevronListTile(
            leading: const Icon(Icons.settings_ethernet),
            title: Text(l10n.advancedSettings),
            subtitle: Text(l10n.advancedSettingsSubtitle),
            onTap: () => context.push(const AdvancedSettingsPage()),
          ),
        ],
      ),
    );
  }
}
