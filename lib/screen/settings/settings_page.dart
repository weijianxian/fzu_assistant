import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/section.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/theme/theme_tile.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/screen/settings/theme/app_themes.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── 外观模式 ──
          Section(
            title: l10n.appearance,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder(
                valueListenable: settings.themeModeKey,
                builder: (_, modeKey, _) => SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'system',
                      icon: const Icon(Icons.brightness_auto),
                      label: Text(l10n.followSystem),
                    ),
                    ButtonSegment(
                      value: 'light',
                      icon: const Icon(Icons.light_mode),
                      label: Text(l10n.light),
                    ),
                    ButtonSegment(
                      value: 'dark',
                      icon: const Icon(Icons.dark_mode),
                      label: Text(l10n.dark),
                    ),
                  ],
                  selected: {modeKey},
                  onSelectionChanged: (s) =>
                      settings.themeModeKey.value = s.first,
                ),
              ),
            ),
          ),

          // ── 主题色 ──
          Section(
            title: l10n.themeColor,
            child: ValueListenableBuilder(
              valueListenable: settings.themeModeKey,
              builder: (_, modeKey, _) {
                final isDark =
                    modeKey == 'dark' ||
                    (modeKey == 'system' &&
                        MediaQuery.platformBrightnessOf(context) ==
                            Brightness.dark);
                return ValueListenableBuilder(
                  valueListenable: settings.themeKey,
                  builder: (_, currentKey, _) => Column(
                    children: appThemes.map((theme) {
                      final selected = currentKey == theme.key;
                      final themeCs = ColorScheme.fromSeed(
                        seedColor: theme.color,
                        brightness: isDark ? Brightness.dark : Brightness.light,
                      );
                      return ThemeTile(
                        name: themeName(theme.key, l10n),
                        cs: themeCs,
                        selected: selected,
                        onTap: () => settings.themeKey.value = theme.key,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),

          // ── 语言 ──
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
