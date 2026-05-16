import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/theme/app_themes.dart';

class ThemeState {
  final themeIndex = ValueNotifier<int>(0);
  final themeMode = ValueNotifier<int>(0); // 0=跟随系统, 1=浅色, 2=深色
  static const _defaultThemeKey = 'deep_purple';
  static const _defaultMode = 0;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();

    final savedKey = sp.getString(SpKeys.themeKey) ?? _defaultThemeKey;
    final idx = appThemes.indexWhere((t) => t.key == savedKey);
    themeIndex.value = idx >= 0 ? idx : 0;

    final mode = sp.getInt(SpKeys.themeMode) ?? _defaultMode;
    if (mode >= 0 && mode <= 2) themeMode.value = mode;

    themeIndex.addListener(() {
      final key = appThemes[themeIndex.value].key;
      SharedPreferences.getInstance().then((sp) => sp.setString(SpKeys.themeKey, key));
    });
    themeMode.addListener(() =>
        SharedPreferences.getInstance().then((sp) => sp.setInt(SpKeys.themeMode, themeMode.value)));
  }

  ThemeData get lightTheme =>
      buildTheme(appThemes[themeIndex.value].color, brightness: Brightness.light);

  ThemeData get darkTheme =>
      buildTheme(appThemes[themeIndex.value].color, brightness: Brightness.dark);

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
