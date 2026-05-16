import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/theme/app_themes.dart';

class ThemeState {
  final themeKey = ValueNotifier<String>('deep_purple');
  final themeModeKey = ValueNotifier<String>('system');

  static const _modeMap = {
    'system': ThemeMode.system,
    'light': ThemeMode.light,
    'dark': ThemeMode.dark,
  };

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();

    final savedTheme = sp.getString(SpKeys.themeKey) ?? 'deep_purple';
    final validTheme = appThemes.any((t) => t.key == savedTheme);
    themeKey.value = validTheme ? savedTheme : 'deep_purple';

    final savedMode = sp.getString(SpKeys.themeMode) ?? 'system';
    final validMode = _modeMap.containsKey(savedMode);
    themeModeKey.value = validMode ? savedMode : 'system';

    themeKey.addListener(() {
      SharedPreferences.getInstance().then((sp) => sp.setString(SpKeys.themeKey, themeKey.value));
    });
    themeModeKey.addListener(() {
      SharedPreferences.getInstance().then((sp) => sp.setString(SpKeys.themeMode, themeModeKey.value));
    });
  }

  ThemeData get lightTheme {
    final match = appThemes.where((t) => t.key == themeKey.value);
    final color = match.isNotEmpty ? match.first.color : appThemes.first.color;
    return buildTheme(color, brightness: Brightness.light);
  }

  ThemeData get darkTheme {
    final match = appThemes.where((t) => t.key == themeKey.value);
    final color = match.isNotEmpty ? match.first.color : appThemes.first.color;
    return buildTheme(color, brightness: Brightness.dark);
  }

  ThemeMode get currentThemeMode => _modeMap[themeModeKey.value] ?? ThemeMode.system;

  void dispose() {
    themeKey.dispose();
    themeModeKey.dispose();
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
      themeKey != old.themeKey || themeModeKey != old.themeModeKey;

  ValueNotifier<String> get themeKey => state.themeKey;
  ValueNotifier<String> get themeModeKey => state.themeModeKey;
}
