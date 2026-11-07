import 'dart:io';
import 'dart:typed_data';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/theme_customization_service.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ThemeCustomizationService store;
  late AppSettings settings;
  var systemAvailable = false;
  const imageSeed = Color(0xffb34731);
  const customSeed = Color(0xff25775a);
  const systemSeed = Color(0xff395cbb);

  ThemeProfile profile({ThemeVariant? light, ThemeVariant? dark}) =>
      ThemeProfile(
        id: 'palette-sources',
        name: '独立亮暗主题',
        baseThemeKey: 'pink',
        light:
            light ??
            ThemeVariant(colorSource: 'image', seedColor: imageSeed.toARGB32()),
        dark:
            dark ??
            ThemeVariant(colorSource: 'seed', seedColor: customSeed.toARGB32()),
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fzu-palette-sources-');
    store = ThemeCustomizationService(directory: () async => directory);
    settings = AppSettings(themeStore: store);
    systemAvailable = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DynamicColorPlugin.channel, (call) async {
          if (systemAvailable && call.method == DynamicColorPlugin.methodName) {
            final palette = SchemeTonalSpot(
              sourceColorHct: Hct.fromInt(systemSeed.toARGB32()),
              isDark: false,
              contrastLevel: 0,
            );
            // Match the locked plugin's five concatenated native palettes.
            return Int64List.fromList([
              ...palette.primaryPalette.asList,
              ...palette.secondaryPalette.asList,
              ...palette.tertiaryPalette.asList,
              ...palette.neutralPalette.asList,
              ...palette.neutralVariantPalette.asList,
            ]);
          }
          return null;
        });
    await settings.initDynamicColor();
    SharedPreferences.setMockInitialValues({});
    await settings.load();
  });

  tearDown(() async {
    systemAvailable = false;
    await settings.initDynamicColor();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DynamicColorPlugin.channel, null);
    settings.dispose();
    await directory.delete(recursive: true);
  });

  test('亮暗独立使用 App 壁纸种子与自选种子，细调覆盖生成配色', () {
    final draft = profile(
      light: ThemeVariant(
        colorSource: 'image',
        seedColor: imageSeed.toARGB32(),
        colors: {'primary': 0xff123456, 'courseCard': 0xff654321},
        courseCardRadius: 20,
      ),
    );
    final light = settings.buildProfileTheme(draft, Brightness.light);
    final dark = settings.buildProfileTheme(draft, Brightness.dark);
    expect(
      light.colorScheme,
      ColorScheme.fromSeed(seedColor: imageSeed)
          .copyWith(primary: const Color(0xff123456)),
    );
    expect(
      dark.colorScheme,
      ColorScheme.fromSeed(seedColor: customSeed, brightness: Brightness.dark),
    );
    expect(
      light.extension<ThemeVisuals>()!.color('courseCard'),
      const Color(0xff654321),
    );
    expect(light.extension<ThemeVisuals>()!.courseCardRadius, 20);
    expect(settings.activeCustomTheme.value, isNull);
  });

  test('手机壁纸来源只影响选定模式，使用现有动态配色接口', () async {
    var changes = 0;
    settings.systemColorRevision.addListener(() => changes++);
    systemAvailable = true;
    await settings.initDynamicColor();
    final draft = profile(
      dark: ThemeVariant(
        colorSource: 'system',
        seedColor: customSeed.toARGB32(),
      ),
    );
    expect(AppSettings.dynamicColorSupported, isTrue);
    expect(changes, 1);
    expect(
      settings.buildProfileTheme(draft, Brightness.dark).colorScheme,
      AppSettings.systemColorScheme(Brightness.dark),
    );
    expect(
      settings.buildProfileTheme(draft, Brightness.light).colorScheme,
      ColorScheme.fromSeed(seedColor: imageSeed),
    );
  });

  test('系统配色失效会清除旧值，分享来的系统主题仍可用备用种子显示', () async {
    systemAvailable = true;
    await settings.initDynamicColor();
    expect(AppSettings.systemColorScheme(Brightness.light), isNotNull);
    systemAvailable = false;
    await settings.initDynamicColor();
    expect(AppSettings.dynamicColorSupported, isFalse);
    expect(AppSettings.systemColorScheme(Brightness.light), isNull);
    expect(AppSettings.systemColorScheme(Brightness.dark), isNull);
    final draft = profile(
      light: ThemeVariant(
        colorSource: 'system',
        seedColor: customSeed.toARGB32(),
      ),
    );
    expect(
      settings.buildProfileTheme(draft, Brightness.light).colorScheme,
      ColorScheme.fromSeed(seedColor: customSeed),
    );
    expect(draft.light.colorSource, 'system');
  });

  test('独立来源和种子跨保存重启与主题包分享保持一致', () async {
    final draft = profile();
    final saved = await settings.saveCustomTheme(draft);
    final restored = AppSettings(
      themeStore: ThemeCustomizationService(directory: () async => directory),
    );
    try {
      await restored.load();
      expect(restored.activeCustomTheme.value!.light.colorSource, 'image');
      expect(restored.activeCustomTheme.value!.dark.colorSource, 'seed');
      expect(restored.lightTheme.colorScheme, settings.lightTheme.colorScheme);
      expect(restored.darkTheme.colorScheme, settings.darkTheme.colorScheme);
      final asset = await store.exportTheme(
        saved,
        destination: File('${directory.path}/shared.fzutheme'),
      );
      final imported = await store.importTheme(asset.file);
      expect(imported.id, isNot(saved.id));
      expect(imported.light.toJson(), saved.light.toJson());
      expect(imported.dark.toJson(), saved.dark.toJson());
      expect(imported.light.toJson()['seedColor'], 'FFB34731');
    } finally {
      restored.dispose();
    }
  });

  test('缺少新增字段的旧主题继续继承原色卡和动态色', () async {
    final legacy = ThemeProfile.fromJson({
      'version': 1,
      'id': 'legacy',
      'name': '旧主题',
      'baseThemeKey': 'pink',
      'light': <String, dynamic>{},
      'dark': <String, dynamic>{},
    });
    expect(legacy.light.colorSource, isNull);
    expect(legacy.light.seedColor, isNull);
    expect(
      settings.buildProfileTheme(legacy, Brightness.light).colorScheme,
      ColorScheme.fromSeed(seedColor: const Color(0xffe91e63)),
    );
    systemAvailable = true;
    await settings.initDynamicColor();
    expect(
      settings
          .buildProfileTheme(
            legacy.copyWith(baseThemeKey: 'dynamic'),
            Brightness.dark,
          )
          .colorScheme,
      AppSettings.systemColorScheme(Brightness.dark),
    );
  });

  test('配色来源及种子严格校验，透明 ARGB 保留且可清除为旧继承方式', () {
    for (final source in ['unknown', '', 0, true]) {
      expect(
        () => ThemeVariant.fromJson({'colorSource': source}),
        throwsFormatException,
      );
    }
    for (final seed in ['123456', '#FF123456', 'GG123456', -1, 0xff123456]) {
      expect(
        () => ThemeVariant.fromJson({'colorSource': 'seed', 'seedColor': seed}),
        throwsFormatException,
      );
    }
    for (final source in ['seed', 'image']) {
      expect(() => ThemeVariant(colorSource: source), throwsFormatException);
    }
    expect(() => ThemeVariant(seedColor: 0x100000000), throwsFormatException);
    final variant = ThemeVariant.fromJson({
      'colorSource': 'seed',
      'seedColor': '00123456',
    });
    expect(variant.seedColor, 0x00123456);
    expect(variant.copyWith().seedColor, variant.seedColor);
    expect(variant.toJson()['seedColor'], '00123456');
    final inherited = variant.copyWith(
      clearColorSource: true,
      clearSeedColor: true,
    );
    expect(inherited.colorSource, isNull);
    expect(inherited.seedColor, isNull);
  });
}
