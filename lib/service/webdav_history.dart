part of 'webdav_sync_service.dart';

enum WebDavHistoryReason { upload, beforeUpload }

/// Immutable content-addressed snapshots; the index never supplies a URL.
class WebDavHistoryEntry {
  const WebDavHistoryEntry._({
    required this.id,
    required this.createdAt,
    required this.recordedAt,
    required this.schemaVersion,
    required this.customCourseCount,
    required this.hiddenCourseCount,
    required this.reason,
    this.appVersion,
  });

  final String id;
  final DateTime createdAt;
  final DateTime recordedAt;
  final int schemaVersion;
  final int customCourseCount;
  final int hiddenCourseCount;
  final WebDavAppVersion? appVersion;
  final WebDavHistoryReason reason;

  factory WebDavHistoryEntry._snapshot(
    WebDavSnapshot snapshot,
    WebDavHistoryReason reason,
  ) => WebDavHistoryEntry._(
    id: sha256.convert(utf8.encode(jsonEncode(snapshot.toJson()))).toString(),
    createdAt: snapshot.createdAt,
    recordedAt: DateTime.now().toUtc(),
    schemaVersion: snapshot.schemaVersion,
    appVersion: snapshot.appVersion,
    customCourseCount: snapshot.customCourseCount,
    hiddenCourseCount: snapshot.hiddenCourseCount,
    reason: reason,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
    if (appVersion != null) 'appVersion': appVersion!.toJson(),
    'customCourseCount': customCourseCount,
    'hiddenCourseCount': hiddenCourseCount,
    'reason': reason.name,
  };

  factory WebDavHistoryEntry.fromJson(Object? source) {
    const keys = {
      'id',
      'createdAt',
      'recordedAt',
      'schemaVersion',
      'appVersion',
      'customCourseCount',
      'hiddenCourseCount',
      'reason',
    };
    if (source is! Map ||
        source.keys.any((key) => !keys.contains(key)) ||
        source['id'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(source['id'] as String) ||
        source['createdAt'] is! String ||
        source['recordedAt'] is! String ||
        source['schemaVersion'] is! int ||
        (source['schemaVersion'] as int) < 1 ||
        source['customCourseCount'] is! int ||
        source['hiddenCourseCount'] is! int ||
        (source['customCourseCount'] as int) < 0 ||
        (source['hiddenCourseCount'] as int) < 0) {
      throw const FormatException('WebDAV 历史快照索引无效');
    }
    final createdAt = DateTime.tryParse(source['createdAt'] as String);
    final recordedAt = DateTime.tryParse(source['recordedAt'] as String);
    final reason = WebDavHistoryReason.values
        .where((value) => value.name == source['reason'])
        .firstOrNull;
    if (createdAt == null || recordedAt == null || reason == null) {
      throw const FormatException('WebDAV 历史快照索引无效');
    }
    return WebDavHistoryEntry._(
      id: source['id'] as String,
      createdAt: createdAt,
      recordedAt: recordedAt,
      schemaVersion: source['schemaVersion'] as int,
      customCourseCount: source['customCourseCount'] as int,
      hiddenCourseCount: source['hiddenCourseCount'] as int,
      appVersion: source['appVersion'] == null
          ? null
          : WebDavAppVersion.fromJson(source['appVersion']),
      reason: reason,
    );
  }
}

class _WebDavHistoryIndex {
  const _WebDavHistoryIndex(this.entries, {this.etag, this.exists = false});
  final List<WebDavHistoryEntry> entries;
  final String? etag;
  final bool exists;

  Map<String, Object> toJson() => {
    'format': _historyFormat,
    'schemaVersion': 1,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };
}

const _historyFormat = 'fzu-assistant-history';
const _historyIndexName = 'fzu-assistant-history.json';
const _historyDirectory = 'fzu-assistant-history/';

extension WebDavHistoryService on WebDavSyncService {
  Future<_WebDavHistoryIndex> _readHistoryIndex(
    WebDavConfig config,
    bool Function() isCurrent,
  ) async {
    WebDavSyncService._checkCurrent(isCurrent);
    final response = await _request(
      config,
      _options(config, 'GET'),
      uri: config.fileUri.resolve(_historyIndexName),
    );
    if ({404, 409}.contains(response.statusCode)) {
      await response.data?.stream.drain<void>();
      WebDavSyncService._checkCurrent(isCurrent);
      return const _WebDavHistoryIndex([]);
    }
    if (response.statusCode != 200 || response.data == null) {
      await response.data?.stream.drain<void>();
      _httpError(response.statusCode);
    }
    final raw = await _readJson(response, isCurrent);
    if (raw is! Map ||
        raw.length != 3 ||
        raw['format'] != _historyFormat ||
        raw['schemaVersion'] != 1 ||
        raw['entries'] is! List ||
        (raw['entries'] as List).length > 10000) {
      throw const FormatException('WebDAV 历史索引格式或版本不受支持');
    }
    final entries = (raw['entries'] as List)
        .map(WebDavHistoryEntry.fromJson)
        .toList();
    if (entries.map((entry) => entry.id).toSet().length != entries.length) {
      throw const FormatException('WebDAV 历史索引包含重复记录');
    }
    return _WebDavHistoryIndex(
      entries,
      etag: response.headers.value('etag'),
      exists: true,
    );
  }

  Future<List<WebDavHistoryEntry>> listHistory(WebDavConfig config) =>
      _withOperation(() async {
        final index = await _readHistoryIndex(config, captureValidity());
        final entries = [...index.entries]
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        return List.unmodifiable(entries);
      });

  Future<WebDavSnapshot> readHistorySnapshot(
    WebDavConfig config,
    WebDavHistoryEntry entry,
  ) => _withOperation(
    () => _readHistorySnapshot(
      config,
      WebDavHistoryEntry.fromJson(entry.toJson()),
      captureValidity(),
    ),
  );

  Future<WebDavSnapshot> _readHistorySnapshot(
    WebDavConfig config,
    WebDavHistoryEntry entry,
    bool Function() isCurrent,
  ) async {
    WebDavSyncService._checkCurrent(isCurrent);
    final response = await _request(
      config,
      _options(config, 'GET'),
      uri: config.fileUri.resolve('$_historyDirectory${entry.id}.json'),
    );
    if (response.statusCode != 200 || response.data == null) {
      await response.data?.stream.drain<void>();
      _httpError(response.statusCode);
    }
    final source = await _readJson(response, isCurrent);
    final digest = sha256.convert(utf8.encode(jsonEncode(source))).toString();
    if (digest != entry.id) {
      throw const FormatException('WebDAV 历史快照内容与索引不一致');
    }
    final snapshot = WebDavSnapshot.fromJson(source);
    if (snapshot.schemaVersion != entry.schemaVersion ||
        snapshot.createdAt != entry.createdAt ||
        snapshot.appVersion?.label != entry.appVersion?.label ||
        snapshot.customCourseCount != entry.customCourseCount ||
        snapshot.hiddenCourseCount != entry.hiddenCourseCount) {
      throw const FormatException('WebDAV 历史快照摘要无效');
    }
    return snapshot;
  }

  Future<void> _archive(
    WebDavConfig config,
    List<(WebDavSnapshot, WebDavHistoryReason)> snapshots,
    bool Function() isCurrent,
  ) async {
    var index = await _readHistoryIndex(config, isCurrent);
    final additions = <String, (WebDavHistoryEntry, WebDavSnapshot)>{};
    for (final (snapshot, reason) in snapshots) {
      final entry = WebDavHistoryEntry._snapshot(snapshot, reason);
      additions.putIfAbsent(entry.id, () => (entry, snapshot));
    }
    // Check ownership/validator before creating any history files.
    _historyValidator(index);
    for (final (entry, snapshot) in additions.values) {
      final existing = index.entries
          .where((value) => value.id == entry.id)
          .firstOrNull;
      if (existing != null) {
        await _readHistorySnapshot(config, existing, isCurrent);
        continue;
      }
      WebDavSyncService._checkCurrent(isCurrent);
      final data = utf8.encode(jsonEncode(snapshot.toJson()));
      if (data.length > WebDavSyncService.maxBytes) {
        throw const FormatException('WebDAV 历史快照过大');
      }
      final response = await _put(
        config,
        data,
        {
          'Content-Type': 'application/json; charset=utf-8',
          'Content-Length': data.length,
          'If-None-Match': '*',
        },
        uri: config.fileUri.resolve('$_historyDirectory${entry.id}.json'),
        canWrite: isCurrent,
      );
      await response.data?.stream.drain<void>();
      WebDavSyncService._checkCurrent(isCurrent);
      if (response.statusCode == 412) {
        // A content-addressed filename may already exist, but it must contain
        // the exact validated snapshot. Never replace an unrelated resource.
        await _readHistorySnapshot(config, entry, isCurrent);
      } else if (!{200, 201, 204}.contains(response.statusCode)) {
        _httpError(response.statusCode);
      }
    }
    // Another device may append between GET and PUT. Merge its new entries and
    // retry conditionally, without ever overwriting its history.
    for (var attempt = 0; attempt < 4; attempt++) {
      WebDavSyncService._checkCurrent(isCurrent);
      final known = index.entries.map((entry) => entry.id).toSet();
      final missing = additions.values
          .map((item) => item.$1)
          .where((entry) => !known.contains(entry.id))
          .toList();
      if (missing.isEmpty) return;
      final entries = [...index.entries, ...missing];
      if (entries.length > 10000) {
        throw const FormatException('WebDAV 历史索引已满，请先保留或归档远端快照');
      }
      final data = utf8.encode(
        jsonEncode(_WebDavHistoryIndex(entries).toJson()),
      );
      if (data.length > WebDavSyncService.maxBytes) {
        throw const FormatException('WebDAV 历史索引过大');
      }
      final response = await _put(
        config,
        data,
        {
          'Content-Type': 'application/json; charset=utf-8',
          'Content-Length': data.length,
          ..._historyValidator(index),
        },
        uri: config.fileUri.resolve(_historyIndexName),
        canWrite: isCurrent,
      );
      await response.data?.stream.drain<void>();
      WebDavSyncService._checkCurrent(isCurrent);
      if ({200, 201, 204}.contains(response.statusCode)) return;
      if (response.statusCode != 412) _httpError(response.statusCode);
      index = await _readHistoryIndex(config, isCurrent);
    }
    throw Exception('WebDAV 历史记录正在被其他设备修改，请稍后重试');
  }

  Map<String, Object> _historyValidator(_WebDavHistoryIndex index) {
    if (!index.exists) return {'If-None-Match': '*'};
    final etag = index.etag;
    if (etag == null ||
        etag.startsWith('W/') ||
        !etag.startsWith('"') ||
        !etag.endsWith('"')) {
      throw Exception('WebDAV 服务器未提供历史索引的强 ETag，无法安全更新历史记录');
    }
    return {'If-Match': etag};
  }
}
