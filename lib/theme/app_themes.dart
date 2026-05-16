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

ThemeData buildTheme(Color seedColor, {Brightness brightness = Brightness.light}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    splashFactory: NoSplash.splashFactory,
    appBarTheme: const AppBarTheme(
      scrolledUnderElevation: 0,
    ),
  );
}
