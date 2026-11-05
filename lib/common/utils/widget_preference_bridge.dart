import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foreground writes affecting widgets share the native background commit lock.
abstract final class WidgetPreferenceBridge {
  static bool get nativeSupported => Platform.isAndroid;
  static const _channel = MethodChannel(
    'com.weijx.fzu_assistant/widget_background',
  );
  static const inputKeys = {
    'cache_school_calendar',
    'cache_courses_map',
    'cache_holiday_adjustments_map',
    'custom_courses_v1',
    'hidden_course_sessions',
    'auto_adjust_course',
    'west2_adjustments_access',
    'west2_adjustments_enabled',
    'locale_key',
  };

  static Future<bool> write(
    SharedPreferences preferences,
    String key,
    Object? value,
  ) async {
    if (nativeSupported && inputKeys.contains(key)) {
      try {
        final saved = await _channel.invokeMethod<bool>('writeInputs', {
          'writes': {key: value},
        });
        if (saved != true) throw StateError('无法保存小组件相关设置');
        await preferences.reload();
        return true;
      } on MissingPluginException {
        // Compatibility with an older Android host during development.
      }
    }
    return switch (value) {
      String() => preferences.setString(key, value),
      bool() => preferences.setBool(key, value),
      int() => preferences.setInt(key, value),
      double() => preferences.setDouble(key, value),
      List<String>() => preferences.setStringList(key, value),
      null => preferences.remove(key),
      _ => throw ArgumentError.value(value, key),
    };
  }

  static Future<bool> writeCacheTerm(
    SharedPreferences preferences,
    String key,
    String term,
    String value,
  ) async {
    final saved = await _channel.invokeMethod<bool>('writeCacheTerm', {
      'key': key,
      'term': term,
      'value': value,
    });
    if (saved != true) throw StateError('无法保存课程缓存');
    await preferences.reload();
    return true;
  }
}
