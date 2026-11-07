import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/course_color_palettes.dart';
import 'package:fzu_assistant/service/theme_customization_service.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';
import 'package:image/image.dart' as image;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
  '/x8AAwMCAO+jZ1kAAAAASUVORK5CYII=',
);

ThemeProfile _profile({
  String id = 'sample',
  String name = '我的主题',
  ThemeVariant? light,
  ThemeVariant? dark,
}) => ThemeProfile(
  id: id,
  name: name,
  light: light ?? ThemeVariant(colors: {'primary': 0xff123456}),
  dark: dark ?? ThemeVariant(colors: {'primary': 0xffabcdef}),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory documents;
  late ThemeCustomizationService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fzu-themes-test-');
    documents = Directory('${directory.path}/documents');
    service = ThemeCustomizationService(directory: () async => documents);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<File> jsonFile(Map<String, dynamic> json) async =>
      File('${directory.path}/theme.json').writeAsString(jsonEncode(json));

  Future<File> zipFile(Archive archive) async =>
      File('${directory.path}/theme.zip')
          .writeAsBytes(ZipEncoder().encode(archive));

  test('亮暗课程色卡及 DIY 完整保存、分享并导入，旧主题沿用 Tailwind', () async {
    final lightColors = [
      ...CourseColorPalettes.colors(CourseColorPalettes.fuu, dark: false),
    ]..[0] = 0x80123456;
    final profile = _profile(
      light: ThemeVariant(
        coursePaletteKey: CourseColorPalettes.fuu,
        coursePalette: lightColors,
      ),
      dark: ThemeVariant(coursePalette: [0xff112233, 0x80556677]),
    );
    await service.save(profile);
    lightColors[0] = 0;
    final saved = (await service.load(profile.id))!;
    expect(saved.light.coursePalette[0], 0x80123456);
    expect(saved.dark.coursePalette, [0xff112233, 0x80556677]);
    expect(() => saved.light.coursePalette.clear(), throwsUnsupportedError);
    final exported = await service.exportTheme(
      saved,
      destination: File('${directory.path}/palette.fzutheme'),
    );
    final imported = await service.importTheme(exported.file);
    expect(imported.id, isNot(saved.id));
    expect(imported.light.toJson(), saved.light.toJson());
    expect(imported.dark.toJson(), saved.dark.toJson());
    final legacy = ThemeVariant.fromJson({});
    expect(legacy.coursePaletteKey, CourseColorPalettes.tailwind);
    expect(legacy.coursePalette, isEmpty);
  });

  test('导入拒绝未知色卡、超长或非法 DIY 颜色，保留已保存主题', () async {
    final original = await service.save(_profile());
    for (final malformed in [
      {'coursePaletteKey': 'unknown'},
      {'coursePaletteKey': 10},
      {'coursePalette': 'FF123456'},
      {'coursePalette': List.filled(65, 'FF123456')},
      {
        'coursePalette': ['#FF123456'],
      },
      {
        'coursePalette': [0xff123456],
      },
      {
        'coursePalette': ['123456'],
      },
    ]) {
      final json = original.toJson();
      json['light'] = malformed;
      await expectLater(
        service.importTheme(await jsonFile(json)),
        throwsFormatException,
      );
      expect((await service.load(original.id))!.toJson(), original.toJson());
      expect((await service.loadAll()).length, 1);
    }
  });

  test('颜色键覆盖全部 ColorScheme 和课表专用角色', () {
    for (final brightness in Brightness.values) {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: brightness,
      );
      final colors = {
        for (final entry in ThemeColors.fromScheme(scheme).entries)
          entry.key: entry.value.toARGB32(),
        'highlight': 0xff123456,
        'courseCard': 0xff123456,
        'courseCardText': 0xff123456,
        'courseCardSecondaryText': 0xff123456,
        'courseAccent': 0xff123456,
        'divider': 0xff123456,
        'todayHighlight': 0xff123456,
        'onTodayHighlight': 0xff123456,
      };
      final variant = ThemeVariant(colors: colors);
      expect(ThemeVariant.fromJson(variant.toJson()).colors, colors);
      expect(ThemeVariant.colorKeys, containsAll(colors.keys));
    }
  });

  test('亮暗配色和所有附加参数独立保存，颜色序列化为 8 位 ARGB', () async {
    final colors = {for (final key in ThemeVariant.colorKeys) key: 0x80123456};
    final profile = _profile(
      light: ThemeVariant(
        colors: colors,
        colorSource: 'seed',
        seedColor: Colors.deepPurple.toARGB32(),
        isSeedColorCustom: true,
        backgroundDim: 0.25,
        courseCardOpacity: 0.6,
        cardRadius: 36,
        courseCardRadius: 4,
        dividerWidth: 2,
        backgroundBlur: 12,
        surfaceOpacity: 0.8,
      ),
      dark: ThemeVariant(
        colors: {'primary': 0x00000000, 'onTodayHighlight': 0xffffffff},
        colorSource: 'seed',
        seedColor: Colors.deepPurple.toARGB32(),
        backgroundDim: 0.75,
        courseCardOpacity: 0.9,
        cardRadius: 12,
        courseCardRadius: 16,
        dividerWidth: 0,
        backgroundBlur: 25,
        surfaceOpacity: 0.4,
      ),
    );
    await service.save(profile);
    final root = await service.ensureDirectory();
    expect(root.path, endsWith('fzu-themes'));
    expect(await Directory('${root.path}/images').exists(), isTrue);
    final json = jsonDecode(
      await File('${root.path}/sample.json').readAsString(),
    ) as Map;
    expect((json['light'] as Map)['colors']['courseCard'], '80123456');
    expect((json['dark'] as Map)['colors']['primary'], '00000000');
    expect((json['dark'] as Map)['colors']['onTodayHighlight'], 'FFFFFFFF');
    expect((json['light'] as Map)['isSeedColorCustom'], isTrue);
    expect((json['dark'] as Map).containsKey('isSeedColorCustom'), isFalse);
    final reload = ThemeCustomizationService(directory: () async => documents);
    final loaded = (await reload.load('sample'))!;
    expect(loaded.toJson(), profile.toJson());
    expect(loaded.light.seedColor, loaded.dark.seedColor);
    expect(loaded.light.isSeedColorCustom, isTrue);
    expect(loaded.dark.isSeedColorCustom, isFalse);
    expect((await reload.loadAll()).single.id, 'sample');
    expect(await reload.load('missing'), isNull);
    expect(() => profile.light.colors.clear(), throwsUnsupportedError);
    colors['primary'] = 0;
    expect(profile.light.colors['primary'], 0x80123456);
  });

  test('数值默认值、复制、清除图片和基础色卡均保留', () {
    final variant = ThemeVariant(backgroundImagePath: 'images/example.png');
    expect(variant.backgroundDim, 0);
    expect(variant.courseCardOpacity, 1);
    expect(variant.cardRadius, 24);
    expect(variant.courseCardRadius, 8);
    expect(variant.dividerWidth, 1);
    expect(variant.backgroundBlur, 0);
    expect(variant.surfaceOpacity, 0.9);
    expect(variant.isSeedColorCustom, isFalse);
    expect(variant.toJson().containsKey('isSeedColorCustom'), isFalse);
    expect(ThemeVariant.fromJson({}).isSeedColorCustom, isFalse);
    expect(
      ThemeVariant.fromJson({'isSeedColorCustom': false}).toJson(),
      ThemeVariant().toJson(),
    );
    expect(variant.copyWith().backgroundImagePath, variant.backgroundImagePath);
    expect(
      variant.copyWith(clearBackgroundImage: true).backgroundImagePath,
      isNull,
    );
    expect(
      _profile().copyWith(baseThemeKey: 'dynamic').baseThemeKey,
      'dynamic',
    );
    final minimal = _profile().toJson();
    minimal['light'] = <String, dynamic>{};
    expect(
      ThemeProfile.fromJson(minimal).light.toJson(),
      ThemeVariant().toJson(),
    );
  });

  test('自定义种子色标记可独立复制与清除，同色内置预设不丢失显式选择', () {
    final preset = ThemeVariant(
      colorSource: 'seed',
      seedColor: Colors.deepPurple.toARGB32(),
    );
    final custom = preset.copyWith(isSeedColorCustom: true);
    expect(preset.isSeedColorCustom, isFalse);
    expect(custom.seedColor, preset.seedColor);
    expect(custom.copyWith().isSeedColorCustom, isTrue);
    expect(custom.copyWith(backgroundDim: 0.5).isSeedColorCustom, isTrue);
    expect(ThemeVariant.fromJson(custom.toJson()).isSeedColorCustom, isTrue);
    expect(custom.copyWith(isSeedColorCustom: false).toJson(), preset.toJson());

    final profile = _profile(light: custom, dark: preset);
    final changed = profile.copyWith(
      dark: profile.dark.copyWith(isSeedColorCustom: true),
    );
    expect(profile.dark.isSeedColorCustom, isFalse);
    expect(changed.light.toJson(), profile.light.toJson());
    expect(changed.dark.isSeedColorCustom, isTrue);
    expect(
      changed
          .copyWith(light: changed.light.copyWith(isSeedColorCustom: false))
          .dark
          .isSeedColorCustom,
      isTrue,
    );
  });

  test('自定义种子色标记拒绝所有非布尔输入且不改变已有主题', () async {
    final original = await service.save(_profile());
    for (final invalid in [null, 0, 1, 1.0, 'true', [], {}]) {
      expect(
        () => ThemeVariant.fromJson({'isSeedColorCustom': invalid}),
        throwsFormatException,
        reason: 'isSeedColorCustom=$invalid',
      );
      for (final mode in ['light', 'dark']) {
        final json = original.toJson();
        (json[mode] as Map)['isSeedColorCustom'] = invalid;
        await expectLater(
          service.importTheme(await jsonFile(json)),
          throwsFormatException,
        );
      }
    }
    expect((await service.load(original.id))!.toJson(), original.toJson());
    expect((await service.loadAll()).length, 1);
  });

  test('保存编辑和并发操作不会覆盖其他主题，失败后队列仍可使用', () async {
    await Future.wait([
      service.save(_profile(id: 'one', name: 'A')),
      service.save(_profile(id: 'two', name: 'B')),
    ]);
    await expectLater(
      service.save(
        _profile(
          light: ThemeVariant(
            backgroundImagePath: '${directory.path}/outside.png',
          ),
        ),
      ),
      throwsFormatException,
    );
    await service.save(_profile(id: 'one', name: '编辑后'));
    expect((await service.load('one'))!.name, '编辑后');
    expect((await service.load('two'))!.name, 'B');
    await service.delete('one');
    await service.delete('missing');
    expect((await service.loadAll()).single.id, 'two');
  });

  test('用户选择的图片复制为安全文件名，JSON 只包含相对路径', () async {
    final source = await File('${directory.path}/任意图片名称.png')
        .writeAsBytes(_png);
    final image = await service.importBackgroundImage(source);
    final root = await service.ensureDirectory();
    expect(image, startsWith(root.path));
    expect(image.replaceAll('\\', '/'), matches(r'/images/[a-f0-9]{64}\.png$'));
    expect(await service.importBackgroundImage(source), image);
    final saved = await service.save(
      _profile(light: ThemeVariant(backgroundImagePath: image)),
    );
    expect(saved.light.backgroundImagePath, image);
    final json = jsonDecode(
      await File('${root.path}/sample.json').readAsString(),
    ) as Map;
    expect(
      (json['light'] as Map)['backgroundImagePath'],
      startsWith('images/'),
    );
    expect(jsonEncode(json), isNot(contains(root.path)));
    await source.delete();
    expect(
      await File((await service.load('sample'))!.light.backgroundImagePath!)
          .readAsBytes(),
      _png,
    );
  });

  test('主题删除只回收未被其他主题使用的生成图片', () async {
    final source = await File('${directory.path}/picked.png')
        .writeAsBytes(_png);
    final image = await service.importBackgroundImage(source);
    for (final id in ['one', 'two']) {
      await service.save(
        _profile(
          id: id,
          light: ThemeVariant(backgroundImagePath: image),
        ),
      );
    }
    await service.delete('one');
    expect(await File(image).exists(), isTrue);
    expect((await service.load('two'))!.light.backgroundImagePath, image);
    await service.delete('two');
    expect(await File(image).exists(), isFalse);
    expect(await source.readAsBytes(), _png);
  });

  test('ZIP 导出到指定文件，亮暗图片去重且跨目录完整导入', () async {
    final source = await File('${directory.path}/picked.png')
        .writeAsBytes(_png);
    final image = await service.importBackgroundImage(source);
    final original = await service.save(
      _profile(
        light: ThemeVariant(
          backgroundImagePath: image,
          backgroundDim: 0.2,
          colorSource: 'seed',
          seedColor: Colors.deepPurple.toARGB32(),
          isSeedColorCustom: true,
        ),
        dark: ThemeVariant(backgroundImagePath: image, backgroundDim: 0.8),
      ),
    );
    final destination = File('${directory.path}/share/自定义主题.fzutheme');
    final asset = await service.exportTheme(original, destination: destination);
    expect(
      await FileSystemEntity.identical(asset.file.path, destination.path),
      isTrue,
    );
    expect(asset.mimeType, 'application/zip');
    expect(asset.name, '自定义主题.fzutheme');
    final archive = ZipDecoder().decodeBytes(await asset.file.readAsBytes());
    expect(archive, hasLength(2));
    final manifest =
        jsonDecode(utf8.decode(archive.findFile('theme.json')!.content)) as Map;
    expect(
      (manifest['light'] as Map)['backgroundImagePath'],
      startsWith('images/'),
    );
    expect(
      (manifest['dark'] as Map)['backgroundImagePath'],
      (manifest['light'] as Map)['backgroundImagePath'],
    );
    expect((manifest['light'] as Map)['isSeedColorCustom'], isTrue);
    expect((manifest['dark'] as Map).containsKey('isSeedColorCustom'), isFalse);
    final other = ThemeCustomizationService(
      directory: () async => Directory('${directory.path}/other-app'),
    );
    final imported = await other.importTheme(destination);
    expect(imported.id, isNot(original.id));
    expect(imported.name, original.name);
    expect(imported.baseThemeKey, original.baseThemeKey);
    expect(imported.light.backgroundDim, 0.2);
    expect(imported.dark.backgroundDim, 0.8);
    expect(imported.light.seedColor, Colors.deepPurple.toARGB32());
    expect(imported.light.isSeedColorCustom, isTrue);
    expect(imported.dark.isSeedColorCustom, isFalse);
    expect(
      imported.light.backgroundImagePath,
      imported.dark.backgroundImagePath,
    );
    expect(await File(imported.light.backgroundImagePath!).readAsBytes(), _png);
    expect((await other.load(imported.id))!.toJson(), imported.toJson());
  });

  test('无图片主题可分享；重复导入不覆盖现有 ID', () async {
    final profile = _profile(
      dark: ThemeVariant(
        colorSource: 'seed',
        seedColor: Colors.deepPurple.toARGB32(),
        isSeedColorCustom: true,
      ),
    );
    await service.save(profile);
    final asset = await service.exportTheme(
      profile,
      destination: File('${directory.path}/plain.zip'),
    );
    final first = await service.importTheme(asset.file);
    final second = await service.importTheme(asset.file);
    expect({profile.id, first.id, second.id}, hasLength(3));
    expect((await service.loadAll()), hasLength(3));
    expect(first.light.toJson(), profile.light.toJson());
    expect(first.dark.toJson(), profile.dark.toJson());
    expect(first.light.isSeedColorCustom, isFalse);
    expect(first.dark.isSeedColorCustom, isTrue);
    expect(second.dark.isSeedColorCustom, isTrue);
  });

  test('不同亮暗背景图片完整导入，删除原主题不影响导入副本', () async {
    final bright = await service.importBackgroundImage(
      await File('${directory.path}/bright.png').writeAsBytes(_png),
    );
    final gif = base64Decode(
      'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
    );
    final dark = await service.importBackgroundImage(
      await File('${directory.path}/dark.gif').writeAsBytes(gif),
    );
    final profile = await service.save(
      _profile(
        light: ThemeVariant(backgroundImagePath: bright),
        dark: ThemeVariant(backgroundImagePath: dark),
      ),
    );
    final asset = await service.exportTheme(
      profile,
      destination: File('${directory.path}/two-images.zip'),
    );
    final imported = await service.importTheme(asset.file);
    await service.delete(profile.id);
    expect(
      imported.light.backgroundImagePath,
      isNot(imported.dark.backgroundImagePath),
    );
    expect(await File(imported.light.backgroundImagePath!).readAsBytes(), _png);
    expect(await File(imported.dark.backgroundImagePath!).readAsBytes(), gif);
    expect((await service.load(imported.id))!.toJson(), imported.toJson());
  });

  test('可导入临时目录中的 JSON 与图片，复制后不再依赖原始文件', () async {
    await File('${directory.path}/photo.png').writeAsBytes(_png);
    final file = await jsonFile(
      _profile(light: ThemeVariant(backgroundImagePath: 'photo.png')).toJson(),
    );
    final imported = await service.importTheme(file);
    await File('${directory.path}/photo.png').delete();
    await file.delete();
    expect(await File(imported.light.backgroundImagePath!).readAsBytes(), _png);
    expect(
      (await service.load(imported.id))!.light.backgroundImagePath,
      imported.light.backgroundImagePath,
    );
  });

  test('所有数值范围、非有限数值、未知颜色及错误 ARGB 格式均拒绝', () {
    final limits = {
      'backgroundDim': 1,
      'courseCardOpacity': 1,
      'cardRadius': 48,
      'courseCardRadius': 48,
      'dividerWidth': 3,
      'backgroundBlur': 30,
      'surfaceOpacity': 1,
    };
    for (final entry in limits.entries) {
      for (final value in [
        -0.01,
        entry.value + 0.01,
        double.nan,
        double.infinity,
        '1',
        null,
      ]) {
        expect(
          () => ThemeVariant.fromJson({entry.key: value}),
          throwsFormatException,
          reason: '${entry.key}=$value',
        );
      }
      expect(
        () => ThemeVariant.fromJson({entry.key: entry.value}),
        returnsNormally,
      );
    }
    for (final color in [
      'FFFFFF',
      '#FFFFFFFF',
      '0xFFFFFFFF',
      'GGFFFFFF',
      0xffffffff,
      null,
    ]) {
      expect(
        () => ThemeVariant.fromJson({
          'colors': {'primary': color},
        }),
        throwsFormatException,
      );
    }
    for (final colors in [
      {'unknownRole': 0xff123456},
      {'primary': -1},
      {'primary': 0x100000000},
    ]) {
      expect(() => ThemeVariant(colors: colors), throwsFormatException);
    }
    expect(
      () => ThemeVariant.fromJson({'colors': null}),
      throwsFormatException,
    );
  });

  test('版本、顶层字段和不安全 ID 拒绝导入且不写入主题', () async {
    for (final version in [null, 0, 2, '1', 1.0]) {
      await expectLater(
        service.importTheme(
          await jsonFile({..._profile().toJson(), 'version': version}),
        ),
        throwsFormatException,
      );
    }
    for (final id in [
      '',
      '../escape',
      r'C:\escape',
      '/escape',
      'CON',
      'a.json',
      'a/b',
    ]) {
      expect(() => _profile(id: id), throwsFormatException);
      await expectLater(service.load(id), throwsFormatException);
      await expectLater(service.delete(id), throwsFormatException);
    }
    for (final patch in [
      {'light': null},
      {'dark': []},
      {'name': ' '},
      {'baseThemeKey': '../outside'},
    ]) {
      await expectLater(
        service.importTheme(await jsonFile({..._profile().toJson(), ...patch})),
        throwsFormatException,
      );
    }
    expect(await service.loadAll(), isEmpty);
  });

  test('导入图片拒绝绝对路径、路径穿越、URL 和 Windows 路径', () async {
    final root = await service.ensureDirectory();
    for (final path in [
      '../outside.png',
      'images/../../outside.png',
      '/etc/photo.png',
      '${root.path}/images/test.png',
      r'C:\photo.png',
      r'C:photo.png',
      r'\\server\share\photo.png',
      r'images\photo.png',
      'https://example.com/photo.png',
      'file:///tmp/photo.png',
      'images/%2e%2e/photo.png',
      'images/./photo.png',
    ]) {
      await expectLater(
        service.importTheme(
          await jsonFile(
            _profile(light: ThemeVariant(backgroundImagePath: path)).toJson(),
          ),
        ),
        throwsFormatException,
        reason: path,
      );
    }
    expect(await service.loadAll(), isEmpty);
  });

  test('ZIP 拒绝路径穿越、符号链接、重复大小写名称及多余文件', () async {
    final manifest = utf8.encode(jsonEncode(_profile().toJson()));
    for (final entry in [
      ArchiveFile.bytes('../escape.png', _png),
      ArchiveFile.bytes('/escape.png', _png),
      ArchiveFile.bytes(r'C:\escape.png', _png),
      ArchiveFile.symlink('photo.png', '../outside.png'),
      ArchiveFile.bytes('THEME.JSON', manifest),
      ArchiveFile.bytes('unreferenced.png', _png),
    ]) {
      final file = await zipFile(
        Archive()
          ..add(ArchiveFile.bytes('theme.json', manifest))
          ..add(entry),
      );
      await expectLater(service.importTheme(file), throwsFormatException);
    }
    expect(await service.loadAll(), isEmpty);
    expect(await File('${directory.parent.path}/escape.png').exists(), isFalse);
  });

  test('没有规范清单或清单被截断的 ZIP 拒绝导入', () async {
    for (final archive in [
      Archive()..add(
        ArchiveFile.string('THEME.JSON', jsonEncode(_profile().toJson())),
      ),
      Archive()..add(ArchiveFile.string('theme.json', '{')),
      Archive()..add(ArchiveFile.bytes('photo.png', _png)),
    ]) {
      await expectLater(
        service.importTheme(await zipFile(archive)),
        throwsFormatException,
      );
    }
    expect(await service.loadAll(), isEmpty);
  });

  test('目录链接不能使导入包内的图片路径逃逸', () async {
    final outside = await Directory('${directory.path}/outside').create();
    await File('${outside.path}/photo.png').writeAsBytes(_png);
    final package = await Directory('${directory.path}/package').create();
    final link = Link('${package.path}/images');
    try {
      await link.create(outside.path);
    } on FileSystemException {
      markTestSkipped('当前系统未授权创建文件系统链接');
      return;
    }
    try {
      final source = await File('${package.path}/theme.json').writeAsString(
        jsonEncode(
          _profile(light: ThemeVariant(backgroundImagePath: 'images/photo.png'))
              .toJson(),
        ),
      );
      await expectLater(service.importTheme(source), throwsFormatException);
      expect(await service.loadAll(), isEmpty);
    } finally {
      await link.delete();
    }
  });

  test('JSON、图片和压缩包有大小上限，格式错误的图片不写入', () async {
    final tooLarge = await File('${directory.path}/huge.json')
        .open(mode: FileMode.write);
    await tooLarge.truncate(ThemeCustomizationService.maxJsonBytes + 1);
    await tooLarge.close();
    await expectLater(
      service.importTheme(File('${directory.path}/huge.json')),
      throwsFormatException,
    );
    final picture = await File('${directory.path}/huge.png')
        .open(mode: FileMode.write);
    await picture.truncate(ThemeCustomizationService.maxImageBytes + 1);
    await picture.close();
    await expectLater(
      service.importBackgroundImage(File('${directory.path}/huge.png')),
      throwsFormatException,
    );
    final package = await File('${directory.path}/huge.zip')
        .open(mode: FileMode.write);
    await package.truncate(ThemeCustomizationService.maxPackageBytes + 1);
    await package.close();
    await expectLater(
      service.importTheme(File('${directory.path}/huge.zip')),
      throwsFormatException,
    );
    await expectLater(
      service.importBackgroundImage(
        await File('${directory.path}/fake.png').writeAsString('<svg/>'),
      ),
      throwsFormatException,
    );
    final zip = await zipFile(
      Archive()..add(
        ArchiveFile.bytes(
          'theme.json',
          Uint8List(ThemeCustomizationService.maxJsonBytes + 1),
        ),
      ),
    );
    await expectLater(service.importTheme(zip), throwsFormatException);
    expect(await service.loadAll(), isEmpty);
  });

  test('损坏导入和保存失败不会覆盖旧主题，损坏主题可以删除', () async {
    final old = await service.save(_profile());
    final root = await service.ensureDirectory();
    await expectLater(
      service.save(
        old.copyWith(
          light: ThemeVariant(backgroundImagePath: 'images/missing.png'),
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect((await service.load(old.id))!.toJson(), old.toJson());
    await File('${root.path}/sample.json').writeAsString('broken');
    await expectLater(service.load('sample'), throwsFormatException);
    await service.delete('sample');
    expect(await service.load('sample'), isNull);
  });

  test('导出不能覆盖主题清单或图片文件', () async {
    await service.save(_profile());
    final root = await service.ensureDirectory();
    await expectLater(
      service.exportTheme(
        _profile(),
        destination: File('${root.path}/sample.json'),
      ),
      throwsFormatException,
    );
    expect((await service.load('sample'))!.name, '我的主题');
  });

  test('图片和主题包均在渲染前拒绝超大尺寸或只有签名的损坏图片', () async {
    final bytes = image.encodePng(image.Image(width: 9000, height: 1));
    final oversized = await File('${directory.path}/wide.png')
        .writeAsBytes(bytes);
    await expectLater(
      service.importBackgroundImage(oversized),
      throwsFormatException,
    );
    final package = await zipFile(
      Archive()
        ..add(
          ArchiveFile.bytes(
            'theme.json',
            utf8.encode(
              jsonEncode(
                _profile(
                  light: ThemeVariant(backgroundImagePath: 'images/wide.png'),
                ).toJson(),
              ),
            ),
          ),
        )
        ..add(ArchiveFile.bytes('images/wide.png', bytes)),
    );
    await expectLater(service.importTheme(package), throwsFormatException);
    final broken = await File('${directory.path}/broken.jpg')
        .writeAsBytes([0xff, 0xd8, 0xff]);
    await expectLater(
      service.importBackgroundImage(broken),
      throwsFormatException,
    );
    expect(await service.loadAll(), isEmpty);
  });
}
