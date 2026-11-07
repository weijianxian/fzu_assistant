import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('旧存储键继续加载，所有设置类型均持久化，快速修改保存最新值', () async {
    SharedPreferences.setMockInitialValues({
      'selected_semester': '202501',
      'terms_list': '["202501"]',
      SpKeys.themeKey: 'unknown',
    });
    final settings = AppSettings();
    await settings.load();
    expect(settings.selectedSemesterKey.value, '202501');
    expect(settings.termsKey.value, ['202501']);
    expect(settings.themeKey.value, 'deep_purple');
    expect(settings.interfaceStyle.value, InterfaceStyle.classic);

    settings.localeKey.value = 'en';
    settings.themeModeKey.value = 'dark';
    settings.interfaceStyle.value = InterfaceStyle.cards;
    settings.selectedSemesterKey.value = '202601';
    settings.termsKey.value = ['202601', '202501'];
    settings.showExamOnSchedule.value = false;
    settings.showNonCurrentWeekCourses.value = true;
    settings.siteInjectionEnabled.value = false;
    settings.autoAdjustCourse.value = false;
    settings.west2AdjustmentsAccess.value = FeatureAccess.allow;
    settings.githubProxyEnabled.value = false;
    settings.githubProxyBaseUrl.value = 'https://proxy.example.com';
    settings.localeKey.value = 'zh';
    settings.localeKey.value = 'en';
    await Future<void>.delayed(Duration.zero);
    final reloaded = AppSettings();
    await reloaded.load();
    expect(reloaded.currentLocale, const Locale('en'));
    expect(reloaded.currentThemeMode, ThemeMode.dark);
    expect(reloaded.interfaceStyle.value, InterfaceStyle.cards);
    expect(
      reloaded.lightTheme.extension<InterfaceTheme>()!.style,
      InterfaceStyle.cards,
    );
    expect(
      reloaded.darkTheme.extension<InterfaceTheme>()!.style,
      InterfaceStyle.cards,
    );
    expect(reloaded.lightTheme.brightness, Brightness.light);
    expect(reloaded.darkTheme.brightness, Brightness.dark);
    expect(reloaded.selectedSemesterKey.value, '202601');
    expect(reloaded.termsKey.value, ['202601', '202501']);
    expect(reloaded.showExamOnSchedule.value, isFalse);
    expect(reloaded.showNonCurrentWeekCourses.value, isTrue);
    expect(reloaded.siteInjectionEnabled.value, isFalse);
    expect(reloaded.autoAdjustCourse.value, isFalse);
    expect(reloaded.useWest2Adjustments, isTrue);
    expect(reloaded.githubProxyEnabled.value, isFalse);
    expect(reloaded.githubProxyBaseUrl.value, 'https://proxy.example.com/');
    settings.dispose();
    reloaded.dispose();
  });

  test('unknown interface style falls back to classic', () async {
    SharedPreferences.setMockInitialValues({SpKeys.interfaceStyle: 'future'});
    final settings = AppSettings();
    await settings.load();
    expect(settings.interfaceStyle.value, InterfaceStyle.classic);
    settings.dispose();
  });

  test('custom and system color schemes retain the independent style', () {
    for (final brightness in Brightness.values) {
      for (final style in InterfaceStyle.values) {
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        );
        final theme = buildThemeFromScheme(scheme, interfaceStyle: style);
        expect(theme.colorScheme, scheme);
        expect(theme.brightness, brightness);
        expect(theme.extension<InterfaceTheme>()!.style, style);
        expect(theme.useMaterial3, isTrue);
      }
    }
  });
}
