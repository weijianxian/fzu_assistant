import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/layout/app_theme_background.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/screen/schedule/widgets/course_card.dart';
import 'package:fzu_assistant/screen/settings/theme/theme_section.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/course_color_palettes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/theme_customization_service.dart';
import 'package:fzu_assistant/service/theme_image_palette.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show ImagePickerPlatform;

enum _EditorTask { image, extract, save }

const _customCoursePalette = 'custom';

/// An isolated draft: only Save applies changes to the application's theme.
class ThemeEditorPage extends HookWidget {
  const ThemeEditorPage({super.key, required this.profile});

  final ThemeProfile profile;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    final original = useMemoized(() {
      ThemeVariant restoreSource(ThemeVariant value) =>
          value.colorSource == 'image' && value.backgroundImagePath == null
          ? value.copyWith(colorSource: 'system', clearSeedColor: true)
          : value;
      return profile.copyWith(
        light: restoreSource(profile.light),
        dark: restoreSource(profile.dark),
      );
    });
    final draft = useState(original);
    final name = useTextEditingController(text: original.name);
    useListenable(name);
    final nameError = useState(false);
    final mode = useState(Theme.of(context).brightness);
    final task = useState<_EditorTask?>(null);
    final leaving = useState(false);
    final confirming = useRef(false);
    final colorSheetOpen = useRef(false);
    final previewOpen = useRef(false);
    final controller = useScrollController();
    final style = useValueListenable(settings.interfaceStyle);
    final systemColorRevision = useValueListenable(
      settings.systemColorRevision,
    );
    final theme = useMemoized(
      () => settings.buildProfileTheme(draft.value, mode.value),
      [settings, draft.value, mode.value, style, systemColorRevision],
    );
    final variant = mode.value == Brightness.light
        ? draft.value.light
        : draft.value.dark;
    final dirty =
        name.text != original.name ||
        draft.value.baseThemeKey != original.baseThemeKey ||
        !_sameVariant(draft.value.light, original.light) ||
        !_sameVariant(draft.value.dark, original.dark);
    final materialColors = ThemeColors.fromScheme(theme.colorScheme);
    final systemColorsAvailable =
        AppSettings.dynamicColorSupported &&
        AppSettings.systemColorScheme(mode.value) != null;
    final source =
        variant.colorSource ??
        (draft.value.baseThemeKey == 'dynamic' ? 'system' : 'seed');
    final seed = Color(
      variant.seedColor ??
          (appThemes
                      .where((entry) => entry.key == draft.value.baseThemeKey)
                      .firstOrNull ??
                  appThemes.first)
              .color
              .toARGB32(),
    );
    final preset = appThemes
        .where((entry) => entry.color.toARGB32() == seed.toARGB32())
        .firstOrNull
        ?.key;
    final isCustomSeed = variant.isSeedColorCustom || preset == null;
    final coursePaletteDefaults = CourseColorPalettes.colors(
      variant.coursePaletteKey,
      dark: mode.value == Brightness.dark,
    );
    final coursePalette = variant.coursePalette.isEmpty
        ? coursePaletteDefaults
        : variant.coursePalette;

    ThemeVariant currentVariant(Brightness brightness) =>
        brightness == Brightness.light ? draft.value.light : draft.value.dark;

    void updateVariant(
      ThemeVariant Function(ThemeVariant) update, {
      Brightness? brightness,
    }) {
      final target = brightness ?? mode.value;
      final next = update(currentVariant(target));
      draft.value = target == Brightness.light
          ? draft.value.copyWith(light: next)
          : draft.value.copyWith(dark: next);
    }

    ThemeVariant palette(
      ThemeVariant value, {
      required String source,
      int? seedColor,
      bool? isSeedColorCustom,
    }) => value.copyWith(
      colorSource: source,
      seedColor: seedColor,
      isSeedColorCustom: isSeedColorCustom,
      colors: {
        for (final entry in value.colors.entries)
          if (!materialColors.containsKey(entry.key)) entry.key: entry.value,
      },
    );

    void showError(Object error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loadingFailed(error.toString()))),
      );
    }

    Future<bool> confirmPalette(Brightness brightness) async {
      if (!currentVariant(brightness).colors.keys
          .any(materialColors.containsKey)) {
        return true;
      }
      final target = brightness == Brightness.light ? l10n.light : l10n.dark;
      return await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.themeReplacePalette),
              content: Text(l10n.themeReplacePaletteMessage(target)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.learningCancel),
                ),
                FilledButton(
                  key: const ValueKey('theme-palette-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.learningConfirm),
                ),
              ],
            ),
          ) ==
          true;
    }

    Future<void> selectPalette(
      String source,
      int seedColor, {
      bool? isSeedColorCustom,
    }) async {
      if (task.value != null || confirming.value) return;
      final brightness = mode.value;
      confirming.value = true;
      try {
        if (!await confirmPalette(brightness) || !context.mounted) return;
        updateVariant(
          (value) => palette(
            value,
            source: source,
            seedColor: seedColor,
            isSeedColorCustom: isSeedColorCustom,
          ),
          brightness: brightness,
        );
      } finally {
        confirming.value = false;
      }
    }

    Future<void> exit() async {
      if (task.value != null || confirming.value) return;
      if (dirty) {
        confirming.value = true;
        final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.themeUnsavedTitle),
            content: Text(l10n.themeUnsavedMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.themeKeepEditing),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.themeDiscard),
              ),
            ],
          ),
        );
        confirming.value = false;
        if (discard != true || !context.mounted) return;
      }
      leaving.value = true;
      // Let PopScope see the decision before asking the navigator to pop.
      await WidgetsBinding.instance.endOfFrame;
      if (context.mounted) Navigator.of(context).pop();
    }

    Future<void> chooseImage() async {
      if (task.value != null) return;
      final brightness = mode.value;
      task.value = _EditorTask.image;
      try {
        final XFile? image;
        if (Platform.isAndroid || Platform.isIOS) {
          final implementation = ImagePickerPlatform.instance;
          if (implementation is ImagePickerAndroid) {
            implementation.useAndroidPhotoPicker = true;
          }
          image = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 4096,
            maxHeight: 4096,
            requestFullMetadata: false,
          );
        } else {
          image = await openFile(
            acceptedTypeGroups: [
              XTypeGroup(
                label: l10n.themeBackground,
                extensions: const ['png', 'jpg', 'jpeg', 'webp'],
                mimeTypes: const ['image/png', 'image/jpeg', 'image/webp'],
                uniformTypeIdentifiers: const [
                  'public.png',
                  'public.jpeg',
                  'org.webmproject.webp',
                ],
              ),
            ],
            confirmButtonText: l10n.themeChooseImage,
          );
        }
        if (image == null || !context.mounted) return;
        // Validate and sample off the UI isolate; refresh only an image source.
        final imageSeed = await ThemeImagePalette.seedFromFile(image.path);
        if (!context.mounted) return;
        final path = await settings.themeStore.importBackgroundImage(
          File(image.path),
        );
        if (!context.mounted) return;
        updateVariant(
          (value) => value.copyWith(
            backgroundImagePath: path,
            seedColor: value.colorSource == 'image'
                ? imageSeed.toARGB32()
                : null,
          ),
          brightness: brightness,
        );
      } catch (error) {
        showError(error);
      } finally {
        if (context.mounted) task.value = null;
      }
    }

    Future<void> selectImagePalette() async {
      if (task.value != null || confirming.value) return;
      final brightness = mode.value;
      final path = currentVariant(brightness).backgroundImagePath;
      if (path == null) return;
      confirming.value = true;
      try {
        if (!await confirmPalette(brightness) || !context.mounted) {
          return;
        }
        task.value = _EditorTask.extract;
        final seed = await ThemeImagePalette.seedFromFile(path);
        if (!context.mounted) return;
        updateVariant(
          (value) =>
              palette(value, source: 'image', seedColor: seed.toARGB32()),
          brightness: brightness,
        );
      } catch (error) {
        showError(error);
      } finally {
        confirming.value = false;
        if (context.mounted) task.value = null;
      }
    }

    Future<void> editSeed() async {
      if (task.value != null || colorSheetOpen.value) return;
      colorSheetOpen.value = true;
      final brightness = mode.value;
      try {
        final result = await showAppBottomSheet<_ColorEdit>(
          context: context,
          builder: (_) =>
              _ColorEditor(role: l10n.themeCustomSeed, initialColor: seed),
        );
        if (result == null || !context.mounted) return;
        if (!await confirmPalette(brightness) || !context.mounted) return;
        updateVariant(
          (value) => palette(
            value,
            source: 'seed',
            seedColor: result.argb ?? appThemes.first.color.toARGB32(),
            isSeedColorCustom: true,
          ),
          brightness: brightness,
        );
      } finally {
        colorSheetOpen.value = false;
      }
    }

    void selectCoursePalette(String key) => updateVariant(
      (value) => value.copyWith(
        coursePaletteKey: key,
        coursePalette: const [],
        colors: {...value.colors}
          ..remove('courseCard')
          ..remove('courseAccent'),
      ),
    );

    void updateCoursePalette(List<int> colors, Brightness brightness) {
      final value = currentVariant(brightness);
      final defaults = CourseColorPalettes.colors(
        value.coursePaletteKey,
        dark: brightness == Brightness.dark,
      );
      updateVariant(
        (value) => value.copyWith(
          coursePalette: listEquals(colors, defaults) ? const [] : colors,
          colors: {...value.colors}
            ..remove('courseCard')
            ..remove('courseAccent'),
        ),
        brightness: brightness,
      );
    }

    Future<void> generateCoursePalette() async {
      if (task.value != null || confirming.value || colorSheetOpen.value) {
        return;
      }
      final brightness = mode.value;
      final path = currentVariant(brightness).backgroundImagePath;
      if (path == null) return;
      task.value = _EditorTask.extract;
      try {
        final colors = await ThemeImagePalette.colorsFromFile(path);
        if (!context.mounted) return;
        updateCoursePalette(
          colors.map((color) => color.toARGB32()).toList(),
          brightness,
        );
      } catch (error) {
        showError(error);
      } finally {
        if (context.mounted) task.value = null;
      }
    }

    void addCoursePaletteColor() {
      if (task.value != null ||
          colorSheetOpen.value ||
          coursePalette.length >= CourseColorPalettes.maxColors) {
        return;
      }
      updateCoursePalette([
        ...coursePalette,
        theme.colorScheme.primary.toARGB32(),
      ], mode.value);
    }

    void removeCoursePaletteColor(int index) {
      if (task.value != null ||
          colorSheetOpen.value ||
          coursePalette.length <= 1) {
        return;
      }
      updateCoursePalette(
        List<int>.of(coursePalette)..removeAt(index),
        mode.value,
      );
    }

    Future<void> editCoursePaletteColor(int index) async {
      if (task.value != null || colorSheetOpen.value) return;
      colorSheetOpen.value = true;
      final brightness = mode.value;
      final defaults = CourseColorPalettes.colors(
        variant.coursePaletteKey,
        dark: brightness == Brightness.dark,
      );
      final originalColors = List<int>.of(coursePalette);
      try {
        final result = await showAppBottomSheet<_ColorEdit>(
          context: context,
          builder: (_) => _ColorEditor(
            role: l10n.themeCoursePaletteColor(index + 1),
            initialColor: Color(originalColors[index]),
          ),
        );
        if (result == null || !context.mounted) return;
        originalColors[index] =
            result.argb ?? defaults[index % defaults.length];
        updateCoursePalette(originalColors, brightness);
      } finally {
        colorSheetOpen.value = false;
      }
    }

    Future<void> save() async {
      if (task.value != null) return;
      if (!_validName(name.text)) {
        nameError.value = true;
        if (controller.hasClients) {
          await controller.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
        return;
      }
      task.value = _EditorTask.save;
      FocusScope.of(context).unfocus();
      try {
        await settings.saveCustomTheme(
          draft.value.copyWith(name: name.text.trim()),
        );
        if (!context.mounted) return;
        leaving.value = true;
        task.value = null;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.themeSaved)));
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted) Navigator.of(context).pop();
      } catch (error) {
        showError(error);
      } finally {
        if (context.mounted) task.value = null;
      }
    }

    Future<void> showPreview() async {
      if (task.value != null || previewOpen.value) return;
      previewOpen.value = true;
      FocusScope.of(context).unfocus();
      try {
        await showAppBottomSheet<void>(
          context: context,
          builder: (sheetContext) => AnimatedBuilder(
            animation: Listenable.merge([
              draft,
              name,
              mode,
              settings.interfaceStyle,
              settings.systemColorRevision,
            ]),
            builder: (sheetContext, _) {
              final previewTheme = settings.buildProfileTheme(
                draft.value,
                mode.value,
              );
              final scale = MediaQuery.textScalerOf(sheetContext);
              return Padding(
                key: const ValueKey('theme-preview-sheet'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.themePreview,
                            style: Theme.of(sheetContext).textTheme.titleLarge,
                          ),
                        ),
                        CloseButton(
                          key: const ValueKey('theme-preview-close'),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ThemeModeSelector(
                      key: const ValueKey('theme-preview-mode'),
                      mode: mode.value,
                      onChanged: (value) => mode.value = value,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160 + scale.scale(160),
                      child: _ThemePreview(
                        theme: previewTheme,
                        name: name.text.trim().isEmpty
                            ? draft.value.name
                            : name.text.trim(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      } finally {
        previewOpen.value = false;
      }
    }

    return PopScope<void>(
      canPop: task.value == null && (!dirty || leaving.value),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(exit());
      },
      child: AppScaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: task.value == null ? () => unawaited(exit()) : null,
          ),
          title: Text(l10n.themeEdit),
          actions: [
            TextButton(
              key: const ValueKey('theme-preview-button'),
              onPressed: task.value == null ? showPreview : null,
              child: Text(l10n.themePreview),
            ),
          ],
          bottom: task.value == null
              ? null
              : const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(),
                ),
        ),
        body: AbsorbPointer(
          absorbing: task.value != null,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: AppListView(
                key: const ValueKey('theme-editor-list'),
                controller: controller,
                padding: const EdgeInsets.symmetric(vertical: 8),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ThemeModeSelector(
                      key: const ValueKey('theme-editor-mode'),
                      mode: mode.value,
                      onChanged: (value) => mode.value = value,
                    ),
                  ),
                  SettingsSection.list(
                    key: const ValueKey('theme-basic-info-section'),
                    title: l10n.themeBasicInfo,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          key: const ValueKey('theme-name'),
                          controller: name,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: l10n.themeName,
                            errorText: nameError.value
                                ? l10n.themeNameRequired
                                : null,
                          ),
                          onChanged: (value) {
                            if (nameError.value) {
                              nameError.value = !_validName(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SettingsSection.list(
                    key: const ValueKey('theme-background-section'),
                    title: l10n.themeBackground,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.themeImageHelp,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  key: const ValueKey('theme-choose-image'),
                                  onPressed: chooseImage,
                                  icon: const Icon(Icons.image_outlined),
                                  label: Text(l10n.themeChooseImage),
                                ),
                                if (variant.backgroundImagePath != null) ...[
                                  TextButton.icon(
                                    key: const ValueKey('theme-remove-image'),
                                    onPressed: () => updateVariant(
                                      (value) => value.copyWith(
                                        clearBackgroundImage: true,
                                        colorSource: 'system',
                                        clearSeedColor: true,
                                      ),
                                    ),
                                    icon: const Icon(Icons.hide_image_outlined),
                                    label: Text(l10n.themeRemoveImage),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      _EditorSlider(
                        id: 'backgroundDim',
                        label: l10n.themeBackgroundDim,
                        value: variant.backgroundDim,
                        onChanged: (value) => updateVariant(
                          (entry) => entry.copyWith(backgroundDim: value),
                        ),
                      ),
                      _EditorSlider(
                        id: 'backgroundBlur',
                        label: l10n.themeBackgroundBlur,
                        value: variant.backgroundBlur,
                        max: 30,
                        onChanged: (value) => updateVariant(
                          (entry) => entry.copyWith(backgroundBlur: value),
                        ),
                      ),
                      _EditorSlider(
                        id: 'surfaceOpacity',
                        label: l10n.themeSurfaceOpacity,
                        value: variant.surfaceOpacity,
                        onChanged: (value) => updateVariant(
                          (entry) => entry.copyWith(surfaceOpacity: value),
                        ),
                      ),
                      _EditorSlider(
                        id: 'cardRadius',
                        label: l10n.themeCardRadius,
                        value: variant.cardRadius,
                        max: 48,
                        onChanged: (value) => updateVariant(
                          (entry) => entry.copyWith(cardRadius: value),
                        ),
                      ),
                      _EditorSlider(
                        id: 'dividerWidth',
                        label: l10n.themeDividerWidth,
                        value: variant.dividerWidth,
                        max: 3,
                        onChanged: (value) => updateVariant(
                          (entry) => entry.copyWith(dividerWidth: value),
                        ),
                      ),
                    ],
                  ),
                  RadioGroup<String>(
                    groupValue: source,
                    onChanged: (value) {
                      if (value == 'image') {
                        unawaited(selectImagePalette());
                      } else if (value != null) {
                        unawaited(selectPalette(value, seed.toARGB32()));
                      }
                    },
                    child: SettingsSection.list(
                      key: const ValueKey('theme-source-section'),
                      title: l10n.themeColorSource,
                      children: [
                        RadioListTile<String>(
                          key: const ValueKey('theme-source-system'),
                          value: 'system',
                          enabled: systemColorsAvailable,
                          title: Text(l10n.themeSourceSystem),
                          subtitle: Text(
                            systemColorsAvailable
                                ? l10n.themeSourceSystemHelp
                                : l10n.themeSourceSystemUnavailable,
                          ),
                        ),
                        if (variant.backgroundImagePath != null)
                          RadioListTile<String>(
                            key: const ValueKey('theme-source-image'),
                            value: 'image',
                            title: Text(l10n.themeSourceImage),
                          ),
                        RadioListTile<String>(
                          key: const ValueKey('theme-source-seed'),
                          value: 'seed',
                          title: Text(l10n.themeSourceSeed),
                        ),
                        if (source == 'seed') ...[
                          SettingsChoiceTile<String>(
                            key: const ValueKey('theme-base-palette'),
                            leading: const Icon(Icons.palette_outlined),
                            title: l10n.themeBasePalette,
                            value: isCustomSeed ? 'custom' : preset,
                            choices: [
                              SettingsChoice(
                                value: 'custom',
                                label: l10n.themeCustomPalette,
                              ),
                              for (final entry in appThemes)
                                SettingsChoice(
                                  value: entry.key,
                                  label: themeName(entry.key, l10n),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == 'custom') {
                                updateVariant(
                                  (entry) =>
                                      entry.copyWith(isSeedColorCustom: true),
                                );
                              } else {
                                final color = appThemes
                                    .firstWhere((entry) => entry.key == value)
                                    .color;
                                unawaited(
                                  selectPalette(
                                    'seed',
                                    color.toARGB32(),
                                    isSeedColorCustom: false,
                                  ),
                                );
                              }
                            },
                          ),
                          if (isCustomSeed)
                            ListTile(
                              key: const ValueKey('theme-seed-color'),
                              leading: _ColorSwatch(color: seed),
                              title: Text(l10n.themeCustomSeed),
                              subtitle: Text(_hex(seed)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: editSeed,
                            ),
                        ],
                      ],
                    ),
                  ),
                  SettingsSection.list(
                    key: const ValueKey('theme-course-section'),
                    title: l10n.themeCourseStyle,
                    children: [
                      SettingsChoiceTile<String>(
                        key: const ValueKey('theme-course-palette'),
                        leading: const Icon(Icons.palette_outlined),
                        title: l10n.themeCoursePalette,
                        value: variant.coursePalette.isEmpty
                            ? variant.coursePaletteKey
                            : _customCoursePalette,
                        choices: [
                          const SettingsChoice(
                            value: CourseColorPalettes.tailwind,
                            label: 'Tailwind',
                          ),
                          const SettingsChoice(
                            value: CourseColorPalettes.fuu,
                            label: 'FUU',
                          ),
                          if (variant.coursePalette.isNotEmpty)
                            SettingsChoice(
                              value: _customCoursePalette,
                              label: l10n.themeCoursePaletteCustom,
                            ),
                        ],
                        onChanged: (value) {
                          if (value != _customCoursePalette) {
                            selectCoursePalette(value);
                          }
                        },
                      ),
                      ExpansionTile(
                        key: const PageStorageKey('theme-course-palette-edit'),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Row(
                          children: [
                            Expanded(child: Text(l10n.themeCoursePaletteEdit)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.themeCoursePaletteCount(
                                  coursePalette.length,
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (var i = 0; i < coursePalette.length; i++)
                                    InputChip(
                                      key: ValueKey(
                                        'theme-course-palette-color-$i',
                                      ),
                                      tooltip: l10n.themeCoursePaletteColor(
                                        i + 1,
                                      ),
                                      label: _ColorSwatch(
                                        color: Color(coursePalette[i]),
                                      ),
                                      onPressed: () =>
                                          editCoursePaletteColor(i),
                                      deleteIcon: const Icon(Icons.remove),
                                      deleteButtonTooltipMessage: l10n
                                          .themeCoursePaletteRemove(i + 1),
                                      onDeleted: coursePalette.length > 1
                                          ? () => removeCoursePaletteColor(i)
                                          : null,
                                    ),
                                  ActionChip(
                                    key: const ValueKey(
                                      'theme-course-palette-add',
                                    ),
                                    avatar: const Icon(Icons.add),
                                    label: Text(l10n.themeCoursePaletteAdd),
                                    onPressed:
                                        coursePalette.length <
                                            CourseColorPalettes.maxColors
                                        ? addCoursePaletteColor
                                        : null,
                                  ),
                                  if (variant.backgroundImagePath != null)
                                    ActionChip(
                                      key: const ValueKey(
                                        'theme-course-palette-from-wallpaper',
                                      ),
                                      avatar: const Icon(
                                        Icons.wallpaper_outlined,
                                      ),
                                      label: Text(
                                        l10n.themeCoursePaletteFromWallpaper,
                                      ),
                                      onPressed: generateCoursePalette,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      _EditorSlider(
                        id: 'courseCardOpacity',
                        label: l10n.themeCourseOpacity,
                        value: variant.courseCardOpacity,
                        onChanged: (value) => updateVariant(
                          (entry) => entry.copyWith(courseCardOpacity: value),
                        ),
                      ),
                      _EditorSlider(
                        id: 'courseCardRadius',
                        label: l10n.themeCourseRadius,
                        value: variant.courseCardRadius,
                        max: 48,
                        onChanged: (value) => updateVariant(
                          (entry) => entry.copyWith(courseCardRadius: value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: FilledButton.icon(
              key: const ValueKey('theme-save'),
              onPressed: task.value == null ? save : null,
              icon: const Icon(Icons.check),
              label: Text(l10n.themeSaveApply),
            ),
          ),
        ),
      ),
    );
  }
}

bool _validName(String value) {
  final trimmed = value.trim();
  return trimmed.isNotEmpty &&
      trimmed.length <= 80 &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(trimmed);
}

bool _sameVariant(ThemeVariant a, ThemeVariant b) =>
    mapEquals(a.colors, b.colors) &&
    a.coursePaletteKey == b.coursePaletteKey &&
    listEquals(a.coursePalette, b.coursePalette) &&
    a.colorSource == b.colorSource &&
    a.seedColor == b.seedColor &&
    a.isSeedColorCustom == b.isSeedColorCustom &&
    a.backgroundImagePath == b.backgroundImagePath &&
    a.backgroundDim == b.backgroundDim &&
    a.backgroundBlur == b.backgroundBlur &&
    a.surfaceOpacity == b.surfaceOpacity &&
    a.courseCardOpacity == b.courseCardOpacity &&
    a.cardRadius == b.cardRadius &&
    a.courseCardRadius == b.courseCardRadius &&
    a.dividerWidth == b.dividerWidth;

Color _extraColor(ThemeData theme, String role) {
  final visuals = theme.extension<ThemeVisuals>();
  final scheme = theme.colorScheme;
  return visuals?.color(role) ??
      switch (role) {
        'courseCard' || 'todayHighlight' => scheme.primaryContainer,
        'courseCardText' || 'onTodayHighlight' => scheme.onPrimaryContainer,
        'courseCardSecondaryText' => scheme.onSurfaceVariant,
        'courseAccent' => scheme.primary,
        _ => scheme.primary,
      };
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

int? _parseColor(String text) {
  final hex = text.trim().replaceFirst(RegExp(r'^#'), '');
  if (!RegExp(r'^(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(hex)) {
    return null;
  }
  return int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
}

class _ColorEdit {
  const _ColorEdit(this.argb);
  final int? argb;
}

class _ColorEditor extends HookWidget {
  const _ColorEditor({required this.role, required this.initialColor});

  final String role;
  final Color initialColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = useState(initialColor);
    final hex = useTextEditingController(text: _hex(initialColor));
    final error = useState(false);
    const channels = [('R', 16), ('G', 8), ('B', 0), ('A', 24)];

    void updateChannel(int shift, double value) {
      color.value = Color(
        (color.value.toARGB32() & ~(0xff << shift)) | (value.round() << shift),
      );
      final text = _hex(color.value);
      hex.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      error.value = false;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(role, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Center(child: _ColorSwatch(color: color.value)),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('theme-color-hex'),
            controller: hex,
            maxLength: 9,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.themeColorHex,
              helperText: l10n.themeColorHexHelp,
              errorText: error.value ? l10n.themeColorInvalid : null,
            ),
            onChanged: (value) {
              final argb = _parseColor(value);
              error.value = argb == null;
              if (argb != null) color.value = Color(argb);
            },
          ),
          for (final (channel, shift) in channels)
            _EditorSlider(
              id: 'channel-$channel',
              label: channel,
              value: ((color.value.toARGB32() >> shift) & 0xff).toDouble(),
              max: 255,
              divisions: 255,
              onChanged: (value) => updateChannel(shift, value),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.learningCancel),
              ),
              TextButton(
                key: const ValueKey('theme-color-reset'),
                onPressed: () =>
                    Navigator.of(context).pop(const _ColorEdit(null)),
                child: Text(l10n.themeResetColor),
              ),
              FilledButton(
                key: const ValueKey('theme-color-confirm'),
                onPressed: () {
                  final argb = _parseColor(hex.text);
                  error.value = argb == null;
                  if (argb != null) {
                    Navigator.of(context).pop(_ColorEdit(argb));
                  }
                },
                child: Text(l10n.learningConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 32,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

class _EditorSlider extends StatelessWidget {
  const _EditorSlider({
    required this.id,
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 1,
    this.divisions,
  });

  final String id, label;
  final double value, max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final display = max == 1
        ? '${(value * 100).round()}%'
        : value.toStringAsFixed(max == 3 ? 1 : 0);
    return ExpansionTile(
      key: PageStorageKey('theme-slider-expansion-$id'),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Row(
        key: ValueKey('theme-slider-row-$id'),
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(display),
        ],
      ),
      children: [
        Slider(
          key: ValueKey('theme-slider-$id'),
          value: value,
          max: max,
          divisions: divisions ?? (max == 1 ? 100 : (max * 10).round()),
          label: display,
          semanticFormatterCallback: (_) => '$label $display',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final Brightness mode;
  final ValueChanged<Brightness> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabels =
            constraints.maxWidth >= MediaQuery.textScalerOf(context).scale(220);
        return SegmentedButton<Brightness>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: Brightness.light,
              icon: const Icon(Icons.light_mode_outlined),
              label: showLabels ? Text(l10n.light) : null,
              tooltip: l10n.light,
            ),
            ButtonSegment(
              value: Brightness.dark,
              icon: const Icon(Icons.dark_mode_outlined),
              label: showLabels ? Text(l10n.dark) : null,
              tooltip: l10n.dark,
            ),
          ],
          selected: {mode},
          onSelectionChanged: (values) => onChanged(values.single),
        );
      },
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme, required this.name});

  final ThemeData theme;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: constraints.biggest,
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          ),
          child: Theme(
            data: theme,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AppThemeBackground(
                key: const ValueKey('theme-editor-preview'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _ColorSwatch(color: theme.colorScheme.primary),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 48),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _extraColor(theme, 'todayHighlight'),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    l10n.monday,
                                    style: TextStyle(
                                      color: _extraColor(
                                        theme,
                                        'onTodayHighlight',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CourseCard(
                                course: Course.fromJson({
                                  'name': l10n.customCourseName,
                                }),
                                location: l10n.customCourseLocation,
                                isHorizontal: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
