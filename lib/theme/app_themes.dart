import 'package:flutter/material.dart';

const appThemes = [
  ('深紫', Color(0xFF673AB7)),
  ('蓝色', Color(0xFF2196F3)),
  ('青色', Color(0xFF009688)),
  ('绿色', Color(0xFF4CAF50)),
  ('橙色', Color(0xFFFF9800)),
  ('红色', Color(0xFFF44336)),
  ('粉色', Color(0xFFE91E63)),
  ('靛蓝', Color(0xFF3F51B5)),
  ('棕色', Color(0xFF795548)),
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
