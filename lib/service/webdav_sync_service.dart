import 'dart:convert';

import 'package:fzu_assistant/common/utils/widget_preference_bridge.dart';

import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/common/utils/github_proxy.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebDavConfig {
  const WebDavConfig({
    required this.directory,
    required this.username,
    required this.password,
  });
  final String directory, username, password;

  Uri get fileUri {
    final uri = Uri.tryParse(directory.trim());
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('请输入有效的 WebDAV 目录地址，不要包含账号、查询参数或片段');
    }
    final folder = uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
    return folder.resolve(WebDavSyncService.fileName);
  }
}

class WebDavSnapshot {
  WebDavSnapshot._({
    required this.createdAt,
    required Map<String, Object> values,
  }) : values = Map.unmodifiable(values);
  final DateTime createdAt;
  final Map<String, Object> values;

  /// Timestamps and JSON key ordering do not represent changes to user data.
  String get fingerprint {
    Object? canonical(Object? value) {
      if (value is Map) {
        final keys = value.keys.cast<String>().toList()..sort();
        return {for (final key in keys) key: canonical(value[key])};
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    final content = {
      ...values,
      for (final key in [
        CustomCourseStore.storageKey,
        SpKeys.hiddenCourseSessions,
      ])
        key: jsonDecode(values[key] as String),
    };
    return sha256
        .convert(utf8.encode(jsonEncode(canonical(content))))
        .toString();
  }

  int get customCourseCount => (jsonDecode(
    values[CustomCourseStore.storageKey] as String,
  ) as List).length;
  int get hiddenCourseCount => (jsonDecode(
    values[SpKeys.hiddenCourseSessions] as String,
  ) as List).length;

  Map<String, Object> toJson() => {
    'format': WebDavSyncService.format,
    'version': 1,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'values': values,
  };

  factory WebDavSnapshot.fromJson(Object? source) {
    if (source is! Map ||
        source['format'] != WebDavSyncService.format ||
        source['version'] != 1 ||
        source['createdAt'] is! String ||
        source['values'] is! Map) {
      throw const FormatException('WebDAV 同步文件格式或版本不受支持');
    }
    final createdAt = DateTime.tryParse(source['createdAt'] as String);
    if (createdAt == null) throw const FormatException('WebDAV 同步文件时间无效');
    final raw = source['values'] as Map;
    if (raw.keys.any((key) => !WebDavSyncService.defaults.containsKey(key)) ||
        WebDavSyncService.defaults.keys.any(
          (key) => key != SpKeys.interfaceStyle && !raw.containsKey(key),
        )) {
      throw const FormatException('WebDAV 同步文件设置不完整或含有非同步字段');
    }
    final values = <String, Object>{};
    for (final entry in WebDavSyncService.defaults.entries) {
      // Backups created before interface styles still restore as classic.
      final value =
          entry.key == SpKeys.interfaceStyle && !raw.containsKey(entry.key)
          ? entry.value
          : raw[entry.key];
      if ((entry.value is String && value is! String) ||
          (entry.value is bool && value is! bool) ||
          (entry.value is int && value is! int)) {
        throw const FormatException('WebDAV 同步文件设置类型无效');
      }
      values[entry.key] = value as Object;
    }
    if (!(values[SpKeys.themeKey] == 'dynamic' ||
            appThemes.any((theme) => theme.key == values[SpKeys.themeKey])) ||
        !{'system', 'light', 'dark'}.contains(values[SpKeys.themeMode]) ||
        !InterfaceStyle.values.any(
          (style) => style.name == values[SpKeys.interfaceStyle],
        ) ||
        !{'system', 'zh', 'en'}.contains(values[SpKeys.localeKey]) ||
        (values[SpKeys.courseReminderMinutes] as int) < 0 ||
        (values[SpKeys.courseReminderMinutes] as int) > 1439 ||
        !RegExp(r'^(?:\d{6})?$')
            .hasMatch(values[SpKeys.selectedSemester] as String) ||
        !FeatureAccess.values.any(
          (value) => value.name == values[SpKeys.west2AdjustmentsAccess],
        ) ||
        !FeatureAccess.values.any(
          (value) => value.name == values[SpKeys.papersAccess],
        )) {
      throw const FormatException('WebDAV 同步文件设置值无效');
    }
    final proxy = Uri.tryParse(values[SpKeys.githubProxyBaseUrl] as String);
    if (proxy == null ||
        !{'http', 'https'}.contains(proxy.scheme) ||
        proxy.host.isEmpty ||
        proxy.userInfo.isNotEmpty) {
      throw const FormatException('WebDAV 同步文件代理地址无效');
    }
    try {
      CustomCourse.parseList(
        jsonDecode(values[CustomCourseStore.storageKey] as String),
      );
      final hidden = jsonDecode(values[SpKeys.hiddenCourseSessions] as String);
      if (hidden is! List) throw const FormatException('隐藏课程必须为列表');
      final keys = <String>{};
      for (final record in hidden) {
        final session = HiddenCourseSession.fromJson(
          Map<String, dynamic>.from(record as Map),
        );
        if (session.week > CustomCourse.maxWeek ||
            session.endClass > CustomCourse.maxPeriod ||
            !keys.add(session.key)) {
          throw const FormatException('隐藏课程记录重复或范围无效');
        }
      }
    } catch (_) {
      throw const FormatException('WebDAV 同步文件课程记录无效');
    }
    return WebDavSnapshot._(createdAt: createdAt, values: values);
  }
}

class WebDavRemote {
  const WebDavRemote({required this.snapshot, this.etag});
  final WebDavSnapshot? snapshot;
  final String? etag;
}

enum WebDavAutoSyncResult {
  skipped,
  unchanged,
  uploaded,
  downloaded,
  conflict,
  manualUploadRequired,
}

class WebDavLocalChanged implements Exception {
  @override
  String toString() => '本地数据已改变，请重新同步';
}

class _WebDavNetworkFailure implements Exception {
  const _WebDavNetworkFailure();

  @override
  String toString() => '无法连接 WebDAV，请检查目录地址、网络和服务器状态';
}

/// A strict whitelist keeps authentication data and caches off WebDAV.
class WebDavSyncService {
  static final instance = WebDavSyncService();
  static bool _operationActive = false;
  static int _configurationRevision = 0;
  WebDavSyncService({Dio? dio, FlutterSecureStorage? storage})
    : dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 20))),
      storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );
  final Dio dio;
  final FlutterSecureStorage storage;
  static const fileName = 'fzu-assistant-sync.json';
  static const format = 'fzu-assistant-settings';
  static const maxBytes = 5 * 1024 * 1024;
  static const _directoryKey = 'webdav_directory';
  static const _usernameKey = 'webdav_username';
  static const _passwordKey = 'fzu_webdav_password';
  static const _autoSyncKey = 'webdav_auto_sync';
  static const _baselineKey = 'webdav_sync_baseline';
  static const defaults = <String, Object>{
    SpKeys.themeKey: 'deep_purple',
    SpKeys.themeMode: 'system',
    SpKeys.interfaceStyle: 'classic',
    SpKeys.localeKey: 'system',
    SpKeys.selectedSemester: '',
    SpKeys.siteInjectionEnabled: true,
    SpKeys.showExamOnSchedule: true,
    SpKeys.showNonCurrentWeekCourses: false,
    SpKeys.autoAdjustCourse: true,
    SpKeys.courseReminderEnabled: false,
    SpKeys.courseReminderMinutes: 21 * 60,
    SpKeys.githubProxyEnabled: true,
    SpKeys.githubProxyBaseUrl: GitHubProxy.defaultBaseUrl,
    SpKeys.west2AdjustmentsAccess: 'tip',
    SpKeys.papersAccess: 'tip',
    SpKeys.hiddenCourseSessions: '[]',
    CustomCourseStore.storageKey: '[]',
  };

  Future<WebDavConfig> loadConfig() async {
    final sp = await SharedPreferences.getInstance();
    return WebDavConfig(
      directory: sp.getString(_directoryKey) ?? '',
      username: sp.getString(_usernameKey) ?? '',
      password: await storage.read(key: _passwordKey) ?? '',
    );
  }

  Future<void> saveConfig(WebDavConfig config) async {
    config.fileUri;
    _configurationRevision++;
    final sp = await SharedPreferences.getInstance();
    await storage.write(key: _passwordKey, value: config.password);
    await sp.setString(_directoryKey, config.directory.trim());
    await sp.setString(_usernameKey, config.username);
  }

  Future<bool> loadAutoSyncEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_autoSyncKey) ?? false;

  Future<void> setAutoSyncEnabled(bool enabled) async {
    _configurationRevision++;
    final sp = await SharedPreferences.getInstance();
    if (!await sp.setBool(_autoSyncKey, enabled)) {
      throw Exception('无法保存自动同步设置');
    }
  }

  /// Include manual confirmation dialogs in this lock, across page instances.
  Future<T> exclusive<T>(Future<T> Function() action) async {
    if (_operationActive) throw Exception('WebDAV 正在同步，请稍后重试');
    _operationActive = true;
    try {
      return await action();
    } finally {
      _operationActive = false;
    }
  }

  String _target(WebDavConfig config) => sha256
      .convert(
        utf8.encode(jsonEncode([config.fileUri.toString(), config.username])),
      )
      .toString();

  Future<void> rememberSynced(
    WebDavConfig config,
    WebDavSnapshot snapshot,
  ) async {
    final sp = await SharedPreferences.getInstance();
    if (!await sp.setString(
      _baselineKey,
      jsonEncode({'target': _target(config), 'content': snapshot.fingerprint}),
    )) {
      throw Exception('无法保存同步记录');
    }
  }

  Future<WebDavAutoSyncResult> autoSync({
    required void Function(WebDavSnapshot) apply,
  }) async {
    if (_operationActive) return WebDavAutoSyncResult.skipped;
    return exclusive(() async {
      final revision = _configurationRevision;
      bool isCurrent() => revision == _configurationRevision;
      if (!await loadAutoSyncEnabled() || !isCurrent()) {
        return WebDavAutoSyncResult.skipped;
      }
      final config = await loadConfig();
      if (config.directory.trim().isEmpty) return WebDavAutoSyncResult.skipped;
      final sp = await SharedPreferences.getInstance();
      String? baseline;
      try {
        final saved = jsonDecode(sp.getString(_baselineKey) ?? '{}');
        if (saved is Map && saved['target'] == _target(config)) {
          baseline = saved['content'] as String?;
        }
      } catch (_) {
        // A missing or damaged baseline requires an explicit first choice.
      }
      final local = await exportSnapshot();
      if (!isCurrent()) return WebDavAutoSyncResult.skipped;
      final remote = await readRemote(config);
      final latest = await exportSnapshot();
      if (!isCurrent()) return WebDavAutoSyncResult.skipped;
      if (latest.fingerprint != local.fingerprint) {
        return WebDavAutoSyncResult.conflict;
      }
      final other = remote.snapshot;
      if (other?.fingerprint == local.fingerprint) {
        await rememberSynced(config, local);
        return WebDavAutoSyncResult.unchanged;
      }
      if (other == null) {
        await upload(config, local, remote);
        await rememberSynced(config, local);
        return WebDavAutoSyncResult.uploaded;
      }
      if (baseline == null ||
          (baseline != local.fingerprint && baseline != other.fingerprint)) {
        return WebDavAutoSyncResult.conflict;
      }
      if (local.fingerprint == baseline) {
        try {
          await restore(
            other,
            expectedLocal: local,
            apply: apply,
            canApply: isCurrent,
          );
        } on WebDavLocalChanged {
          return isCurrent()
              ? WebDavAutoSyncResult.conflict
              : WebDavAutoSyncResult.skipped;
        }
        await rememberSynced(config, other);
        return WebDavAutoSyncResult.downloaded;
      }
      // Existing files need a strong validator to prevent racing another device.
      if (remote.etag == null || remote.etag!.startsWith('W/')) {
        return WebDavAutoSyncResult.manualUploadRequired;
      }
      await upload(config, local, remote);
      await rememberSynced(config, local);
      return WebDavAutoSyncResult.uploaded;
    });
  }

  Future<WebDavSnapshot> exportSnapshot() async {
    final sp = await SharedPreferences.getInstance();
    final values = <String, Object>{
      for (final entry in defaults.entries)
        entry.key: sp.get(entry.key) ?? entry.value,
    };
    // Migrate consent in the exported copy as well; never reset an existing allow.
    if (!sp.containsKey(SpKeys.west2AdjustmentsAccess) &&
        sp.getBool(SpKeys.west2AdjustmentsEnabled) == true) {
      values[SpKeys.west2AdjustmentsAccess] = FeatureAccess.allow.name;
    }
    return WebDavSnapshot.fromJson({
      'format': format,
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'values': values,
    });
  }

  Options _options(
    WebDavConfig config,
    String method, {
    Map<String, Object>? headers,
  }) => Options(
    method: method,
    followRedirects: false,
    responseType: ResponseType.stream,
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
      ...?headers,
    },
    validateStatus: (status) => status != null,
  );

  Never _httpError(int? status) {
    if (status == 401 || status == 403) throw Exception('WebDAV 认证失败，请检查账号和密码');
    if (status == 412) throw Exception('远端文件已改变，请重新读取后再同步');
    if (status != null && status >= 300 && status < 400) {
      throw Exception('WebDAV 地址发生跳转，请填写最终目录地址');
    }
    throw Exception('WebDAV 请求失败（HTTP $status）');
  }

  Future<Response<ResponseBody>> _request(
    WebDavConfig config,
    Options options, {
    Object? data,
    Uri? uri,
  }) async {
    try {
      return await dio.requestUri<ResponseBody>(
        uri ?? config.fileUri,
        options: options,
        data: data,
      );
    } on DioException {
      throw const _WebDavNetworkFailure();
    }
  }

  Future<void> _ensureDirectory(
    WebDavConfig config,
    Uri directory, [
    int depth = 0,
  ]) async {
    Future<int?> create() async {
      final response = await _request(
        config,
        _options(config, 'MKCOL'),
        uri: directory,
      );
      await response.data?.stream.drain<void>();
      return response.statusCode;
    }

    var status = await create();
    if ({201, 405}.contains(status)) return;
    if (status == 409) {
      final parent = directory.resolve('../');
      if (depth >= 64 || parent == directory) {
        throw Exception('无法创建 WebDAV 目录，请检查路径和写入权限');
      }
      await _ensureDirectory(config, parent, depth + 1);
      status = await create();
      if ({201, 405}.contains(status)) return;
    }
    _httpError(status);
  }

  Future<Response<ResponseBody>> _put(
    WebDavConfig config,
    List<int> data,
    Map<String, Object> headers, {
    Uri? uri,
  }) async {
    Future<Response<ResponseBody>> send() => _request(
      config,
      _options(config, 'PUT', headers: headers),
      data: Stream.value(data),
      uri: uri,
    );

    final response = await send();
    if (response.statusCode != 409) return response;
    await response.data?.stream.drain<void>();
    await _ensureDirectory(config, config.fileUri.resolve('.'));
    // Rebuild the body stream and preserve conditional headers on the one retry.
    return send();
  }

  /// Probe the entered directory without reading or replacing the sync backup.
  Future<void> testConnection(WebDavConfig config) async {
    final directory = config.fileUri;
    final random = Random.secure();
    final nonce = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final name = 'fzu-assistant-test-$nonce.tmp';
    final uri = directory.resolve(name);
    final marker = 'FZU Assistant WebDAV connection test: $nonce\n';
    final data = utf8.encode(marker);
    Response<ResponseBody> created;
    try {
      created = await _put(config, data, {
        'Content-Type': 'text/plain; charset=utf-8',
        'Content-Length': data.length,
        'If-None-Match': '*',
      }, uri: uri);
    } on _WebDavNetworkFailure {
      throw Exception('连接测试中断，临时文件 $name 可能残留，请检查连接后手动删除');
    }
    if (!{200, 201, 204}.contains(created.statusCode)) {
      await created.data?.stream.drain<void>();
      _httpError(created.statusCode);
    }

    // Once created, attempt cleanup even if reading or checking the marker fails.
    try {
      await created.data?.stream.drain<void>();
      final response = await _request(
        config,
        _options(config, 'GET'),
        uri: uri,
      );
      final body = response.data;
      if (response.statusCode != 200 || body == null) {
        await body?.stream.drain<void>();
        _httpError(response.statusCode);
      }
      const limit = 1024;
      if ((int.tryParse(response.headers.value('content-length') ?? '') ?? 0) >
          limit) {
        await body.stream.listen((_) {}).cancel();
        throw Exception('连接测试返回的数据无效');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in body.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (bytes.length + chunk.length > limit) {
          throw Exception('连接测试返回的数据无效');
        }
        bytes.add(chunk);
      }
      if (utf8.decode(bytes.takeBytes()) != marker) {
        throw Exception('连接测试读取的内容不一致，请检查目录和权限');
      }
    } finally {
      try {
        final deleted = await _request(
          config,
          _options(config, 'DELETE'),
          uri: uri,
        );
        await deleted.data?.stream.drain<void>();
        if (!{200, 204, 404}.contains(deleted.statusCode)) {
          _httpError(deleted.statusCode);
        }
      } catch (_) {
        throw Exception('测试文件 $name 清理失败，请手动删除并检查目录权限');
      }
    }
  }

  Future<WebDavRemote> readRemote(WebDavConfig config) async {
    final response = await _request(config, _options(config, 'GET'));
    final body = response.data;
    if ({404, 409}.contains(response.statusCode)) {
      await body?.stream.drain<void>();
      return const WebDavRemote(snapshot: null);
    }
    if (response.statusCode != 200 || body == null) {
      await body?.stream.drain<void>();
      _httpError(response.statusCode);
    }
    if ((int.tryParse(response.headers.value('content-length') ?? '') ?? 0) >
        maxBytes) {
      await body.stream.listen((_) {}).cancel();
      throw const FormatException('WebDAV 同步文件过大');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in body.stream) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('WebDAV 同步文件过大');
      }
      bytes.add(chunk);
    }
    return WebDavRemote(
      snapshot: WebDavSnapshot.fromJson(
        jsonDecode(utf8.decode(bytes.takeBytes())),
      ),
      etag: response.headers.value('etag'),
    );
  }

  Future<void> upload(
    WebDavConfig config,
    WebDavSnapshot snapshot,
    WebDavRemote previous,
  ) async {
    final data = utf8.encode(jsonEncode(snapshot.toJson()));
    if (data.length > maxBytes) throw const FormatException('同步数据过大');
    final response = await _put(config, data, {
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': data.length,
      if (previous.snapshot == null) 'If-None-Match': '*',
      if (previous.etag != null) 'If-Match': previous.etag!,
    });
    await response.data?.stream.drain<void>();
    if (!{200, 201, 204}.contains(response.statusCode)) {
      _httpError(response.statusCode);
    }
  }

  /// Validate before the first mutation, and restore the old values on failure.
  Future<void> restore(
    WebDavSnapshot snapshot, {
    WebDavSnapshot? expectedLocal,
    void Function(WebDavSnapshot)? apply,
    bool Function()? canApply,
  }) async {
    final checked = WebDavSnapshot.fromJson(snapshot.toJson());
    await CustomCourseStore.instance.restoreFromSync(() async {
      final sp = await SharedPreferences.getInstance();
      final previous = await exportSnapshot();
      if (canApply != null && !canApply()) throw WebDavLocalChanged();
      if (expectedLocal != null &&
          previous.fingerprint != expectedLocal.fingerprint) {
        throw WebDavLocalChanged();
      }
      final before = {for (final key in defaults.keys) key: sp.get(key)};
      try {
        // SP updates its cache synchronously; apply notifiers in the same turn,
        // before waiting for disk writes, to preserve subsequent user edits.
        final writes = [
          for (final entry in checked.values.entries)
            _write(sp, entry.key, entry.value),
        ];
        apply?.call(checked);
        if ((await Future.wait(writes)).any((saved) => !saved)) {
          throw Exception('无法保存同步设置');
        }
      } catch (_) {
        final rollback = [
          for (final entry in before.entries)
            _write(sp, entry.key, entry.value),
        ];
        apply?.call(previous);
        await Future.wait(rollback);
        rethrow;
      }
    });
  }

  static Future<bool> _write(SharedPreferences sp, String key, Object? value) =>
      WidgetPreferenceBridge.write(sp, key, value);
}

/// Apply already validated data without binding a second set of SP listeners.
void applyWebDavSettings(AppSettings settings, WebDavSnapshot snapshot) {
  final values = snapshot.values;
  settings.west2AdjustmentsAccess.value = FeatureAccess.parse(
    values[SpKeys.west2AdjustmentsAccess] as String,
  );
  settings.papersAccess.value = FeatureAccess.parse(
    values[SpKeys.papersAccess] as String,
  );
  settings.themeKey.value = values[SpKeys.themeKey] as String;
  settings.themeModeKey.value = values[SpKeys.themeMode] as String;
  settings.interfaceStyle.value = InterfaceStyle.parse(
    values[SpKeys.interfaceStyle] as String,
  );
  settings.localeKey.value = values[SpKeys.localeKey] as String;
  settings.selectedSemesterKey.value =
      values[SpKeys.selectedSemester] as String;
  settings.siteInjectionEnabled.value =
      values[SpKeys.siteInjectionEnabled] as bool;
  settings.showExamOnSchedule.value = values[SpKeys.showExamOnSchedule] as bool;
  settings.showNonCurrentWeekCourses.value =
      values[SpKeys.showNonCurrentWeekCourses] as bool;
  settings.autoAdjustCourse.value = values[SpKeys.autoAdjustCourse] as bool;
  settings.githubProxyEnabled.value = values[SpKeys.githubProxyEnabled] as bool;
  settings.githubProxyBaseUrl.value =
      values[SpKeys.githubProxyBaseUrl] as String;
  settings.hiddenCourseSessions.value =
      (jsonDecode(values[SpKeys.hiddenCourseSessions] as String) as List)
          .map(
            (record) => HiddenCourseSession.fromJson(
              Map<String, dynamic>.from(record as Map),
            ),
          )
          .toList();
  settings.courseReminderMinutes.value =
      values[SpKeys.courseReminderMinutes] as int;
  settings.courseReminderEnabled.value =
      values[SpKeys.courseReminderEnabled] as bool;
}
