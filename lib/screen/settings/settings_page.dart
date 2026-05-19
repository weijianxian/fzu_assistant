import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/section.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/theme/theme_tile.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/screen/settings/theme/app_themes.dart';
import 'package:fzu_assistant/service/api/course_service.dart';

class SettingsPage extends HookWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 学期列表加载
    final termsLoading = useState(false);
    final termsError = useState<String?>(null);

    Future<void> loadTerms() async {
      if (settings.termsKey.value.isNotEmpty) return;
      termsLoading.value = true;
      termsError.value = null;
      try {
        final termInfo = await CourseService().getTerms();
        settings.termsKey.value = termInfo.terms;
      } catch (e) {
        termsError.value = e.toString();
      }
      termsLoading.value = false;
    }

    useEffect(() {
      loadTerms();
      return null;
    }, []);

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

          // ── 学期 ──
          Section(
            title: l10n.selectSemester,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder(
                valueListenable: settings.selectedSemesterKey,
                builder: (_, selected, _) {
                  final terms = settings.termsKey.value;

                  if (termsLoading.value) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  if (termsError.value != null) {
                    return ListTile(
                      title: Text(termsError.value!),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          termsError.value = null;
                          loadTerms();
                        },
                      ),
                    );
                  }

                  return DropdownButton<String>(
                    value: selected.isEmpty ? '' : selected,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l10n.autoSemester),
                      ),
                      for (final term in terms)
                        DropdownMenuItem(
                          value: term,
                          child: Text(AppSettings.formatSemester(term)),
                        ),
                    ],
                    onChanged: (v) {
                      settings.selectedSemesterKey.value = v ?? '';
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
