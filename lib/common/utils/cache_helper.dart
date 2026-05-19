import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 按 key 存取 JSON Map 的泛型工具。
abstract final class CacheHelper {
  /// 读取 [spKey] 对应的 JSON Map；不存在则返回空 Map。
  static Future<Map<String, dynamic>> loadMap(String spKey) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(spKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  /// 将整个 [map] 写入 [spKey]。
  static Future<void> saveMap(String spKey, Map<String, dynamic> map) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(spKey, jsonEncode(map));
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
  static Future<void> saveForKey<T>(
    String spKey,
    String termKey,
    dynamic value,
  ) async {
    final map = await loadMap(spKey);
    map[termKey] = value;
    await saveMap(spKey, map);
  }
}
