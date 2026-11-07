import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

String themeName(String key, AppLocalizations l10n) => switch (key) {
  'dynamic' => l10n.themeDynamic,
  'deep_purple' => l10n.themeDeepPurple,
  'blue' => l10n.themeBlue,
  'teal' => l10n.themeTeal,
  'green' => l10n.themeGreen,
  'orange' => l10n.themeOrange,
  'red' => l10n.themeRed,
  'pink' => l10n.themePink,
  'indigo' => l10n.themeIndigo,
  'brown' => l10n.themeBrown,
  _ => key,
};

class ThemeSection extends HookWidget {
  const ThemeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    final style = useValueListenable(settings.interfaceStyle);
    final mode = useValueListenable(settings.themeModeKey);
    final color = useValueListenable(settings.themeKey);
    final brightness = Theme.of(context).brightness;
    final colorKeys = [
      if (AppSettings.dynamicColorSupported || color == 'dynamic') 'dynamic',
      for (final theme in appThemes) theme.key,
    ];

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.appearance)),
      body: AppListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SettingsSection.list(
            title: l10n.settingsDisplaySection,
            children: [
              SettingsChoiceTile<String>(
                leading: const Icon(Icons.brightness_6_outlined),
                title: l10n.appearance,
                value: mode,
                choices: [
                  SettingsChoice(value: 'system', label: l10n.followSystem),
                  SettingsChoice(value: 'light', label: l10n.light),
                  SettingsChoice(value: 'dark', label: l10n.dark),
                ],
                onChanged: (value) => settings.themeModeKey.value = value,
              ),
              SettingsChoiceTile<InterfaceStyle>(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: l10n.interfaceStyle,
                value: style,
                choices: [
                  SettingsChoice(
                    value: InterfaceStyle.classic,
                    label: l10n.interfaceStyleClassic,
                    detail: l10n.interfaceStyleClassicDescription,
                  ),
                  SettingsChoice(
                    value: InterfaceStyle.cards,
                    label: l10n.interfaceStyleCards,
                    detail: l10n.interfaceStyleCardsDescription,
                  ),
                ],
                onChanged: (value) => settings.interfaceStyle.value = value,
              ),
            ],
          ),
          Section(
            title: l10n.themeColor,
            child: Column(
              children: [
                for (final key in colorKeys)
                  _ThemeTile(
                    key: ValueKey('theme-color-$key'),
                    name: themeName(key, l10n),
                    cs: key == 'dynamic'
                        ? AppSettings.systemColorScheme(brightness) ??
                              Theme.of(context).colorScheme
                        : ColorScheme.fromSeed(
                            seedColor: appThemes
                                .firstWhere((theme) => theme.key == key)
                                .color,
                            brightness: brightness,
                          ),
                    selected: color == key,
                    onTap: () => settings.themeKey.value = key,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    super.key,
    required this.name,
    required this.cs,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final ColorScheme cs;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(16);

    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  _ColorDots(
                    primary: cs.primary,
                    secondary: cs.secondary,
                    tertiary: cs.tertiary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  _MiniPalette(cs: cs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDots extends StatelessWidget {
  const _ColorDots({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    height: 36,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: secondary, shape: BoxShape.circle),
          ),
        ),
        Positioned(
          left: 4,
          bottom: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: tertiary, shape: BoxShape.circle),
          ),
        ),
      ],
    ),
  );
}

class _MiniPalette extends StatelessWidget {
  const _MiniPalette({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: 60,
      height: 32,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container(color: cs.primary)),
                Expanded(child: Container(color: cs.secondary)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container(color: cs.primaryContainer)),
                Expanded(child: Container(color: cs.secondaryContainer)),
                Expanded(child: Container(color: cs.tertiaryContainer)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
