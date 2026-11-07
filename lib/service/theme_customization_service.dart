import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fzu_assistant/service/course_color_palettes.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';

/// One brightness mode. Missing color roles keep the selected base palette.
///
/// Colors are ARGB integers in memory and exactly eight hex digits in JSON.
/// [backgroundImagePath] is absolute after service reads/saves, but relative
/// inside persisted JSON and exported packages.
class ThemeVariant {
  ThemeVariant({
    Map<String, int> colors = const {},
    this.coursePaletteKey = CourseColorPalettes.tailwind,
    List<int> coursePalette = const [],
    this.colorSource,
    this.seedColor,
    this.isSeedColorCustom = false,
    this.backgroundImagePath,
    this.backgroundDim = 0,
    this.courseCardOpacity = 1,
    this.cardRadius = 24,
    this.courseCardRadius = 8,
    this.dividerWidth = 1,
    this.backgroundBlur = 0,
    this.surfaceOpacity = 0.9,
  }) : colors = Map.unmodifiable(colors),
       coursePalette = List.unmodifiable(coursePalette) {
    if (!CourseColorPalettes.keys.contains(coursePaletteKey)) {
      throw const FormatException('课程色卡无效');
    }
    if (coursePalette.length > CourseColorPalettes.maxColors ||
        coursePalette.any((color) => color < 0 || color > 0xffffffff)) {
      throw const FormatException('课程色卡需为最多 64 个 8 位 ARGB 颜色');
    }
    if (colorSource != null && !colorSources.contains(colorSource)) {
      throw const FormatException('主题配色来源无效');
    }
    if (seedColor != null && (seedColor! < 0 || seedColor! > 0xffffffff)) {
      throw const FormatException('主题种子色必须是 8 位 ARGB 颜色');
    }
    if ((colorSource == 'seed' || colorSource == 'image') &&
        seedColor == null) {
      throw const FormatException('自选颜色和背景图配色需要种子色');
    }
    for (final entry in colors.entries) {
      if (!colorKeys.contains(entry.key) ||
          entry.value < 0 ||
          entry.value > 0xffffffff) {
        throw const FormatException('主题颜色必须是受支持的 8 位 ARGB 颜色');
      }
    }
    if (backgroundImagePath != null &&
        (backgroundImagePath!.isEmpty ||
            backgroundImagePath!.length > 4096 ||
            _hasControlCharacters(backgroundImagePath!))) {
      throw const FormatException('背景图片路径无效');
    }
    _checkRange(backgroundDim, 1, 'backgroundDim');
    _checkRange(courseCardOpacity, 1, 'courseCardOpacity');
    _checkRange(cardRadius, 48, 'cardRadius');
    _checkRange(courseCardRadius, 48, 'courseCardRadius');
    _checkRange(dividerWidth, 3, 'dividerWidth');
    _checkRange(backgroundBlur, 30, 'backgroundBlur');
    _checkRange(surfaceOpacity, 1, 'surfaceOpacity');
  }

  static const colorSources = {'system', 'image', 'seed'};

  static const colorKeys = {
    'primary',
    'onPrimary',
    'primaryContainer',
    'onPrimaryContainer',
    'primaryFixed',
    'primaryFixedDim',
    'onPrimaryFixed',
    'onPrimaryFixedVariant',
    'secondary',
    'onSecondary',
    'secondaryContainer',
    'onSecondaryContainer',
    'secondaryFixed',
    'secondaryFixedDim',
    'onSecondaryFixed',
    'onSecondaryFixedVariant',
    'tertiary',
    'onTertiary',
    'tertiaryContainer',
    'onTertiaryContainer',
    'tertiaryFixed',
    'tertiaryFixedDim',
    'onTertiaryFixed',
    'onTertiaryFixedVariant',
    'error',
    'onError',
    'errorContainer',
    'onErrorContainer',
    'surface',
    'onSurface',
    'onSurfaceVariant',
    'surfaceDim',
    'surfaceBright',
    'surfaceContainerLowest',
    'surfaceContainerLow',
    'surfaceContainer',
    'surfaceContainerHigh',
    'surfaceContainerHighest',
    'inverseSurface',
    'onInverseSurface',
    'inversePrimary',
    'surfaceTint',
    'highlight',
    'outline',
    'outlineVariant',
    'shadow',
    'scrim',
    'courseCard',
    'courseCardText',
    'courseCardSecondaryText',
    'courseAccent',
    'divider',
    'todayHighlight',
    'onTodayHighlight',
  };

  final Map<String, int> colors;
  final String coursePaletteKey;

  /// Empty inherits the selected preset for this brightness.
  final List<int> coursePalette;

  /// Null keeps the legacy profile's [ThemeProfile.baseThemeKey] palette.
  final String? colorSource;
  final int? seedColor;

  /// An explicit custom choice, even when [seedColor] matches a built-in seed.
  final bool isSeedColorCustom;
  final String? backgroundImagePath;
  final double backgroundDim;
  final double courseCardOpacity;
  final double cardRadius;
  final double courseCardRadius;
  final double dividerWidth;
  final double backgroundBlur;
  final double surfaceOpacity;

  ThemeVariant copyWith({
    Map<String, int>? colors,
    String? coursePaletteKey,
    List<int>? coursePalette,
    String? colorSource,
    int? seedColor,
    bool? isSeedColorCustom,
    bool clearColorSource = false,
    bool clearSeedColor = false,
    String? backgroundImagePath,
    bool clearBackgroundImage = false,
    double? backgroundDim,
    double? courseCardOpacity,
    double? cardRadius,
    double? courseCardRadius,
    double? dividerWidth,
    double? backgroundBlur,
    double? surfaceOpacity,
  }) => ThemeVariant(
    colors: colors ?? this.colors,
    coursePaletteKey: coursePaletteKey ?? this.coursePaletteKey,
    coursePalette: coursePalette ?? this.coursePalette,
    colorSource: clearColorSource ? null : colorSource ?? this.colorSource,
    seedColor: clearSeedColor ? null : seedColor ?? this.seedColor,
    isSeedColorCustom: isSeedColorCustom ?? this.isSeedColorCustom,
    backgroundImagePath: clearBackgroundImage
        ? null
        : (backgroundImagePath ?? this.backgroundImagePath),
    backgroundDim: backgroundDim ?? this.backgroundDim,
    courseCardOpacity: courseCardOpacity ?? this.courseCardOpacity,
    cardRadius: cardRadius ?? this.cardRadius,
    courseCardRadius: courseCardRadius ?? this.courseCardRadius,
    dividerWidth: dividerWidth ?? this.dividerWidth,
    backgroundBlur: backgroundBlur ?? this.backgroundBlur,
    surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
  );

  Map<String, dynamic> toJson() => {
    'coursePaletteKey': coursePaletteKey,
    if (coursePalette.isNotEmpty)
      'coursePalette': [
        for (final color in coursePalette)
          color.toRadixString(16).padLeft(8, '0').toUpperCase(),
      ],
    if (colorSource != null) 'colorSource': colorSource,
    if (seedColor != null)
      'seedColor': seedColor!.toRadixString(16).padLeft(8, '0').toUpperCase(),
    if (isSeedColorCustom) 'isSeedColorCustom': true,
    'colors': {
      for (final entry in colors.entries)
        entry.key: entry.value.toRadixString(16).padLeft(8, '0').toUpperCase(),
    },
    'backgroundImagePath': backgroundImagePath,
    'backgroundDim': backgroundDim,
    'courseCardOpacity': courseCardOpacity,
    'cardRadius': cardRadius,
    'courseCardRadius': courseCardRadius,
    'dividerWidth': dividerWidth,
    'backgroundBlur': backgroundBlur,
    'surfaceOpacity': surfaceOpacity,
  };

  factory ThemeVariant.fromJson(Map<String, dynamic> json) {
    final paletteKey = json['coursePaletteKey'] ?? CourseColorPalettes.tailwind;
    if (paletteKey is! String) {
      throw const FormatException('课程色卡无效');
    }
    final palette = json['coursePalette'] ?? const [];
    if (palette is! List || palette.length > CourseColorPalettes.maxColors) {
      throw const FormatException('课程色卡需为最多 64 个 8 位 ARGB 颜色');
    }
    final parsedPalette = <int>[];
    for (final color in palette) {
      if (color is! String || !RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(color)) {
        throw const FormatException('课程色卡必须是 8 位 ARGB 十六进制字符串');
      }
      parsedPalette.add(int.parse(color, radix: 16));
    }
    final source = json['colorSource'];
    if (source != null && source is! String) {
      throw const FormatException('主题配色来源无效');
    }
    final seed = json['seedColor'];
    if (seed != null &&
        (seed is! String || !RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(seed))) {
      throw const FormatException('主题种子色必须是 8 位 ARGB 十六进制字符串');
    }
    final custom = json.containsKey('isSeedColorCustom')
        ? json['isSeedColorCustom']
        : false;
    if (custom is! bool) {
      throw const FormatException('自定义种子色标记必须是布尔值');
    }
    final colors = json.containsKey('colors')
        ? _map(json['colors'])
        : <String, dynamic>{};
    final parsed = <String, int>{};
    for (final entry in colors.entries) {
      if (entry.value is! String ||
          !RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(entry.value as String)) {
        throw const FormatException('主题颜色必须是 8 位 ARGB 十六进制字符串');
      }
      parsed[entry.key] = int.parse(entry.value as String, radix: 16);
    }
    final image = json['backgroundImagePath'];
    if (image != null && image is! String) {
      throw const FormatException('背景图片路径无效');
    }
    return ThemeVariant(
      colors: parsed,
      coursePaletteKey: paletteKey,
      coursePalette: parsedPalette,
      colorSource: source as String?,
      seedColor: seed == null ? null : int.parse(seed as String, radix: 16),
      isSeedColorCustom: custom,
      backgroundImagePath: image as String?,
      backgroundDim: _number(json, 'backgroundDim', 0),
      courseCardOpacity: _number(json, 'courseCardOpacity', 1),
      cardRadius: _number(json, 'cardRadius', 24),
      courseCardRadius: _number(json, 'courseCardRadius', 8),
      dividerWidth: _number(json, 'dividerWidth', 1),
      backgroundBlur: _number(json, 'backgroundBlur', 0),
      surfaceOpacity: _number(json, 'surfaceOpacity', 0.9),
    );
  }
}

class ThemeProfile {
  ThemeProfile({
    required this.id,
    required this.name,
    this.baseThemeKey = 'deep_purple',
    required this.light,
    required this.dark,
  }) {
    _checkId(id);
    if (name.trim().isEmpty ||
        name.length > 80 ||
        _hasControlCharacters(name)) {
      throw const FormatException('主题名称需为 1 至 80 个字符');
    }
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(baseThemeKey)) {
      throw const FormatException('基础色卡名称无效');
    }
  }

  static const version = 1;
  final String id;
  final String name;
  final String baseThemeKey;
  final ThemeVariant light;
  final ThemeVariant dark;

  ThemeProfile copyWith({
    String? id,
    String? name,
    String? baseThemeKey,
    ThemeVariant? light,
    ThemeVariant? dark,
  }) => ThemeProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    baseThemeKey: baseThemeKey ?? this.baseThemeKey,
    light: light ?? this.light,
    dark: dark ?? this.dark,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'id': id,
    'name': name,
    'baseThemeKey': baseThemeKey,
    'light': light.toJson(),
    'dark': dark.toJson(),
  };

  factory ThemeProfile.fromJson(Map<String, dynamic> json) {
    if (json['version'] is! int || json['version'] != version) {
      throw const FormatException('不支持的主题文件版本');
    }
    if (json['id'] is! String ||
        json['name'] is! String ||
        (json.containsKey('baseThemeKey') && json['baseThemeKey'] is! String)) {
      throw const FormatException('主题信息不完整');
    }
    return ThemeProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      baseThemeKey: json['baseThemeKey'] as String? ?? 'deep_purple',
      light: ThemeVariant.fromJson(_map(json['light'])),
      dark: ThemeVariant.fromJson(_map(json['dark'])),
    );
  }
}

/// Pass [file.path] and [mimeType] to XFile/share_plus, or open its directory.
class ShareableThemeAsset {
  const ShareableThemeAsset({
    required this.file,
    required this.name,
    this.mimeType = 'application/zip',
  });

  final File file;
  final String name;
  final String mimeType;
}

/// Application-owned themes, separate from credentials and app preferences.
///
/// JSON lives at `Documents/fzu-themes/<id>.json`; images are content-addressed
/// under images/. Importing always creates a fresh ID, never replacing a local
/// theme. All operations on this service share a queue.
class ThemeCustomizationService {
  ThemeCustomizationService({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  static final instance = ThemeCustomizationService();
  static const maxJsonBytes = 256 * 1024;
  static const maxImageBytes = 20 * 1024 * 1024;
  static const maxPackageBytes = 2 * maxImageBytes + maxJsonBytes + 64 * 1024;
  static final _random = Random.secure();

  final Future<Directory> Function() _directory;
  Future<void> _pending = Future.value();

  static String createId() =>
      'theme-${DateTime.now().microsecondsSinceEpoch}-'
      '${_random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0')}';

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<Directory> ensureDirectory() => _serialize(_ensureDirectory);

  Future<Directory> _ensureDirectory() async {
    final documents = await _directory();
    await documents.create(recursive: true);
    final parent = Directory(await documents.resolveSymbolicLinks());
    final root = await _childDirectory(parent, 'fzu-themes');
    await _childDirectory(root, 'images');
    return root;
  }

  Future<List<ThemeProfile>> loadAll() => _serialize(() async {
    final root = await _ensureDirectory();
    return _loadAll(root);
  });

  Future<List<ThemeProfile>> _loadAll(Directory root) async {
    final profiles = <ThemeProfile>[];
    await for (final entry in root.list(followLinks: false)) {
      final name = _basename(entry.path);
      if (!name.endsWith('.json')) continue;
      final id = name.substring(0, name.length - 5);
      _checkId(id);
      final profile = await _load(root, id);
      if (profile != null) profiles.add(profile);
    }
    profiles.sort((a, b) {
      final order = a.name.compareTo(b.name);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return List.unmodifiable(profiles);
  }

  Future<ThemeProfile?> load(String id) => _serialize(() async {
    _checkId(id);
    return _load(await _ensureDirectory(), id);
  });

  Future<ThemeProfile?> _load(Directory root, String id) async {
    final file = File(_join(root, '$id.json'));
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return null;
    }
    await _fileInside(root, file.path);
    final profile = _decodeProfile(await _readLimited(file, maxJsonBytes));
    if (profile.id != id) {
      throw const FormatException('主题 ID 与文件名不一致');
    }
    Future<ThemeVariant> resolve(ThemeVariant variant) async {
      final path = variant.backgroundImagePath;
      if (path == null) return variant;
      _checkRelativePath(path);
      final image = await _fileInside(root, path);
      _imageExtension(await _readLimited(image, maxImageBytes));
      return variant.copyWith(backgroundImagePath: image.path);
    }

    return profile.copyWith(
      light: await resolve(profile.light),
      dark: await resolve(profile.dark),
    );
  }

  /// Pictures must first be copied using [importBackgroundImage].
  Future<ThemeProfile> save(ThemeProfile profile) => _serialize(() async {
    final root = await _ensureDirectory();
    return _save(root, profile);
  });

  Future<ThemeProfile> _save(
    Directory root,
    ThemeProfile profile, {
    Directory? packageDirectory,
    Map<String, Uint8List>? packageImages,
  }) async {
    Future<Uint8List?> read(ThemeVariant variant) async {
      final path = variant.backgroundImagePath;
      if (path == null) return null;
      if (packageDirectory != null || packageImages != null) {
        _checkRelativePath(path);
      }
      final Uint8List bytes;
      if (packageImages != null) {
        final image = packageImages[path];
        if (image == null) throw const FormatException('主题包缺少背景图片');
        bytes = image;
      } else {
        final file = await _fileInside(packageDirectory ?? root, path);
        bytes = await _readLimited(file, maxImageBytes);
      }
      _imageExtension(bytes);
      return bytes;
    }

    // Validate both modes before writing any file or replacing a local theme.
    final light = await read(profile.light);
    final dark = await read(profile.dark);
    Future<ThemeVariant> store(ThemeVariant variant, Uint8List? bytes) async {
      if (bytes == null) return variant;
      return variant.copyWith(
        backgroundImagePath: (await _storeImage(root, bytes)).path,
      );
    }

    final saved = profile.copyWith(
      light: await store(profile.light, light),
      dark: await store(profile.dark, dark),
    );
    final portable = _portable(saved, root);
    final json = utf8.encode(jsonEncode(portable.toJson()));
    if (json.length > maxJsonBytes) {
      throw const FormatException('主题 JSON 超过大小限制');
    }
    await _writeAtomic(File(_join(root, '${profile.id}.json')), json);
    return saved;
  }

  Future<void> delete(String id) => _serialize(() async {
    _checkId(id);
    final root = await _ensureDirectory();
    final file = File(_join(root, '$id.json'));
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return;
    }
    await _fileInside(root, file.path);
    ThemeProfile? removed;
    try {
      removed = await _load(root, id);
    } on FormatException {
      // A broken theme can still be deleted; its images are left untouched.
    } on FileSystemException {
      // Missing pictures must not prevent removing their theme.
    }
    await file.delete();
    if (removed == null) return;
    final List<ThemeProfile> remaining;
    try {
      remaining = await _loadAll(root);
    } on FormatException {
      return; // Preserve pictures if another theme cannot be checked.
    } on FileSystemException {
      return;
    }
    final used = {
      for (final profile in remaining)
        for (final variant in [profile.light, profile.dark])
          if (variant.backgroundImagePath != null)
            _pathKey(variant.backgroundImagePath!),
    };
    final candidates = {
      removed.light.backgroundImagePath,
      removed.dark.backgroundImagePath,
    }..remove(null);
    for (final path in candidates) {
      if (!used.contains(_pathKey(path!))) {
        final image = await _fileInside(root, path);
        // Only delete generated assets, never arbitrary files within root.
        if (_generatedImage.hasMatch(_relative(root, image.path))) {
          await image.delete();
        }
      }
    }
  });

  /// Only this explicit file-picker entry point accepts a picture outside root.
  Future<String> importBackgroundImage(File source) => _serialize(() async {
    final bytes = await _readLimited(source, maxImageBytes);
    _imageExtension(bytes);
    return (await _storeImage(await _ensureDirectory(), bytes)).path;
  });

  Future<File> _storeImage(Directory root, Uint8List bytes) async {
    final name = '${sha256.convert(bytes)}.${_imageExtension(bytes)}';
    final images = await _childDirectory(root, 'images');
    final file = File(_join(images, name));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.notFound) {
      await _fileInside(root, file.path);
      final existing = await _readLimited(file, maxImageBytes);
      if (sha256.convert(existing).toString() !=
          sha256.convert(bytes).toString()) {
        throw const FormatException('已保存的背景图片损坏');
      }
    } else {
      await _writeAtomic(file, bytes);
    }
    return file;
  }

  /// A single ZIP containing theme.json and at most two deduplicated images.
  Future<ShareableThemeAsset> exportTheme(
    ThemeProfile profile, {
    required File destination,
  }) => _serialize(() async {
    final root = await _ensureDirectory();
    final images = <String, Uint8List>{};
    Future<ThemeVariant> pack(ThemeVariant variant) async {
      final path = variant.backgroundImagePath;
      if (path == null) return variant;
      final source = await _fileInside(root, path);
      final bytes = await _readLimited(source, maxImageBytes);
      final relative =
          'images/${sha256.convert(bytes)}.${_imageExtension(bytes)}';
      images[relative] = bytes;
      return variant.copyWith(backgroundImagePath: relative);
    }

    final portable = profile.copyWith(
      light: await pack(profile.light),
      dark: await pack(profile.dark),
    );
    final manifest = utf8.encode(jsonEncode(portable.toJson()));
    if (manifest.length > maxJsonBytes) {
      throw const FormatException('主题 JSON 超过大小限制');
    }
    final archive = Archive()..add(ArchiveFile.bytes('theme.json', manifest));
    for (final entry in images.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }
    final bytes = ZipEncoder().encode(archive);
    if (bytes.length > maxPackageBytes) {
      throw const FormatException('主题包超过大小限制');
    }
    final target = destination.absolute;
    await target.parent.create(recursive: true);
    final parent = Directory(await target.parent.resolveSymbolicLinks());
    final resolved = File(_join(parent, _basename(target.path)));
    if (_isInside(root.path, resolved.path) &&
        (resolved.path.endsWith('.json') ||
            _isInside(_join(root, 'images'), resolved.path))) {
      throw const FormatException('导出文件不能覆盖已保存的主题或背景图片');
    }
    await _writeAtomic(resolved, bytes);
    return ShareableThemeAsset(file: resolved, name: _basename(resolved.path));
  });

  /// Accepts a ZIP, or a JSON manifest with pictures relative to its directory.
  /// Imported IDs are replaced, so importing cannot overwrite a local theme.
  Future<ThemeProfile> importTheme(File source) => _serialize(() async {
    final bytes = await _readLimited(source, maxPackageBytes);
    final root = await _ensureDirectory();
    if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
      final entries = _readPackage(bytes);
      final profile = _decodeProfile(entries.remove('theme.json')!)
          .copyWith(id: createId());
      final referenced = {
        profile.light.backgroundImagePath,
        profile.dark.backgroundImagePath,
      }..remove(null);
      if (referenced.length != entries.length ||
          !referenced.every(entries.containsKey)) {
        throw const FormatException('主题包图片清单不匹配');
      }
      return _save(root, profile, packageImages: entries);
    }
    if (bytes.length > maxJsonBytes) {
      throw const FormatException('主题 JSON 超过大小限制');
    }
    final profile = _decodeProfile(bytes).copyWith(id: createId());
    final directory = Directory(await source.parent.resolveSymbolicLinks());
    return _save(root, profile, packageDirectory: directory);
  });

  Map<String, Uint8List> _readPackage(Uint8List bytes) {
    // Inspect headers before ZipDecoder can materialize even a symlink entry.
    final directory = ZipDirectory()
      ..read(InputMemoryStream(bytes), verify: true);
    if (directory.filePosition < 0 ||
        directory.fileHeaders.isEmpty ||
        directory.fileHeaders.length > 3) {
      throw const FormatException('主题包文件清单无效');
    }
    final names = <String>{};
    for (final header in directory.fileHeaders) {
      final file = header.file!;
      _checkRelativePath(file.filename);
      final fileType = (header.externalFileAttributes >> 16) & 0xf000;
      final limit = file.filename == 'theme.json'
          ? maxJsonBytes
          : maxImageBytes;
      if (!names.add(file.filename.toLowerCase()) ||
          (fileType != 0 && fileType != 0x8000) ||
          (header.externalFileAttributes & 0x10) != 0 ||
          (file.flags & 1) != 0 ||
          file.uncompressedSize <= 0 ||
          file.uncompressedSize > limit ||
          (file.compressionMethod != CompressionType.none &&
              file.compressionMethod != CompressionType.deflate)) {
        throw const FormatException('主题包含不支持或过大的文件');
      }
    }
    if (!directory.fileHeaders.any(
      (header) => header.file!.filename == 'theme.json',
    )) {
      throw const FormatException('主题包缺少 theme.json');
    }
    final archive = ZipDecoder().decodeBytes(
      bytes,
      verify: true,
      throwOnError: true,
    );
    try {
      return {for (final entry in archive) entry.name: entry.readBytes()!};
    } finally {
      archive.clearSync();
    }
  }
}

ThemeProfile _decodeProfile(List<int> bytes) =>
    ThemeProfile.fromJson(_map(jsonDecode(utf8.decode(bytes))));

ThemeProfile _portable(ThemeProfile profile, Directory root) {
  ThemeVariant variant(ThemeVariant value) => value.backgroundImagePath == null
      ? value
      : value.copyWith(
          backgroundImagePath: _relative(root, value.backgroundImagePath!),
        );
  return profile.copyWith(
    light: variant(profile.light),
    dark: variant(profile.dark),
  );
}

final _generatedImage = RegExp(r'^images/[0-9a-f]{64}\.(png|jpg|gif|webp)$');

Future<Directory> _childDirectory(Directory parent, String name) async {
  final directory = Directory(_join(parent, name));
  final type = await FileSystemEntity.type(directory.path, followLinks: false);
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.directory) {
    throw const FormatException('主题目录不能是链接或文件');
  }
  await directory.create();
  final resolved = Directory(await directory.resolveSymbolicLinks());
  if (!_isInside(parent.path, resolved.path)) {
    throw const FormatException('主题目录超出应用目录');
  }
  return resolved;
}

Future<File> _fileInside(Directory root, String path) async {
  final file = File(path).isAbsolute ? File(path) : File(_join(root, path));
  final normalized = file.absolute.uri.normalizePath().toFilePath();
  if (!_isInside(root.path, normalized)) {
    throw const FormatException('背景图片必须位于主题目录或导入包内');
  }
  final relative = _relative(root, normalized);
  var current = root.path;
  final parts = relative.split('/');
  for (var i = 0; i < parts.length; i++) {
    current = '$current${Platform.pathSeparator}${parts[i]}';
    final type = await FileSystemEntity.type(current, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('主题文件不存在', current);
    }
    if (type !=
        (i == parts.length - 1
            ? FileSystemEntityType.file
            : FileSystemEntityType.directory)) {
      throw const FormatException('主题文件路径不能包含符号链接');
    }
  }
  final resolved = File(await file.resolveSymbolicLinks());
  if (!_isInside(root.path, resolved.path)) {
    throw const FormatException('主题文件路径超出目录');
  }
  return resolved;
}

Future<Uint8List> _readLimited(File file, int limit) async {
  final stat = await file.stat();
  if (stat.type != FileSystemEntityType.file ||
      stat.size <= 0 ||
      stat.size > limit) {
    throw const FormatException('主题文件为空或超过大小限制');
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (bytes.length + chunk.length > limit) {
      throw const FormatException('主题文件超过大小限制');
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}

Future<void> _writeAtomic(File file, List<int> bytes) async {
  final type = await FileSystemEntity.type(file.path, followLinks: false);
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.file) {
    throw const FormatException('目标文件不能是链接或目录');
  }
  final temporary = File(
    '${file.path}.${ThemeCustomizationService.createId()}.tmp',
  );
  await temporary.create(exclusive: true);
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

String _imageExtension(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > ThemeCustomizationService.maxImageBytes) {
    throw const FormatException('背景图片为空或超过大小限制');
  }
  bool starts(List<int> signature) =>
      bytes.length >= signature.length &&
      Iterable<int>.generate(signature.length)
          .every((index) => bytes[index] == signature[index]);
  String? extension;
  if (starts([137, 80, 78, 71, 13, 10, 26, 10])) extension = 'png';
  if (starts([255, 216, 255])) extension = 'jpg';
  if (starts(ascii.encode('GIF87a')) || starts(ascii.encode('GIF89a'))) {
    extension = 'gif';
  }
  if (bytes.length >= 12 &&
      starts(ascii.encode('RIFF')) &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    extension = 'webp';
  }
  if (extension == null) {
    throw const FormatException('背景图片仅支持 PNG、JPEG、GIF 或 WebP');
  }
  // Check dimensions before any renderer allocates a decoded image, including
  // pictures arriving in shared packages rather than through our image picker.
  const maxPixels = 16 * 1024 * 1024;
  const maxDimension = 8192;
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final image.Decoder decoder = switch (extension) {
    'png' => image.PngDecoder(maxPixels: maxPixels),
    'jpg' => image.JpegDecoder(maxPixels: maxPixels),
    'webp' => image.WebPDecoder()..maxPixels = maxPixels,
    _ => image.GifDecoder(),
  };
  try {
    final info = decoder.startDecode(data);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width > maxDimension ||
        info.height > maxDimension ||
        info.width * info.height > maxPixels ||
        info.numFrames > 1) {
      throw const FormatException('背景图片已损坏、不是静态图片或超过 1600 万像素');
    }
  } on image.ImageException {
    throw const FormatException('背景图片已损坏或尺寸超过限制');
  } on RangeError {
    throw const FormatException('背景图片已损坏');
  }
  return extension;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('主题 JSON 对象无效');
  }
  return Map<String, dynamic>.from(value);
}

double _number(Map<String, dynamic> json, String key, double fallback) {
  if (!json.containsKey(key)) return fallback;
  final value = json[key];
  if (value is! num || !value.isFinite) {
    throw FormatException('主题参数 $key 必须是有限数值');
  }
  return value.toDouble();
}

void _checkRange(double value, double maximum, String key) {
  if (!value.isFinite || value < 0 || value > maximum) {
    throw FormatException('主题参数 $key 必须在 0 至 $maximum 之间');
  }
}

void _checkId(String id) {
  if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$').hasMatch(id) ||
      RegExp(
        r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$',
        caseSensitive: false,
      ).hasMatch(id)) {
    throw const FormatException('主题 ID 无效');
  }
}

void _checkRelativePath(String path) {
  final parts = path.split('/');
  if (parts.isEmpty ||
      parts.length > 3 ||
      parts.any(
        (part) =>
            !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}$').hasMatch(part) ||
            part.endsWith('.'),
      )) {
    throw const FormatException('主题图片必须使用包内相对路径');
  }
}

bool _hasControlCharacters(String value) =>
    value.runes.any((rune) => rune < 32 || rune == 127);

String _join(Directory directory, String name) =>
    '${directory.path}${Platform.pathSeparator}$name';

String _basename(String path) => path.replaceAll('\\', '/').split('/').last;

String _pathKey(String path) {
  final normalized = path.replaceAll('\\', '/').replaceFirst(RegExp(r'/$'), '');
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

bool _isInside(String root, String path) =>
    _pathKey(path).startsWith('${_pathKey(root)}/');

String _relative(Directory root, String path) {
  if (!_isInside(root.path, path)) {
    throw const FormatException('主题文件超出允许目录');
  }
  return path
      .replaceAll('\\', '/')
      .substring(root.path.replaceAll('\\', '/').length + 1);
}
