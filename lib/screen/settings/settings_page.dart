import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/settings/schedule_settings_page.dart';
import 'package:fzu_assistant/screen/settings/general_settings_page.dart';
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
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(l10n.scheduleSettings),
            subtitle: Text(l10n.selectSemester),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(const ScheduleSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.generalSettings),
            subtitle: Text(l10n.language),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(const GeneralSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.themeSettings),
            subtitle: Text(l10n.themeColor),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(const ThemeSection()),
          ),
        ],
      ),
    );
  }
}
