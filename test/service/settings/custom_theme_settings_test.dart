import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/theme_customization_service.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
  '/x8AAwMCAO+jZ1kAAAAASUVORK5CYII=',
);
final _gif = <int>[
  0x47,
  0x49,
  0x46,
  0x38,
  0x39,
  0x61,
  0x01,
  0x00,
  0x01,
  0x00,
  0x80,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0xff,
  0xff,
  0xff,
  0x2c,
  0x00,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x01,
  0x00,
  0x00,
  0x02,
  0x01,
  0x4c,
  0x00,
  0x3b,
];

ThemeVariant _variant({required bool dark, String? image}) => ThemeVariant(
  colors: {
    for (final (index, key) in ThemeVariant.colorKeys.indexed)
      key: (dark ? 0xffd00000 : 0xff100000) + index * 0x100,
  },
  backgroundImagePath: image,
  backgroundDim: dark ? 0.7 : 0.15,
  courseCardOpacity: dark ? 0.8 : 0.6,
  cardRadius: dark ? 12 : 32,
  courseCardRadius: dark ? 4 : 16,
  dividerWidth: dark ? 2 : 0.5,
  backgroundBlur: dark ? 20 : 6,
  surfaceOpacity: dark ? 0.5 : 0.9,
);

ThemeProfile _profile({
  String id = 'sample',
  String name = '自定义主题',
  String baseThemeKey = 'teal',
  String? lightImage,
  String? darkImage,
}) => ThemeProfile(
  id: id,
  name: name,
  baseThemeKey: baseThemeKey,
  light: _variant(dark: false, image: lightImage),
  dark: _variant(dark: true, image: darkImage),
);

void _expectVariant(
  ThemeData actual,
  ThemeVariant expected,
  Brightness brightness,
  InterfaceStyle style,
) {
  expect(actual.brightness, brightness);
  expect(actual.extension<InterfaceTheme>()!.style, style);
  final schemeColors = ThemeColors.fromScheme(actual.colorScheme);
  for (final entry in expected.colors.entries) {
    if (schemeColors.containsKey(entry.key)) {
      expect(
        schemeColors[entry.key],
        Color(entry.value),
        reason: '$brightness ${entry.key}',
      );
    }
  }
  final visuals = actual.extension<ThemeVisuals>()!;
  expect(visuals.colors, {
    for (final entry in expected.colors.entries) entry.key: Color(entry.value),
  });
  expect(visuals.backgroundImage, expected.backgroundImagePath);
  expect(visuals.backgroundDim, expected.backgroundDim);
  expect(visuals.backgroundBlur, expected.backgroundBlur);
  expect(visuals.surfaceOpacity, expected.surfaceOpacity);
  expect(visuals.courseCardOpacity, expected.courseCardOpacity);
  expect(visuals.cardRadius, expected.cardRadius);
  expect(visuals.courseCardRadius, expected.courseCardRadius);
  expect(visuals.dividerWidth, expected.dividerWidth);
  expect(actual.dividerTheme.color, Color(expected.colors['divider']!));
  expect(actual.dividerTheme.thickness, expected.dividerWidth);
  final shape = actual.cardTheme.shape! as RoundedRectangleBorder;
  expect(
    shape.borderRadius.resolve(TextDirection.ltr),
    BorderRadius.circular(style.isCard ? expected.cardRadius : 0),
  );
  if (expected.backgroundImagePath != null) {
    expect(actual.scaffoldBackgroundColor, Colors.transparent);
    expect(
      actual.cardTheme.color,
      Color(
        expected.colors[brightness == Brightness.dark
            ? 'surfaceContainerHigh'
            : 'surfaceContainerLow']!,
      ).withValues(alpha: expected.surfaceOpacity),
    );
  }
}

void _expectPreset(
  AppSettings settings,
  String key, {
  InterfaceStyle style = InterfaceStyle.cards,
  String mode = 'dark',
}) {
  expect(settings.activeCustomTheme.value, isNull);
  expect(settings.themeKey.value, key);
  expect(settings.themeModeKey.value, mode);
  expect(settings.interfaceStyle.value, style);
  final seed = appThemes.singleWhere((theme) => theme.key == key).color;
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light
        ? settings.lightTheme
        : settings.darkTheme;
    expect(
      theme.colorScheme,
      ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    );
    expect(theme.extension<InterfaceTheme>()!.style, style);
    expect(theme.extension<ThemeVisuals>(), isNull);
  }
}

/// Only used to control read completion. Saving and picture tests use real IO.
class _ControlledReads extends ThemeCustomizationService {
  _ControlledReads({this.readProfile, this.readProfiles})
    : super(
        directory: () async =>
            throw StateError('Controlled reads must not resolve a directory'),
      );

  final Future<ThemeProfile?> Function(String id)? readProfile;
  final Future<List<ThemeProfile>> Function()? readProfiles;
  final loadStarted = Completer<void>();
  var loadCalls = 0;
  var loadAllCalls = 0;

  @override
  Future<ThemeProfile?> load(String id) {
    loadCalls++;
    if (!loadStarted.isCompleted) loadStarted.complete();
    return readProfile?.call(id) ?? Future.value(null);
  }

  @override
  Future<List<ThemeProfile>> loadAll() {
    loadAllCalls++;
    return readProfiles?.call() ?? Future.value(const []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory documents;
  late ThemeCustomizationService store;
  late List<AppSettings> instances;

  AppSettings createSettings([ThemeCustomizationService? themeStore]) {
    final settings = AppSettings(themeStore: themeStore ?? store);
    instances.add(settings);
    return settings;
  }

  void disposeSettings(AppSettings settings) {
    instances.remove(settings);
    settings.dispose();
  }

  Future<AppSettings> restart({Directory? appDirectory}) async {
    // Drop the plugin's frontend cache as well as AppSettings and themeStore.
    // Retain only the mock platform's persisted values and real theme files.
    await Future<void>.delayed(Duration.zero);
    SharedPreferences.resetStatic();
    final fresh = createSettings(
      ThemeCustomizationService(
        directory: () async => appDirectory ?? documents,
      ),
    );
    await fresh.load();
    return fresh;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fzu-theme-settings-');
    documents = Directory('${directory.path}/app-documents');
    store = ThemeCustomizationService(directory: () async => documents);
    instances = [];
    SharedPreferences.setMockInitialValues({
      SpKeys.themeKey: 'blue',
      SpKeys.themeMode: 'dark',
      SpKeys.interfaceStyle: 'cards',
    });
  });

  tearDown(() async {
    for (final settings in instances.reversed) {
      settings.dispose();
    }
    await directory.delete(recursive: true);
  });

  test('亮暗颜色和视觉参数独立应用并从真实主题文件重启恢复', () async {
    final settings = createSettings();
    await settings.load();
    expect(settings.themeStore, same(store));
    final original = _profile();
    final saved = await settings.saveCustomTheme(original);
    expect(settings.activeCustomTheme.value!.id, saved.id);
    expect(settings.themeKey.value, 'blue');
    expect(settings.themeModeKey.value, 'dark');
    expect(settings.currentThemeMode, ThemeMode.dark);
    _expectVariant(
      settings.lightTheme,
      original.light,
      Brightness.light,
      InterfaceStyle.cards,
    );
    _expectVariant(
      settings.darkTheme,
      original.dark,
      Brightness.dark,
      InterfaceStyle.cards,
    );
    final root = await store.ensureDirectory();
    expect(await File('${root.path}/${saved.id}.json').exists(), isTrue);
    disposeSettings(settings);

    final fresh = await restart();
    expect(fresh.activeCustomTheme.value!.toJson(), original.toJson());
    expect(fresh.customThemes.value, isEmpty, reason: '启动只加载活动项，列表按需加载');
    expect(fresh.customThemeError.value, isNull);
    expect(fresh.themeKey.value, 'blue');
    expect(fresh.themeModeKey.value, 'dark');
    expect(fresh.currentThemeMode, ThemeMode.dark);
    _expectVariant(
      fresh.lightTheme,
      original.light,
      Brightness.light,
      InterfaceStyle.cards,
    );
    _expectVariant(
      fresh.darkTheme,
      original.dark,
      Brightness.dark,
      InterfaceStyle.cards,
    );
    await fresh.loadCustomThemes();
    expect(fresh.customThemes.value.single.id, saved.id);
  });

  test('buildProfileTheme 预览保持当前选择，未覆盖颜色继承其基础色卡', () async {
    var directoryCalls = 0;
    final noIO = ThemeCustomizationService(
      directory: () async {
        directoryCalls++;
        throw StateError('预览不应执行文件 IO');
      },
    );
    final settings = createSettings(noIO);
    await settings.load();
    final preview = ThemeProfile(
      id: 'preview',
      name: '预览',
      baseThemeKey: 'green',
      light: ThemeVariant(colors: {'primary': 0xff123456}),
      dark: ThemeVariant(colors: {'primary': 0xffaabbcc}),
    );
    for (final style in InterfaceStyle.values) {
      settings.interfaceStyle.value = style;
      for (final brightness in Brightness.values) {
        final theme = settings.buildProfileTheme(preview, brightness);
        final base = ColorScheme.fromSeed(
          seedColor: appThemes.singleWhere((t) => t.key == 'green').color,
          brightness: brightness,
        );
        expect(
          theme.colorScheme.primary,
          Color(brightness == Brightness.light ? 0xff123456 : 0xffaabbcc),
        );
        expect(theme.colorScheme.onPrimary, base.onPrimary);
        expect(theme.colorScheme.surface, base.surface);
        expect(theme.extension<InterfaceTheme>()!.style, style);
      }
    }
    expect(settings.activeCustomTheme.value, isNull);
    expect(settings.themeKey.value, 'blue');
    expect(settings.themeModeKey.value, 'dark');
    expect(directoryCalls, 0);
  });

  test('未启用自定义主题时，启动、预设切换和主题构建均不访问主题文件', () async {
    var directoryCalls = 0;
    final noIO = ThemeCustomizationService(
      directory: () async {
        directoryCalls++;
        throw StateError('主题目录不可访问');
      },
    );
    final settings = createSettings(noIO);
    await settings.load();
    _expectPreset(settings, 'blue');
    settings.selectPresetTheme('pink');
    _expectPreset(settings, 'pink');
    settings.selectPresetTheme('dynamic');
    expect(settings.lightTheme.brightness, Brightness.light);
    expect(settings.darkTheme.brightness, Brightness.dark);
    settings.selectPresetTheme('teal');
    expect(directoryCalls, 0);
    expect(settings.customThemeError.value, isNull);
    expect(await documents.exists(), isFalse);
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        SpKeys.activeCustomTheme,
      ),
      isFalse,
    );
  });

  test('selectPresetTheme 清除自定义选择并在重启后恢复预设', () async {
    final settings = createSettings();
    await settings.load();
    final saved = await settings.saveCustomTheme(_profile());
    settings.selectPresetTheme('orange');
    _expectPreset(settings, 'orange');
    expect(settings.customThemes.value.single.id, saved.id);
    expect(await store.load(saved.id), isNotNull);
    disposeSettings(settings);
    final fresh = await restart();
    _expectPreset(fresh, 'orange');
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        SpKeys.activeCustomTheme,
      ),
      isFalse,
    );
  });

  test('删除非活动主题不改选择，删除活动主题回到原预设并持久化', () async {
    final settings = createSettings();
    await settings.load();
    final active = await settings.saveCustomTheme(_profile(id: 'active'));
    await settings.saveCustomTheme(_profile(id: 'inactive'), apply: false);
    await settings.deleteCustomTheme('inactive');
    expect(settings.activeCustomTheme.value!.id, active.id);
    expect(settings.customThemes.value.single.id, active.id);
    await settings.deleteCustomTheme(active.id);
    _expectPreset(settings, 'blue');
    expect(settings.customThemes.value, isEmpty);
    expect(await store.load(active.id), isNull);
    disposeSettings(settings);
    _expectPreset(await restart(), 'blue');
  });

  test('apply=false 保留选择，编辑活动主题仍更新当前外观且不重复列表', () async {
    final settings = createSettings();
    await settings.load();
    final saved = await settings.saveCustomTheme(
      _profile(id: 'draft'),
      apply: false,
    );
    _expectPreset(settings, 'blue');
    settings.activateCustomTheme(saved);
    final edited = saved.copyWith(
      name: '已编辑',
      light: saved.light.copyWith(colors: {'primary': 0xff008877}),
    );
    await settings.saveCustomTheme(edited, apply: false);
    expect(settings.lightTheme.colorScheme.primary, const Color(0xff008877));
    expect(
      settings.darkTheme.colorScheme.primary,
      Color(saved.dark.colors['primary']!),
    );
    expect(settings.customThemes.value.single.name, '已编辑');
    final fresh = await restart();
    expect(fresh.activeCustomTheme.value!.name, '已编辑');
    expect(fresh.lightTheme.colorScheme.primary, const Color(0xff008877));
  });

  for (final fault in [
    'missing',
    'broken-json',
    'missing-picture',
    'unsafe-id',
  ]) {
    test('活动主题 $fault 安全回退，保留风格、亮暗模式和预设', () async {
      final activeId = fault == 'unsafe-id' ? '../outside' : 'active';
      if (fault == 'broken-json') {
        await store.save(_profile(id: activeId));
        final root = await store.ensureDirectory();
        await File('${root.path}/$activeId.json').writeAsString('{"version":');
      } else if (fault == 'missing-picture') {
        final image = await store.importBackgroundImage(
          await File('${directory.path}/picked.png').writeAsBytes(_png),
        );
        await store.save(_profile(id: activeId, lightImage: image));
        await File(image).delete();
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(SpKeys.activeCustomTheme, activeId);
      final settings = createSettings();
      await settings.load();
      _expectPreset(settings, 'blue');
      if (fault != 'missing') {
        expect(settings.customThemeError.value, isNotNull);
      }
      disposeSettings(settings);
      _expectPreset(await restart(), 'blue');
    });
  }

  for (final mode in ['system', 'light', 'dark']) {
    test('切换和编辑主题不改变 $mode 模式或经典列表偏好', () async {
      SharedPreferences.setMockInitialValues({
        SpKeys.themeKey: 'indigo',
        SpKeys.themeMode: mode,
        SpKeys.interfaceStyle: 'classic',
      });
      final settings = createSettings();
      await settings.load();
      final saved = await settings.saveCustomTheme(_profile());
      _expectVariant(
        settings.lightTheme,
        saved.light,
        Brightness.light,
        InterfaceStyle.classic,
      );
      _expectVariant(
        settings.darkTheme,
        saved.dark,
        Brightness.dark,
        InterfaceStyle.classic,
      );
      await settings.saveCustomTheme(saved.copyWith(name: '重命名'));
      expect(settings.themeModeKey.value, mode);
      expect(settings.currentThemeMode.name, mode);
      expect(settings.interfaceStyle.value, InterfaceStyle.classic);
      settings.selectPresetTheme('brown');
      disposeSettings(settings);
      _expectPreset(
        await restart(),
        'brown',
        style: InterfaceStyle.classic,
        mode: mode,
      );
    });
  }

  test('后台加载列表合并重复请求，错误保留活动主题并允许重试', () async {
    final result = Completer<List<ThemeProfile>>();
    var fail = false;
    final reads = _ControlledReads(
      readProfiles: () => fail
          ? Future.error(const FormatException('bad profile'))
          : result.future,
    );
    final settings = createSettings(reads);
    await settings.load();
    final active = _profile();
    settings.activateCustomTheme(active);
    final first = settings.loadCustomThemes();
    final second = settings.loadCustomThemes();
    expect(first, same(second));
    expect(reads.loadAllCalls, 1);
    result.complete(List.unmodifiable([active]));
    await Future.wait([first, second]);
    final before = settings.customThemes.value;
    fail = true;
    await settings.loadCustomThemes();
    expect(reads.loadAllCalls, 2);
    expect(settings.customThemeError.value, contains('bad profile'));
    expect(settings.customThemes.value, same(before));
    expect(settings.activeCustomTheme.value, same(active));
    fail = false;
    await settings.loadCustomThemes();
    expect(reads.loadAllCalls, 3);
    expect(settings.customThemeError.value, isNull);
  });

  test('坏文件导致 loadAll 失败时不替换已有列表或活动主题，移除后可恢复', () async {
    final good = await store.save(_profile(id: 'good', name: '正常主题'));
    await store.save(_profile(id: 'bad', name: '损坏主题'));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(SpKeys.activeCustomTheme, good.id);
    final settings = createSettings();
    await settings.load();
    await settings.loadCustomThemes();
    expect(settings.customThemes.value, hasLength(2));
    final root = await store.ensureDirectory();
    await File('${root.path}/bad.json').writeAsString('{');
    await settings.loadCustomThemes();
    expect(
      settings.customThemes.value.map((profile) => profile.id),
      contains(good.id),
      reason: '读取失败可保留旧列表，逐项隔离坏文件也应保留正常主题',
    );
    expect(settings.activeCustomTheme.value!.id, good.id);
    await store.delete('bad');
    await settings.loadCustomThemes();
    expect(settings.customThemes.value.single.id, good.id);
    expect(settings.customThemeError.value, isNull);
  });

  test('图片真实复制和分享包跨应用目录导入，不依赖原文件并可恢复活动主题', () async {
    final source = createSettings();
    await source.load();
    final chosenLight = await File('${directory.path}/chosen.png')
        .writeAsBytes(_png);
    final chosenDark = await File('${directory.path}/chosen.gif')
        .writeAsBytes(_gif);
    final light = await store.importBackgroundImage(chosenLight);
    final dark = await store.importBackgroundImage(chosenDark);
    final saved = await source.saveCustomTheme(
      _profile(lightImage: light, darkImage: dark),
    );
    final shared = await store.exportTheme(
      saved,
      destination: File('${directory.path}/share/theme.fzutheme'),
    );
    await chosenLight.delete();
    await chosenDark.delete();
    disposeSettings(source);
    final importedDirectory = Directory(
      '${directory.path}/other-app-documents',
    );
    final importedStore = ThemeCustomizationService(
      directory: () async => importedDirectory,
    );
    SharedPreferences.setMockInitialValues({
      SpKeys.themeKey: 'blue',
      SpKeys.themeMode: 'dark',
      SpKeys.interfaceStyle: 'cards',
    });
    final target = createSettings(importedStore);
    await target.load();
    final imported = await target.importCustomTheme(shared.file);
    expect(imported.id, isNot(saved.id));
    expect(target.customThemes.value.single.id, imported.id);
    _expectPreset(target, 'blue');
    final targetRoot = await importedStore.ensureDirectory();
    for (final (path, bytes) in [
      (imported.light.backgroundImagePath!, _png),
      (imported.dark.backgroundImagePath!, _gif),
    ]) {
      expect(File(path).isAbsolute, isTrue);
      expect(path, startsWith(targetRoot.path));
      expect(await File(path).readAsBytes(), bytes);
    }
    await store.delete(saved.id);
    target.activateCustomTheme(imported);
    _expectVariant(
      target.lightTheme,
      imported.light,
      Brightness.light,
      InterfaceStyle.cards,
    );
    _expectVariant(
      target.darkTheme,
      imported.dark,
      Brightness.dark,
      InterfaceStyle.cards,
    );
    disposeSettings(target);
    final fresh = await restart(appDirectory: importedDirectory);
    expect(fresh.activeCustomTheme.value!.id, imported.id);
    _expectVariant(
      fresh.lightTheme,
      imported.light,
      Brightness.light,
      InterfaceStyle.cards,
    );
    _expectVariant(
      fresh.darkTheme,
      imported.dark,
      Brightness.dark,
      InterfaceStyle.cards,
    );
  });

  test('保存或导入失败不激活半成品、不污染已保存主题列表', () async {
    final settings = createSettings();
    await settings.load();
    final saved = await settings.saveCustomTheme(_profile());
    final before = settings.customThemes.value;
    await expectLater(
      settings.saveCustomTheme(
        saved.copyWith(
          light: saved.light.copyWith(
            backgroundImagePath: '${directory.path}/outside.png',
          ),
        ),
      ),
      throwsFormatException,
    );
    final broken = await File('${directory.path}/bad-theme.json')
        .writeAsString('{');
    await expectLater(
      settings.importCustomTheme(broken),
      throwsFormatException,
    );
    expect(settings.customThemes.value, same(before));
    expect(settings.activeCustomTheme.value, same(saved));
    expect((await store.load(saved.id))!.toJson(), saved.toJson());
  });

  test('disposed 后完成的列表加载不会通知已销毁的 notifiers', () async {
    final pending = Completer<List<ThemeProfile>>();
    final settings = createSettings(
      _ControlledReads(readProfiles: () => pending.future),
    );
    await settings.load();
    final loading = settings.loadCustomThemes();
    disposeSettings(settings);
    pending.complete([_profile()]);
    await expectLater(loading, completes);
  });

  test('回归：在途保存完成不能覆盖用户随后选中的预设', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final delayed = ThemeCustomizationService(
      directory: () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        return documents;
      },
    );
    final settings = createSettings(delayed);
    await settings.load();
    final saving = settings.saveCustomTheme(_profile());
    await entered.future;
    settings.selectPresetTheme('green');
    release.complete();
    final saved = await saving;
    expect(await delayed.load(saved.id), isNotNull, reason: '主题仍应正常保存');
    expect(settings.customThemes.value.single.id, saved.id);
    _expectPreset(settings, 'green');
    disposeSettings(settings);
    _expectPreset(await restart(), 'green');
  });

  test('回归：disposed 后完成的启动主题恢复不能写入已销毁的 notifiers', () async {
    final pending = Completer<ThemeProfile?>();
    final reads = _ControlledReads(readProfile: (_) => pending.future);
    await (await SharedPreferences.getInstance()).setString(
      SpKeys.activeCustomTheme,
      'sample',
    );
    final settings = createSettings(reads);
    final loading = settings.load();
    await reads.loadStarted.future;
    disposeSettings(settings);
    final assertion = expectLater(loading, completes);
    pending.complete(_profile());
    await assertion;
  });
}
