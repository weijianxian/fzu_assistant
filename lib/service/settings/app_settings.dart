import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/screen/settings/theme/app_themes.dart';

class AppSettings {
  final themeKey = ValueNotifier<String>('deep_purple');
  final themeModeKey = ValueNotifier<String>('system');
  final localeKey = ValueNotifier<String>('system');

  static const _modeMap = {
    'system': ThemeMode.system,
    'light': ThemeMode.light,
    'dark': ThemeMode.dark,
  };

  static const _localeOptions = [
    ('system', null, 'System'),
    ('zh', Locale('zh'), '中文'),
    ('en', Locale('en'), 'English'),
  ];

  static String labelOf(String key) => _localeOptions
      .firstWhere((o) => o.$1 == key, orElse: () => _localeOptions.first)
      .$3;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();

    final savedTheme = sp.getString(SpKeys.themeKey) ?? 'deep_purple';
    final validTheme = appThemes.any((t) => t.key == savedTheme);
    themeKey.value = validTheme ? savedTheme : 'deep_purple';

    final savedMode = sp.getString(SpKeys.themeMode) ?? 'system';
    final validMode = _modeMap.containsKey(savedMode);
    themeModeKey.value = validMode ? savedMode : 'system';

    final savedLocale = sp.getString(SpKeys.localeKey) ?? 'system';
    final validLocale = _localeOptions.any((o) => o.$1 == savedLocale);
    localeKey.value = validLocale ? savedLocale : 'system';

    themeKey.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) => sp.setString(SpKeys.themeKey, themeKey.value),
      );
    });
    themeModeKey.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) => sp.setString(SpKeys.themeMode, themeModeKey.value),
      );
    });
    localeKey.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) => sp.setString(SpKeys.localeKey, localeKey.value),
      );
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

  ThemeMode get currentThemeMode =>
      _modeMap[themeModeKey.value] ?? ThemeMode.system;

  Locale? get currentLocale {
    final match = _localeOptions.where((o) => o.$1 == localeKey.value);
    return match.isNotEmpty ? match.first.$2 : null;
  }

  void dispose() {
    themeKey.dispose();
    themeModeKey.dispose();
    localeKey.dispose();
  }
}

class AppSettingsProvider extends InheritedWidget {
  final AppSettings settings;
  const AppSettingsProvider({
    super.key,
    required this.settings,
    required super.child,
  });

  static AppSettings of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppSettingsProvider>()!
        .settings;
  }

  @override
  bool updateShouldNotify(AppSettingsProvider old) => false;
}
