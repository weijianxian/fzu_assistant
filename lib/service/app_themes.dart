import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ThemeConfig {
  final String key;
  final String name;
  final Color color;
  const ThemeConfig(this.key, this.name, this.color);
}

const appThemes = [
  ThemeConfig('deep_purple', '深紫', Color(0xFF673AB7)),
  ThemeConfig('blue', '蓝色', Color(0xFF2196F3)),
  ThemeConfig('teal', '青色', Color(0xFF009688)),
  ThemeConfig('green', '绿色', Color(0xFF4CAF50)),
  ThemeConfig('orange', '橙色', Color(0xFFFF9800)),
  ThemeConfig('red', '红色', Color(0xFFF44336)),
  ThemeConfig('pink', '粉色', Color(0xFFE91E63)),
  ThemeConfig('indigo', '靛蓝', Color(0xFF3F51B5)),
  ThemeConfig('brown', '棕色', Color(0xFF795548)),
];

ThemeData buildTheme(
  Color seedColor, {
  Brightness brightness = Brightness.light,
}) {
  return buildThemeFromScheme(
    ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness),
  );
}

/// 所有配色共用主题入口，保证系统配色也使用相同的桌面排版。
ThemeData buildThemeFromScheme(ColorScheme colorScheme) {
  final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  final textTheme = isWindows ? _windowsTextTheme : null;
  return ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    // 拉丁字形使用 Segoe UI；中文明确回退到微软雅黑 UI。
    fontFamily: isWindows ? 'Segoe UI' : null,
    fontFamilyFallback: isWindows
        ? const ['Microsoft YaHei UI', 'Microsoft YaHei', 'Segoe UI Emoji']
        : null,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
  );
}

TextStyle _windowsTextStyle(
  double size, {
  FontWeight weight = FontWeight.w400,
  double height = 1.4,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  height: height,
  letterSpacing: 0,
);

// 中文无需 Material 默认的拉丁字间距，标题以中等字重建立层级。
final _windowsTextTheme = TextTheme(
  displayLarge: _windowsTextStyle(48, height: 1.2),
  displayMedium: _windowsTextStyle(40, height: 1.2),
  displaySmall: _windowsTextStyle(32, height: 1.25),
  headlineLarge: _windowsTextStyle(28, weight: FontWeight.w600, height: 1.3),
  headlineMedium: _windowsTextStyle(24, weight: FontWeight.w600, height: 1.3),
  headlineSmall: _windowsTextStyle(22, weight: FontWeight.w600, height: 1.3),
  titleLarge: _windowsTextStyle(20, weight: FontWeight.w600, height: 1.3),
  titleMedium: _windowsTextStyle(16, weight: FontWeight.w600),
  titleSmall: _windowsTextStyle(14, weight: FontWeight.w600),
  bodyLarge: _windowsTextStyle(15, height: 1.5),
  bodyMedium: _windowsTextStyle(14, height: 1.5),
  bodySmall: _windowsTextStyle(12, height: 1.5),
  labelLarge: _windowsTextStyle(14, weight: FontWeight.w500),
  labelMedium: _windowsTextStyle(13, weight: FontWeight.w500),
  labelSmall: _windowsTextStyle(12, weight: FontWeight.w500),
);
