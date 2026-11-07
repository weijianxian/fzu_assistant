import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/theme_customization_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final active = useValueListenable(settings.activeCustomTheme);
    final profiles = useValueListenable(settings.customThemes);
    final failure = useValueListenable(settings.customThemeError);
    final loading = useFuture(
      useMemoized(() => settings.loadCustomThemes(), [settings]),
    );
    final busy = useState(false);
    final brightness = Theme.of(context).brightness;
    final colorKeys = [
      if (AppSettings.dynamicColorSupported || color == 'dynamic') 'dynamic',
      for (final theme in appThemes) theme.key,
    ];

    void report(Object error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }

    Future<void> action(Future<void> Function() operation) async {
      if (busy.value) return;
      busy.value = true;
      try {
        await operation();
      } catch (error) {
        report(error);
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    Future<void> edit(ThemeProfile profile) => context.pushNamed<void>(
      AppRoutes.themeEdit,
      arguments: ThemeEditArgs(profile: profile),
    );

    Future<void> importTheme() => action(() async {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'FZU Theme',
            extensions: ['fzutheme', 'zip', 'json'],
            uniformTypeIdentifiers: ['public.data'],
            mimeTypes: [
              'application/zip',
              'application/json',
              'application/octet-stream',
            ],
          ),
        ],
      );
      if (file == null || !context.mounted) return;
      await settings.importCustomTheme(File(file.path));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.themeImported)));
      }
    });

    Future<void> exportTheme(
      ThemeProfile profile, {
      required bool share,
      required BuildContext buttonContext,
    }) => action(() async {
      final box = buttonContext.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      final root = await settings.themeStore.ensureDirectory();
      final desktop =
          Platform.isWindows || Platform.isMacOS || Platform.isLinux;
      File destination = File(
        '${root.path}${Platform.pathSeparator}exports'
        '${Platform.pathSeparator}${profile.id}.fzutheme',
      );
      if (!share && desktop) {
        final location = await getSaveLocation(
          suggestedName: _themeFileName(profile.name),
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'FZU Theme',
              extensions: ['fzutheme'],
              uniformTypeIdentifiers: ['public.data'],
            ),
          ],
        );
        if (location == null || !context.mounted) return;
        destination = File(location.path);
      }
      final asset = await settings.themeStore.exportTheme(
        profile,
        destination: destination,
      );
      if (!context.mounted) return;
      Future<void> shareFile() => SharePlus.instance
          .share(
            ShareParams(
              title: profile.name,
              files: [XFile(asset.file.path, mimeType: asset.mimeType)],
              sharePositionOrigin: origin,
            ),
          )
          .then<void>((_) {});
      if (share && !Platform.isLinux) {
        await shareFile();
      } else {
        await showAppBottomSheet<void>(
          context: context,
          builder: (sheetContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(l10n.themeExported),
                subtitle: Text(l10n.themePackageHelp),
              ),
              if (!Platform.isLinux)
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(l10n.themeShare),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    try {
                      await shareFile();
                    } catch (error) {
                      report(error);
                    }
                  },
                ),
              if (desktop)
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: Text(l10n.papersOpenFolder),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    try {
                      if (!await launchUrl(
                        asset.file.parent.uri,
                        mode: LaunchMode.externalApplication,
                      )) {
                        report(l10n.papersOpenFailed);
                      }
                    } catch (error) {
                      report(error);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(l10n.papersCopyLocalPath),
                subtitle: Text(asset.file.path),
                onTap: () {
                  unawaited(
                    Clipboard.setData(ClipboardData(text: asset.file.path)),
                  );
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        );
      }
    });

    Future<void> delete(ThemeProfile profile) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.themeDelete),
          content: Text('${profile.name}\n\n${l10n.themeDeleteMessage}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.learningCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.themeDelete),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await action(() => settings.deleteCustomTheme(profile.id));
      }
    }

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
                  SettingsChoice(
                    value: InterfaceStyle.continuousCards,
                    label: l10n.interfaceStyleContinuousCards,
                    detail: l10n.interfaceStyleContinuousCardsDescription,
                  ),
                ],
                onChanged: (value) => settings.interfaceStyle.value = value,
              ),
            ],
          ),
          SettingsSection.list(
            title: l10n.themeMyThemes,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.themeCreate),
                onTap: busy.value
                    ? null
                    : () => edit(
                        ThemeProfile(
                          id: ThemeCustomizationService.createId(),
                          name: l10n.themeUntitled,
                          baseThemeKey: active?.baseThemeKey ?? color,
                          light: active?.light ?? ThemeVariant(),
                          dark: active?.dark ?? ThemeVariant(),
                        ),
                      ),
              ),
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: Text(l10n.themeImport),
                subtitle: Text(l10n.themeImportHelp),
                onTap: busy.value ? null : importTheme,
              ),
              if (busy.value ||
                  loading.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              if (failure != null)
                ListTile(
                  title: Text(failure),
                  trailing: IconButton(
                    tooltip: l10n.retry,
                    icon: const Icon(Icons.refresh),
                    onPressed: () => settings.loadCustomThemes(),
                  ),
                ),
              if (profiles.isEmpty &&
                  loading.connectionState == ConnectionState.done &&
                  failure == null)
                ListTile(title: Text(l10n.themeEmpty)),
              for (final profile in profiles)
                _ThemeTile(
                  key: ValueKey('theme-custom-${profile.id}'),
                  name: profile.name,
                  cs: settings
                      .buildProfileTheme(profile, brightness)
                      .colorScheme,
                  selected: active?.id == profile.id,
                  onTap: () => settings.activateCustomTheme(profile),
                  trailing: Builder(
                    builder: (buttonContext) => PopupMenuButton<String>(
                      enabled: !busy.value,
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit':
                            await edit(profile);
                          case 'copy':
                            await edit(
                              profile.copyWith(
                                id: ThemeCustomizationService.createId(),
                                name:
                                    '${profile.name} · ${l10n.themeCopy}'
                                            .length <=
                                        80
                                    ? '${profile.name} · ${l10n.themeCopy}'
                                    : profile.name,
                              ),
                            );
                          case 'share':
                            await exportTheme(
                              profile,
                              share: true,
                              buttonContext: buttonContext,
                            );
                          case 'export':
                            await exportTheme(
                              profile,
                              share: false,
                              buttonContext: buttonContext,
                            );
                          case 'delete':
                            await delete(profile);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(l10n.themeEdit),
                        ),
                        PopupMenuItem(
                          value: 'copy',
                          child: Text(l10n.themeDuplicate),
                        ),
                        if (!Platform.isLinux)
                          PopupMenuItem(
                            value: 'share',
                            child: Text(l10n.themeShare),
                          ),
                        PopupMenuItem(
                          value: 'export',
                          child: Text(l10n.themeExport),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.themeDelete),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SettingsSection.list(
            title: l10n.themeColor,
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
                  selected: active == null && color == key,
                  onTap: () => settings.selectPresetTheme(key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _themeFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .trim()
      .replaceFirst(RegExp(r'[. ]+$'), '');
  final safe =
      cleaned.isEmpty ||
          RegExp(
            r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$',
            caseSensitive: false,
          ).hasMatch(cleaned)
      ? 'theme'
      : cleaned;
  return '$safe.fzutheme';
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    super.key,
    required this.name,
    required this.cs,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String name;
  final ColorScheme cs;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = InterfaceTheme.of(context).style.isCard;
    final radius = cards ? BorderRadius.zero : BorderRadius.circular(16);
    final foreground = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: cards
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: selected
              ? theme.colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
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
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    _MiniPalette(cs: cs),
                    ?trailing,
                  ],
                ),
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
