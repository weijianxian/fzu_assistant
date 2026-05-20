import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/section.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

String themeName(String key, AppLocalizations l10n) {
  return switch (key) {
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
}

class ThemeSection extends HookWidget {
  const ThemeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearance)),
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
                    children: [
                      if (AppSettings.dynamicColorSupported)
                        _ThemeTile(
                          name: themeName('dynamic', l10n),
                          cs: AppSettings.systemColorScheme(
                            isDark ? Brightness.dark : Brightness.light,
                          )!,
                          selected: currentKey == 'dynamic',
                          onTap: () => settings.themeKey.value = 'dynamic',
                        ),
                      ...appThemes.map((theme) {
                        final selected = currentKey == theme.key;
                        final themeCs = ColorScheme.fromSeed(
                          seedColor: theme.color,
                          brightness: isDark
                              ? Brightness.dark
                              : Brightness.light,
                        );
                        return _ThemeTile(
                          name: themeName(theme.key, l10n),
                          cs: themeCs,
                          selected: selected,
                          onTap: () => settings.themeKey.value = theme.key,
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String name;
  final ColorScheme cs;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.name,
    required this.cs,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: selected ? Border.all(color: onSurface, width: 2) : null,
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
                    style: TextStyle(
                      fontSize: 15,
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
    );
  }
}

class _ColorDots extends StatelessWidget {
  final Color primary;
  final Color secondary;
  final Color tertiary;

  const _ColorDots({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
              decoration: BoxDecoration(
                color: secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 4,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: tertiary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPalette extends StatelessWidget {
  final ColorScheme cs;

  const _MiniPalette({required this.cs});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
}
