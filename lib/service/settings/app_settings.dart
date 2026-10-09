import 'dart:async';
import 'dart:convert';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/common/utils/github_proxy.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';

class AppSettings {
  static const scheduleHomeStyle = 'schedule';
  static const timelineHomeStyle = 'timeline';
  static const timelineDayOptions = [1, 3, 7, 30];

  static ColorScheme? _systemLightScheme;
  static ColorScheme? _systemDarkScheme;
  static bool dynamicColorSupported = false;

  static ColorScheme? systemColorScheme(Brightness brightness) =>
      brightness == Brightness.dark ? _systemDarkScheme : _systemLightScheme;

  final themeKey = ValueNotifier<String>('deep_purple');
  final themeModeKey = ValueNotifier<String>('system');
  final localeKey = ValueNotifier<String>('system');

  // 首页
  final homeStyleKey = ValueNotifier<String>(scheduleHomeStyle);
  final timelineDaysKey = ValueNotifier<int>(1);

  // 学期相关
  final selectedSemesterKey = ValueNotifier<String>(''); // 空 = 自动当前学期
  final termsKey = ValueNotifier<List<String>>([]);

  // 网页注入
  final siteInjectionEnabled = ValueNotifier<bool>(true);

  // 课表显示考试
  final showExamOnSchedule = ValueNotifier<bool>(true);
  final showNonCurrentWeekCourses = ValueNotifier<bool>(false);
  final hiddenCourseSessions = ValueNotifier<List<HiddenCourseSession>>([]);

  // 自动调课
  final autoAdjustCourse = ValueNotifier<bool>(true);
  final west2AdjustmentsEnabled = ValueNotifier<bool>(false);

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

    final savedHomeStyle = sp.getString(SpKeys.homeStyle) ?? scheduleHomeStyle;
    homeStyleKey.value =
        {scheduleHomeStyle, timelineHomeStyle}.contains(savedHomeStyle)
        ? savedHomeStyle
        : scheduleHomeStyle;
    final savedTimelineDays = sp.getInt(SpKeys.timelineDays) ?? 1;
    timelineDaysKey.value = timelineDayOptions.contains(savedTimelineDays)
        ? savedTimelineDays
        : 1;

    // 学期相关
    selectedSemesterKey.value = sp.getString(SpKeys.selectedSemester) ?? '';

    // 网页注入
    siteInjectionEnabled.value =
        sp.getBool(SpKeys.siteInjectionEnabled) ?? true;

    // 课表显示考试
    showExamOnSchedule.value = sp.getBool(SpKeys.showExamOnSchedule) ?? true;
    showNonCurrentWeekCourses.value =
        sp.getBool(SpKeys.showNonCurrentWeekCourses) ?? false;

    // 自动调课
    autoAdjustCourse.value = sp.getBool(SpKeys.autoAdjustCourse) ?? true;
    west2AdjustmentsEnabled.value =
        sp.getBool(SpKeys.west2AdjustmentsEnabled) ?? false;

    // GitHub 代理
    githubProxyEnabled.value = sp.getBool(SpKeys.githubProxyEnabled) ?? true;
    githubProxyBaseUrl.value = GitHubProxy.normalizeBaseUrl(
      sp.getString(SpKeys.githubProxyBaseUrl) ?? GitHubProxy.defaultBaseUrl,
    );

    final termsRaw = sp.getString(SpKeys.termsList);
    if (termsRaw != null) {
      try {
        termsKey.value = List<String>.from(jsonDecode(termsRaw));
      } catch (_) {}
    }

    final hiddenRaw = sp.getString(SpKeys.hiddenCourseSessions);
    if (hiddenRaw != null) {
      try {
        final records = jsonDecode(hiddenRaw) as List;
        final loaded = <HiddenCourseSession>[];
        for (final record in records) {
          try {
            loaded.add(
              HiddenCourseSession.fromJson(
                Map<String, dynamic>.from(record as Map),
              ),
            );
          } catch (_) {
            // 单条损坏不影响其他隐藏记录。
          }
        }
        hiddenCourseSessions.value = loaded;
      } catch (_) {}
    }
    // 使用已经加载的 SP 实例，统一绑定持久化。
    for (final entry in {
      SpKeys.themeKey: themeKey,
      SpKeys.themeMode: themeModeKey,
      SpKeys.localeKey: localeKey,
      SpKeys.homeStyle: homeStyleKey,
      SpKeys.selectedSemester: selectedSemesterKey,
    }.entries) {
      _persist(entry.value, (value) => sp.setString(entry.key, value));
    }
    for (final entry in {
      SpKeys.siteInjectionEnabled: siteInjectionEnabled,
      SpKeys.showExamOnSchedule: showExamOnSchedule,
      SpKeys.showNonCurrentWeekCourses: showNonCurrentWeekCourses,
      SpKeys.autoAdjustCourse: autoAdjustCourse,
      SpKeys.west2AdjustmentsEnabled: west2AdjustmentsEnabled,
      SpKeys.githubProxyEnabled: githubProxyEnabled,
    }.entries) {
      _persist(entry.value, (value) => sp.setBool(entry.key, value));
    }
    _persist(timelineDaysKey, (value) => sp.setInt(SpKeys.timelineDays, value));
    _persist(
      termsKey,
      (value) => sp.setString(SpKeys.termsList, jsonEncode(value)),
    );
    _persist(
      githubProxyBaseUrl,
      (value) => sp.setString(
        SpKeys.githubProxyBaseUrl,
        GitHubProxy.normalizeBaseUrl(value),
      ),
    );
    _persist(
      hiddenCourseSessions,
      (value) => sp.setString(
        SpKeys.hiddenCourseSessions,
        jsonEncode(value.map((s) => s.toJson()).toList()),
      ),
    );
  }

  static void _persist<T>(
    ValueNotifier<T> notifier,
    Future<bool> Function(T) write,
  ) {
    notifier.addListener(() => unawaited(write(notifier.value)));
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

  void hideCourseSession(HiddenCourseSession session) {
    if (hiddenCourseSessions.value.any((s) => s.key == session.key)) return;
    hiddenCourseSessions.value = [...hiddenCourseSessions.value, session];
  }

  void restoreCourseSession(HiddenCourseSession session) {
    hiddenCourseSessions.value = hiddenCourseSessions.value
        .where((s) => s.key != session.key)
        .toList();
  }

  void restoreAllCourseSessions(String account) {
    hiddenCourseSessions.value = hiddenCourseSessions.value
        .where((s) => s.account != account)
        .toList();
  }

  ThemeData get lightTheme => _buildTheme(Brightness.light);
  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = systemColorScheme(brightness);
    if (themeKey.value == 'dynamic' && scheme != null) {
      return buildThemeFromScheme(scheme);
    }
    final match = appThemes.where((t) => t.key == themeKey.value);
    final color = match.isNotEmpty ? match.first.color : appThemes.first.color;
    return buildTheme(color, brightness: brightness);
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
    homeStyleKey.dispose();
    timelineDaysKey.dispose();
    selectedSemesterKey.dispose();
    termsKey.dispose();
    siteInjectionEnabled.dispose();
    showExamOnSchedule.dispose();
    showNonCurrentWeekCourses.dispose();
    hiddenCourseSessions.dispose();
    autoAdjustCourse.dispose();
    west2AdjustmentsEnabled.dispose();
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
