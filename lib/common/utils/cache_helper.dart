import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/common/utils/widget_preference_bridge.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';

/// SharedPreferences 按 key 存取 JSON Map 的泛型工具。
abstract final class CacheHelper {
  static final changes = ValueNotifier<int>(0);

  /// 读取 [spKey] 对应的 JSON Map；不存在则返回空 Map。
  static Future<Map<String, dynamic>> loadMap(String spKey) async {
    final sp = await SharedPreferences.getInstance();
    if (WidgetPreferenceBridge.nativeSupported) await sp.reload();
    final raw = sp.getString(spKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  /// 将整个 [map] 写入 [spKey]。
  static Future<void> saveMap(String spKey, Map<String, dynamic> map) async {
    final sp = await SharedPreferences.getInstance();
    await WidgetPreferenceBridge.write(sp, spKey, jsonEncode(map));
    changes.value++;
  }

  /// 从 [spKey] 的 Map 中读取 [termKey] 对应的条目，用 [fromJson] 反序列化。
  static Future<T?> loadForKey<T>(
    String spKey,
    String termKey,
    T Function(dynamic json) fromJson,
  ) async {
    final map = await loadMap(spKey);
    final entry = map[termKey];
    if (entry == null) return null;
    return fromJson(entry);
  }

  /// 将 [value] 序列化后存入 [spKey] Map 的 [termKey] 条目。
  static Future<void> saveForKey(
    String spKey,
    String termKey,
    dynamic value,
  ) async {
    if (WidgetPreferenceBridge.nativeSupported &&
        (spKey == SpKeys.cacheCoursesMap ||
            spKey == SpKeys.cacheHolidayAdjustmentsMap)) {
      await WidgetPreferenceBridge.writeCacheTerm(
        await SharedPreferences.getInstance(),
        spKey,
        termKey,
        jsonEncode(value),
      );
      changes.value++;
      return;
    }
    final map = await loadMap(spKey);
    map[termKey] = value;
    await saveMap(spKey, map);
  }

  /// 整份删除 [spKeys] 指定的缓存（含其中所有学期分片）。
  static Future<void> removeAll(Iterable<String> spKeys) async {
    final sp = await SharedPreferences.getInstance();
    for (final key in spKeys) {
      await WidgetPreferenceBridge.write(sp, key, null);
    }
    changes.value++;
  }
}
