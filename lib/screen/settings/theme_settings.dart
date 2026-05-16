import 'package:flutter/material.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/theme/app_themes.dart';
import 'package:fzu_assistant/theme/theme_provider.dart';

String _themeName(String key, AppLocalizations l10n) {
  return switch (key) {
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

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = ThemeProvider.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.themeSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── 深色模式 ──
          _SectionHeader(AppLocalizations.of(context)!.appearance),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ValueListenableBuilder(
              valueListenable: state.themeMode,
              builder: (_, mode, _) => SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.brightness_auto),
                    label: Text(AppLocalizations.of(context)!.followSystem),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.light_mode),
                    label: Text(AppLocalizations.of(context)!.light),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: const Icon(Icons.dark_mode),
                    label: Text(AppLocalizations.of(context)!.dark),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => state.themeMode.value = s.first,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── 主题选择 ──
          _SectionHeader(AppLocalizations.of(context)!.themeColor),
          ValueListenableBuilder(
            valueListenable: state.themeMode,
            builder: (_, mode, _) {
              final isDark = mode == 2 ||
                  (mode == 0 &&
                      MediaQuery.platformBrightnessOf(context) ==
                          Brightness.dark);
              return ValueListenableBuilder(
                valueListenable: state.themeIndex,
                builder: (_, idx, _) => Column(
                  children: List.generate(appThemes.length, (i) {
                    final theme = appThemes[i];
                    final selected = idx == i;
                    final themeCs = ColorScheme.fromSeed(
                      seedColor: theme.color,
                      brightness:
                          isDark ? Brightness.dark : Brightness.light,
                    );
                    return _ThemeTile(
                      name: _themeName(theme.key, AppLocalizations.of(context)!),
                      cs: themeCs,
                      selected: selected,
                      onTap: () => state.themeIndex.value = i,
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary)),
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
              border: selected
                  ? Border.all(color: onSurface, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                // 三色圆点组
                _ColorDots(
                  primary: cs.primary,
                  secondary: cs.secondary,
                  tertiary: cs.tertiary,
                ),
                const SizedBox(width: 16),
                // 名称
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal)),
                ),
                // 色条预览
                _MiniPalette(cs: cs),
                if (selected) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.check_circle, color: cs.primary, size: 22),
                ],
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
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
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
