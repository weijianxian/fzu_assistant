import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fzu_assistant/model/feature_access.dart';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/common/utils/github_proxy.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';
import 'package:fzu_assistant/common/utils/widget_preference_bridge.dart';
import 'package:fzu_assistant/service/theme_customization_service.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

class AppSettings {
  AppSettings({ThemeCustomizationService? themeStore})
    : themeStore = themeStore ?? ThemeCustomizationService.instance;

  final ThemeCustomizationService themeStore;
  final customThemes = ValueNotifier<List<ThemeProfile>>([]);
  final activeCustomTheme = ValueNotifier<ThemeProfile?>(null);
  final customThemeError = ValueNotifier<String?>(null);
  final systemColorRevision = ValueNotifier<int>(0);
  Future<void>? _themesLoading;
  bool _disposed = false;
  int _themeSelectionRevision = 0;
  int _themeLibraryRevision = 0;

  static ColorScheme? _systemLightScheme;
  static ColorScheme? _systemDarkScheme;
  static bool dynamicColorSupported = false;

  static ColorScheme? systemColorScheme(Brightness brightness) =>
      brightness == Brightness.dark ? _systemDarkScheme : _systemLightScheme;

  final themeKey = ValueNotifier<String>('deep_purple');
  final themeModeKey = ValueNotifier<String>('system');
  final interfaceStyle = ValueNotifier<InterfaceStyle>(InterfaceStyle.cards);
  final localeKey = ValueNotifier<String>('system');
  final courseReminderEnabled = ValueNotifier<bool>(false);
  final courseReminderMinutes = ValueNotifier<int>(21 * 60);

  // 首页

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
  final west2AdjustmentsAccess = ValueNotifier<FeatureAccess>(
    FeatureAccess.tip,
  );
  final papersAccess = ValueNotifier<FeatureAccess>(FeatureAccess.tip);
  bool get useWest2Adjustments =>
      west2AdjustmentsAccess.value == FeatureAccess.allow;

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
    final selectionRevision = _themeSelectionRevision;
    final sp = await SharedPreferences.getInstance();
    if (_disposed) return;
    courseReminderEnabled.value =
        sp.getBool(SpKeys.courseReminderEnabled) ?? false;
    courseReminderMinutes.value =
        (sp.getInt(SpKeys.courseReminderMinutes) ?? 21 * 60).clamp(0, 1439);

    final savedTheme = sp.getString(SpKeys.themeKey) ?? 'deep_purple';
    final validTheme =
        savedTheme == 'dynamic' || appThemes.any((t) => t.key == savedTheme);
    themeKey.value = validTheme ? savedTheme : 'deep_purple';
    final customId = sp.getString(SpKeys.activeCustomTheme);
    if (customId?.isNotEmpty == true) {
      try {
        final loaded = await themeStore.load(customId!);
        if (_disposed) return;
        if (_themeSelectionRevision == selectionRevision) {
          activeCustomTheme.value = loaded;
        }
      } catch (error) {
        if (_disposed) return;
        customThemeError.value = error.toString();
      }
    }
    _persist(
      activeCustomTheme,
      (value) => value == null
          ? sp.remove(SpKeys.activeCustomTheme)
          : sp.setString(SpKeys.activeCustomTheme, value.id),
    );

    final savedMode = sp.getString(SpKeys.themeMode) ?? 'system';
    final validMode = _modeMap.containsKey(savedMode);
    themeModeKey.value = validMode ? savedMode : 'system';
    interfaceStyle.value = InterfaceStyle.parse(
      sp.getString(SpKeys.interfaceStyle),
    );
    _persist(
      interfaceStyle,
      (value) => sp.setString(SpKeys.interfaceStyle, value.name),
    );

    final savedLocale = sp.getString(SpKeys.localeKey) ?? 'system';
    final validLocale = _localeOptions.any((o) => o.$1 == savedLocale);
    localeKey.value = validLocale ? savedLocale : 'system';

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
    west2AdjustmentsAccess.value = sp.containsKey(SpKeys.west2AdjustmentsAccess)
        ? FeatureAccess.parse(sp.getString(SpKeys.west2AdjustmentsAccess))
        : (sp.getBool(SpKeys.west2AdjustmentsEnabled) == true
              ? FeatureAccess.allow
              : FeatureAccess.tip);
    papersAccess.value = FeatureAccess.parse(sp.getString(SpKeys.papersAccess));
    _persist(
      west2AdjustmentsAccess,
      (value) => WidgetPreferenceBridge.write(
        sp,
        SpKeys.west2AdjustmentsAccess,
        value.name,
      ),
    );
    _persist(
      papersAccess,
      (value) => sp.setString(SpKeys.papersAccess, value.name),
    );

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
      SpKeys.selectedSemester: selectedSemesterKey,
    }.entries) {
      _persist(
        entry.value,
        (value) => WidgetPreferenceBridge.write(sp, entry.key, value),
      );
    }
    for (final entry in {
      SpKeys.siteInjectionEnabled: siteInjectionEnabled,
      SpKeys.courseReminderEnabled: courseReminderEnabled,
      SpKeys.showExamOnSchedule: showExamOnSchedule,
      SpKeys.showNonCurrentWeekCourses: showNonCurrentWeekCourses,
      SpKeys.autoAdjustCourse: autoAdjustCourse,
      SpKeys.githubProxyEnabled: githubProxyEnabled,
    }.entries) {
      _persist(
        entry.value,
        (value) => WidgetPreferenceBridge.write(sp, entry.key, value),
      );
    }
    _persist(
      courseReminderMinutes,
      (value) => sp.setInt(SpKeys.courseReminderMinutes, value),
    );
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
      (value) => WidgetPreferenceBridge.write(
        sp,
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

  Future<void> loadCustomThemes() {
    return _themesLoading ??= _loadCustomThemes().whenComplete(
      () => _themesLoading = null,
    );
  }

  Future<void> _loadCustomThemes() async {
    final libraryRevision = _themeLibraryRevision;
    try {
      final profiles = await themeStore.loadAll();
      if (_disposed) return;
      if (_themeLibraryRevision == libraryRevision) {
        customThemes.value = profiles;
      }
      customThemeError.value = null;
    } catch (error) {
      if (!_disposed) customThemeError.value = error.toString();
    }
  }

  /// Preset keys stay portable; local images and custom IDs never enter WebDAV.
  void selectPresetTheme(String key) {
    _themeSelectionRevision++;
    activeCustomTheme.value = null;
    themeKey.value = key;
  }

  void activateCustomTheme(ThemeProfile profile) {
    _themeSelectionRevision++;
    activeCustomTheme.value = profile;
  }

  void _updateCustomTheme(ThemeProfile profile) {
    _themeLibraryRevision++;
    final profiles = [
      for (final entry in customThemes.value)
        if (entry.id != profile.id) entry,
      profile,
    ]..sort((a, b) => a.name.compareTo(b.name));
    customThemes.value = List.unmodifiable(profiles);
  }

  Future<ThemeProfile> saveCustomTheme(
    ThemeProfile profile, {
    bool apply = true,
  }) async {
    final shouldApply = apply || activeCustomTheme.value?.id == profile.id;
    final selectionRevision = shouldApply
        ? ++_themeSelectionRevision
        : _themeSelectionRevision;
    final saved = await themeStore.save(profile);
    if (!_disposed) {
      _updateCustomTheme(saved);
      if (shouldApply && _themeSelectionRevision == selectionRevision) {
        activeCustomTheme.value = saved;
      }
    }
    return saved;
  }

  Future<ThemeProfile> importCustomTheme(File source) async {
    final saved = await themeStore.importTheme(source);
    if (!_disposed) _updateCustomTheme(saved);
    return saved;
  }

  Future<void> deleteCustomTheme(String id) async {
    await themeStore.delete(id);
    if (_disposed) return;
    _themeLibraryRevision++;
    if (activeCustomTheme.value?.id == id) {
      _themeSelectionRevision++;
      activeCustomTheme.value = null;
    }
    customThemes.value = List.unmodifiable(
      customThemes.value.where((profile) => profile.id != id),
    );
  }

  Future<void> initDynamicColor() async {
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (_disposed) return;
      if (corePalette != null) {
        _systemLightScheme = corePalette.toColorScheme();
        _systemDarkScheme = corePalette.toColorScheme(
          brightness: Brightness.dark,
        );
        dynamicColorSupported = true;
        systemColorRevision.value++;
        return;
      }
    } catch (_) {}
    if (_disposed) return;
    try {
      final accentColor = await DynamicColorPlugin.getAccentColor();
      if (_disposed) return;
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
        systemColorRevision.value++;
        return;
      }
    } catch (_) {}
    if (_disposed) return;
    _systemLightScheme = null;
    _systemDarkScheme = null;
    dynamicColorSupported = false;
    systemColorRevision.value++;
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
    final profile = activeCustomTheme.value;
    if (profile != null) return buildProfileTheme(profile, brightness);
    final scheme = systemColorScheme(brightness);
    if (themeKey.value == 'dynamic' && scheme != null) {
      return buildThemeFromScheme(scheme, interfaceStyle: interfaceStyle.value);
    }
    final match = appThemes.where((t) => t.key == themeKey.value);
    final color = match.isNotEmpty ? match.first.color : appThemes.first.color;
    return buildTheme(
      color,
      brightness: brightness,
      interfaceStyle: interfaceStyle.value,
    );
  }

  ThemeData buildProfileTheme(ThemeProfile profile, Brightness brightness) {
    final variant = brightness == Brightness.dark
        ? profile.dark
        : profile.light;
    final base = appThemes
        .where((theme) => theme.key == profile.baseThemeKey)
        .firstOrNull;
    final source =
        variant.colorSource ??
        (profile.baseThemeKey == 'dynamic' ? 'system' : 'seed');
    final scheme = source == 'system' ? systemColorScheme(brightness) : null;
    final visuals = ThemeVisuals(
      colors: variant.colors.map((key, argb) => MapEntry(key, Color(argb))),
      coursePaletteKey: variant.coursePaletteKey,
      coursePalette: variant.coursePalette
          .map(Color.new)
          .toList(growable: false),
      backgroundImage: variant.backgroundImagePath,
      backgroundDim: variant.backgroundDim,
      backgroundBlur: variant.backgroundBlur,
      surfaceOpacity: variant.surfaceOpacity,
      courseCardOpacity: variant.courseCardOpacity,
      cardRadius: variant.cardRadius,
      courseCardRadius: variant.courseCardRadius,
      dividerWidth: variant.dividerWidth,
    );
    return buildThemeFromScheme(
      scheme ??
          ColorScheme.fromSeed(
            seedColor: variant.seedColor != null
                ? Color(variant.seedColor!)
                : base?.color ?? appThemes.first.color,
            brightness: brightness,
          ),
      interfaceStyle: interfaceStyle.value,
      visuals: visuals,
    );
  }

  ThemeMode get currentThemeMode =>
      _modeMap[themeModeKey.value] ?? ThemeMode.system;

  Locale? get currentLocale {
    final match = _localeOptions.where((o) => o.$1 == localeKey.value);
    return match.isNotEmpty ? match.first.$2 : null;
  }

  void dispose() {
    _disposed = true;
    customThemes.dispose();
    activeCustomTheme.dispose();
    customThemeError.dispose();
    systemColorRevision.dispose();
    courseReminderEnabled.dispose();
    courseReminderMinutes.dispose();
    themeKey.dispose();
    themeModeKey.dispose();
    interfaceStyle.dispose();
    localeKey.dispose();
    selectedSemesterKey.dispose();
    termsKey.dispose();
    siteInjectionEnabled.dispose();
    showExamOnSchedule.dispose();
    showNonCurrentWeekCourses.dispose();
    hiddenCourseSessions.dispose();
    autoAdjustCourse.dispose();
    west2AdjustmentsAccess.dispose();
    papersAccess.dispose();
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
