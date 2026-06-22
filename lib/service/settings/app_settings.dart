import 'dart:convert';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/common/utils/github_proxy.dart';
import 'package:fzu_assistant/service/app_themes.dart';

class AppSettings {
  static ColorScheme? _systemLightScheme;
  static ColorScheme? _systemDarkScheme;
  static bool dynamicColorSupported = false;

  static ColorScheme? systemColorScheme(Brightness brightness) =>
      brightness == Brightness.dark ? _systemDarkScheme : _systemLightScheme;

  final themeKey = ValueNotifier<String>('deep_purple');
  final themeModeKey = ValueNotifier<String>('system');
  final localeKey = ValueNotifier<String>('system');

  // 学期相关
  final selectedSemesterKey = ValueNotifier<String>(''); // 空 = 自动当前学期
  final termsKey = ValueNotifier<List<String>>([]);

  // 网页注入
  final siteInjectionEnabled = ValueNotifier<bool>(true);

  // 课表显示考试
  final showExamOnSchedule = ValueNotifier<bool>(true);

  // 自动调课
  final autoAdjustCourse = ValueNotifier<bool>(true);

  // GitHub 代理
  final githubProxyEnabled = ValueNotifier<bool>(true);
  final githubProxyBaseUrl = ValueNotifier<String>(GitHubProxy.defaultBaseUrl);

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
    final validTheme =
        savedTheme == 'dynamic' || appThemes.any((t) => t.key == savedTheme);
    themeKey.value = validTheme ? savedTheme : 'deep_purple';

    final savedMode = sp.getString(SpKeys.themeMode) ?? 'system';
    final validMode = _modeMap.containsKey(savedMode);
    themeModeKey.value = validMode ? savedMode : 'system';

    final savedLocale = sp.getString(SpKeys.localeKey) ?? 'system';
    final validLocale = _localeOptions.any((o) => o.$1 == savedLocale);
    localeKey.value = validLocale ? savedLocale : 'system';

    // 学期相关
    selectedSemesterKey.value = sp.getString('selected_semester') ?? '';

    // 网页注入
    siteInjectionEnabled.value =
        sp.getBool(SpKeys.siteInjectionEnabled) ?? true;

    // 课表显示考试
    showExamOnSchedule.value = sp.getBool(SpKeys.showExamOnSchedule) ?? true;

    // 自动调课
    autoAdjustCourse.value = sp.getBool(SpKeys.autoAdjustCourse) ?? true;

    // GitHub 代理
    githubProxyEnabled.value = sp.getBool(SpKeys.githubProxyEnabled) ?? true;
    githubProxyBaseUrl.value = GitHubProxy.normalizeBaseUrl(
      sp.getString(SpKeys.githubProxyBaseUrl) ?? GitHubProxy.defaultBaseUrl,
    );

    final termsRaw = sp.getString('terms_list');
    if (termsRaw != null) {
      try {
        termsKey.value = List<String>.from(jsonDecode(termsRaw));
      } catch (_) {}
    }

    // 持久化 listeners
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
    selectedSemesterKey.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) => sp.setString('selected_semester', selectedSemesterKey.value),
      );
    });
    termsKey.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) => sp.setString('terms_list', jsonEncode(termsKey.value)),
      );
    });
    siteInjectionEnabled.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) =>
            sp.setBool(SpKeys.siteInjectionEnabled, siteInjectionEnabled.value),
      );
    });
    showExamOnSchedule.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) => sp.setBool(SpKeys.showExamOnSchedule, showExamOnSchedule.value),
      );
    });
    autoAdjustCourse.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) => sp.setBool(SpKeys.autoAdjustCourse, autoAdjustCourse.value),
      );
    });
    githubProxyEnabled.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) => sp.setBool(SpKeys.githubProxyEnabled, githubProxyEnabled.value),
      );
    });
    githubProxyBaseUrl.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) => sp.setString(
          SpKeys.githubProxyBaseUrl,
          GitHubProxy.normalizeBaseUrl(githubProxyBaseUrl.value),
        ),
      );
    });
  }

  Future<void> initDynamicColor() async {
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette != null) {
        _systemLightScheme = corePalette.toColorScheme();
        _systemDarkScheme = corePalette.toColorScheme(
          brightness: Brightness.dark,
        );
        dynamicColorSupported = true;
        return;
      }
    } catch (_) {}
    try {
      final accentColor = await DynamicColorPlugin.getAccentColor();
      if (accentColor != null) {
        _systemLightScheme = ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
        );
        _systemDarkScheme = ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.dark,
        );
        dynamicColorSupported = true;
        return;
      }
    } catch (_) {}
    dynamicColorSupported = false;
    if (themeKey.value == 'dynamic') themeKey.value = 'deep_purple';
  }

  ThemeData get lightTheme {
    if (themeKey.value == 'dynamic' && _systemLightScheme != null) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: _systemLightScheme,
        splashFactory: NoSplash.splashFactory,
        appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
      );
    }
    final match = appThemes.where((t) => t.key == themeKey.value);
    final color = match.isNotEmpty ? match.first.color : appThemes.first.color;
    return buildTheme(color, brightness: Brightness.light);
  }

  ThemeData get darkTheme {
    if (themeKey.value == 'dynamic' && _systemDarkScheme != null) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _systemDarkScheme,
        splashFactory: NoSplash.splashFactory,
        appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
      );
    }
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
    selectedSemesterKey.dispose();
    termsKey.dispose();
    siteInjectionEnabled.dispose();
    showExamOnSchedule.dispose();
    autoAdjustCourse.dispose();
    githubProxyEnabled.dispose();
    githubProxyBaseUrl.dispose();
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
