import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/theme/app_themes.dart';

class ThemeState {
  final themeIndex = ValueNotifier<int>(0);
  final themeMode = ValueNotifier<int>(0); // 0=跟随系统, 1=浅色, 2=深色
  static const _keyIndex = 'theme_index';
  static const _keyMode = 'theme_mode';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final idx = sp.getInt(_keyIndex) ?? 0;
    if (idx < appThemes.length) themeIndex.value = idx;
    final mode = sp.getInt(_keyMode) ?? 0;
    if (mode >= 0 && mode <= 2) themeMode.value = mode;

    themeIndex.addListener(() =>
        SharedPreferences.getInstance().then((sp) => sp.setInt(_keyIndex, themeIndex.value)));
    themeMode.addListener(() =>
        SharedPreferences.getInstance().then((sp) => sp.setInt(_keyMode, themeMode.value)));
  }

  ThemeData get lightTheme =>
      buildTheme(appThemes[themeIndex.value].$2, brightness: Brightness.light);

  ThemeData get darkTheme =>
      buildTheme(appThemes[themeIndex.value].$2, brightness: Brightness.dark);

  ThemeMode get currentThemeMode {
    switch (themeMode.value) {
      case 1: return ThemeMode.light;
      case 2: return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  void dispose() {
    themeIndex.dispose();
    themeMode.dispose();
  }
}

class ThemeProvider extends InheritedWidget {
  final ThemeState state;
  const ThemeProvider({super.key, required this.state, required super.child});

  static ThemeState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>()!.state;
  }

  @override
  bool updateShouldNotify(ThemeProvider old) =>
      themeIndex != old.themeIndex || themeMode != old.themeMode;

  ValueNotifier<int> get themeIndex => state.themeIndex;
  ValueNotifier<int> get themeMode => state.themeMode;
}
