part of 'webdav_sync_service.dart';

enum WebDavHistoryReason { upload, beforeUpload }

/// Immutable content-addressed snapshots; metadata never supplies a URL.
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

const _historyFormat = 'fzu-assistant-history';
const _historyIndexName = 'fzu-assistant-history.json';
const _historyDirectory = 'fzu-assistant-history/';
const _historyMetadataDirectory = '${_historyDirectory}metadata/';
const _historyMetadataFormat = 'fzu-assistant-history-entry';
const _historyMaxEntries = 10000;
const _historyMetadataMaxBytes = 16 * 1024;

extension WebDavHistoryService on WebDavSyncService {
  // The v1 shared index is read-only. New clients never create or replace it,
  // including on servers that omit ETag from their GET responses.
  Future<List<WebDavHistoryEntry>> _readHistoryIndex(
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
      return const [];
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
        (raw['entries'] as List).length > _historyMaxEntries) {
      throw const FormatException('WebDAV 历史索引格式或版本不受支持');
    }
    final entries = (raw['entries'] as List)
        .map(WebDavHistoryEntry.fromJson)
        .toList();
    if (entries.map((entry) => entry.id).toSet().length != entries.length) {
      throw const FormatException('WebDAV 历史索引包含重复记录');
    }
    return entries;
  }

  Future<List<WebDavHistoryEntry>> listHistory(WebDavConfig config) =>
      _withOperation(() async {
        final isCurrent = captureValidity();
        final legacy = await _readHistoryIndex(config, isCurrent);
        final ids = await _listHistoryMetadata(config, isCurrent);
        return _mergeHistoryMetadata(config, legacy, ids, isCurrent);
      });

  Future<List<WebDavHistoryEntry>> _mergeHistoryMetadata(
    WebDavConfig config,
    List<WebDavHistoryEntry> legacy,
    Set<String> ids,
    bool Function() isCurrent,
  ) async {
    WebDavSyncService._checkCurrent(isCurrent);
    final byId = {for (final entry in legacy) entry.id: entry};
    if ({...byId.keys, ...ids}.length > _historyMaxEntries) {
      throw const FormatException('WebDAV 历史记录数量超限');
    }
    var totalBytes = 0;
    for (final id in ids) {
      final (entry, size) = await _readHistoryMetadata(config, id, isCurrent);
      totalBytes += size;
      if (totalBytes > WebDavSyncService.maxBytes) {
        throw const FormatException('WebDAV 历史元数据总大小超限');
      }
      final existing = byId[id];
      if (existing != null && !_sameHistorySnapshot(existing, entry)) {
        throw const FormatException('WebDAV 新旧历史记录不一致');
      }
      // Keep v1 timestamps/reasons when both formats describe one snapshot.
      byId.putIfAbsent(id, () => entry);
    }
    final entries = byId.values.toList()
      ..sort((a, b) {
        final order = b.recordedAt.compareTo(a.recordedAt);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    return List.unmodifiable(entries);
  }

  bool _sameHistorySnapshot(WebDavHistoryEntry a, WebDavHistoryEntry b) =>
      a.id == b.id &&
      a.createdAt == b.createdAt &&
      a.schemaVersion == b.schemaVersion &&
      a.appVersion?.label == b.appVersion?.label &&
      a.customCourseCount == b.customCourseCount &&
      a.hiddenCourseCount == b.hiddenCourseCount;

  Future<Set<String>> _listHistoryMetadata(
    WebDavConfig config,
    bool Function() isCurrent, {
    bool createDirectory = false,
  }) async {
    final directory = config.fileUri.resolve(_historyMetadataDirectory);
    Future<Response<ResponseBody>> list() {
      WebDavSyncService._checkCurrent(isCurrent);
      return _request(
        config,
        _options(
          config,
          'PROPFIND',
          headers: {
            'Depth': '1',
            'Content-Type': 'application/xml; charset=utf-8',
          },
        ),
        uri: directory,
        data:
            '<?xml version="1.0" encoding="utf-8"?>'
            '<d:propfind xmlns:d="DAV:"><d:prop>'
            '<d:resourcetype/></d:prop></d:propfind>',
      );
    }

    var response = await list();
    if ({404, 409}.contains(response.statusCode)) {
      await response.data?.stream.drain<void>();
      WebDavSyncService._checkCurrent(isCurrent);
      if (!createDirectory) return {};
      await _ensureDirectory(config, directory, canWrite: isCurrent);
      response = await list();
    }
    if (response.statusCode != 207 || response.data == null) {
      await response.data?.stream.drain<void>();
      WebDavSyncService._checkCurrent(isCurrent);
      if ({405, 501}.contains(response.statusCode)) {
        throw Exception(
          'WebDAV 服务器不支持历史目录的 PROPFIND Depth: 1，'
          '请启用目录列举功能后重试；当前同步文件已保留',
        );
      }
      _httpError(response.statusCode);
    }
    final text = utf8.decode(await _readBytes(response, isCurrent));
    final XmlDocument document;
    try {
      document = XmlDocument.parse(text);
    } on XmlException {
      throw const FormatException('WebDAV 历史目录不是有效的 XML');
    }
    final root = document.rootElement;
    if (document.doctypeElement != null ||
        root.name.local != 'multistatus' ||
        root.namespaceUri != 'DAV:') {
      throw const FormatException('WebDAV 历史目录不是有效的 DAV multistatus');
    }
    final responses = root
        .findElements('response', namespaceUri: 'DAV:')
        .toList();
    if (responses.length > _historyMaxEntries + 1) {
      throw const FormatException('WebDAV 历史记录数量超限');
    }
    var foundDirectory = false;
    final ids = <String>{};
    for (final item in responses) {
      final hrefs = item.findElements('href', namespaceUri: 'DAV:').toList();
      if (hrefs.length != 1 || hrefs.single.childElements.isNotEmpty) {
        throw const FormatException('WebDAV 历史目录 href 无效');
      }
      final id = _historyMetadataId(directory, hrefs.single.innerText.trim());
      final properties = item
          .findElements('propstat', namespaceUri: 'DAV:')
          .where((propstat) {
            final statuses = propstat
                .findElements('status', namespaceUri: 'DAV:')
                .toList();
            if (statuses.length != 1 ||
                !RegExp(r'^HTTP/\d+(?:\.\d+)? 200(?: |$)')
                    .hasMatch(statuses.single.innerText.trim())) {
              return false;
            }
            return true;
          })
          .expand(
            (propstat) => propstat.findElements('prop', namespaceUri: 'DAV:'),
          )
          .expand(
            (prop) => prop.findElements('resourcetype', namespaceUri: 'DAV:'),
          )
          .toList();
      if (properties.length != 1) {
        throw const FormatException('WebDAV 历史目录条目缺少成功的资源类型响应');
      }
      final collection = properties.single
          .findElements('collection', namespaceUri: 'DAV:')
          .isNotEmpty;
      if (id == null) {
        if (!collection || foundDirectory) {
          throw const FormatException('WebDAV 历史目录自身的响应无效');
        }
        foundDirectory = true;
      } else if (collection || !ids.add(id)) {
        throw const FormatException('WebDAV 历史目录包含重复或无效的元数据文件');
      }
    }
    if (!foundDirectory) {
      throw const FormatException('WebDAV 历史目录响应不完整');
    }
    return ids;
  }

  // Only accept the collection itself and fixed-name direct children. Rebuild
  // GET targets from validated IDs; never request a server-supplied href.
  String? _historyMetadataId(Uri directory, String href) {
    if (href.isEmpty ||
        href.length > 4096 ||
        href.codeUnits.any((char) => char <= 0x20 || char == 0x7f)) {
      throw const FormatException('WebDAV 历史目录 href 无效');
    }
    final Uri reference;
    try {
      for (final segment in href.split('/')) {
        final decoded = Uri.decodeComponent(segment);
        if (decoded == '.' ||
            decoded == '..' ||
            decoded.contains('/') ||
            decoded.contains(r'\')) {
          throw const FormatException('WebDAV 历史目录 href 包含不安全路径');
        }
      }
      reference = Uri.parse(href);
    } on FormatException {
      throw const FormatException('WebDAV 历史目录 href 包含不安全路径');
    }
    final uri = directory.resolveUri(reference);
    if (!{'http', 'https'}.contains(uri.scheme) ||
        uri.origin != directory.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('WebDAV 历史目录 href 不属于当前目录');
    }
    final prefix = directory.pathSegments.toList()..removeLast();
    final segments = uri.pathSegments.toList();
    if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
    if (segments.length < prefix.length ||
        segments.take(prefix.length).join('/') != prefix.join('/')) {
      throw const FormatException('WebDAV 历史目录 href 不属于当前目录');
    }
    if (segments.length == prefix.length) return null;
    if (segments.length != prefix.length + 1 ||
        !RegExp(r'^[a-f0-9]{64}\.json$').hasMatch(segments.last) ||
        uri.path.endsWith('/')) {
      throw const FormatException('WebDAV 历史目录包含不安全的元数据文件名');
    }
    return segments.last.substring(0, 64);
  }

  Future<(WebDavHistoryEntry, int)> _readHistoryMetadata(
    WebDavConfig config,
    String id,
    bool Function() isCurrent,
  ) async {
    WebDavSyncService._checkCurrent(isCurrent);
    final response = await _request(
      config,
      _options(config, 'GET'),
      uri: config.fileUri.resolve('$_historyMetadataDirectory$id.json'),
    );
    if (response.statusCode != 200 || response.data == null) {
      await response.data?.stream.drain<void>();
      _httpError(response.statusCode);
    }
    final bytes = await _readBytes(
      response,
      isCurrent,
      limit: _historyMetadataMaxBytes,
    );
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map ||
        raw.length != 3 ||
        raw['format'] != _historyMetadataFormat ||
        raw['schemaVersion'] != 1) {
      throw const FormatException('WebDAV 历史元数据格式或版本不受支持');
    }
    final entry = WebDavHistoryEntry.fromJson(raw['entry']);
    if (entry.id != id) {
      throw const FormatException('WebDAV 历史元数据与文件名不一致');
    }
    return (entry, bytes.length);
  }

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
    final legacy = await _readHistoryIndex(config, isCurrent);
    final ids = await _listHistoryMetadata(
      config,
      isCurrent,
      createDirectory: true,
    );
    final additions = <String, (WebDavHistoryEntry, WebDavSnapshot)>{};
    for (final (snapshot, reason) in snapshots) {
      final entry = WebDavHistoryEntry._snapshot(snapshot, reason);
      additions.putIfAbsent(entry.id, () => (entry, snapshot));
    }
    if ({...legacy.map((entry) => entry.id), ...ids, ...additions.keys}.length >
        _historyMaxEntries) {
      throw const FormatException('WebDAV 历史记录数量超限');
    }
    for (final (entry, snapshot) in additions.values) {
      final existing = legacy
          .where((value) => value.id == entry.id)
          .firstOrNull;
      if (existing != null) {
        if (ids.contains(entry.id)) {
          final (metadata, _) = await _readHistoryMetadata(
            config,
            entry.id,
            isCurrent,
          );
          if (!_sameHistorySnapshot(existing, metadata)) {
            throw const FormatException('WebDAV 新旧历史记录不一致');
          }
        }
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

      // Publishing metadata makes an already-complete snapshot discoverable.
      // One immutable file per snapshot deduplicates retries and concurrent
      // writers. The first writer keeps its recordedAt/reason.
      WebDavSyncService._checkCurrent(isCurrent);
      final metadata = utf8.encode(
        jsonEncode({
          'format': _historyMetadataFormat,
          'schemaVersion': 1,
          'entry': entry.toJson(),
        }),
      );
      if (metadata.length > _historyMetadataMaxBytes) {
        throw const FormatException('WebDAV 历史元数据过大');
      }
      final published = await _put(
        config,
        metadata,
        {
          'Content-Type': 'application/json; charset=utf-8',
          'Content-Length': metadata.length,
          'If-None-Match': '*',
        },
        uri: config.fileUri.resolve(
          '$_historyMetadataDirectory${entry.id}.json',
        ),
        canWrite: isCurrent,
      );
      await published.data?.stream.drain<void>();
      WebDavSyncService._checkCurrent(isCurrent);
      if (published.statusCode == 412) {
        final (existing, _) = await _readHistoryMetadata(
          config,
          entry.id,
          isCurrent,
        );
        if (!_sameHistorySnapshot(existing, entry)) {
          throw const FormatException('WebDAV 已有历史元数据与快照不一致');
        }
      } else if (!{200, 201, 204}.contains(published.statusCode)) {
        _httpError(published.statusCode);
      }
    }
    // Verify discovery before publishing the mutable main file. A partial or
    // unsupported listing must not silently hide a newly archived version.
    final finalIds = await _listHistoryMetadata(config, isCurrent);
    final visible = {...legacy.map((entry) => entry.id), ...finalIds};
    if (visible.length > _historyMaxEntries ||
        !visible.containsAll(ids) ||
        !visible.containsAll(additions.keys)) {
      throw const FormatException('WebDAV 历史目录未完整列出已保存的快照');
    }
    // Validate all discovered metadata once, including unrelated older entries.
    // A main update must not proceed with history that listHistory would reject.
    await _mergeHistoryMetadata(config, legacy, finalIds, isCurrent);
  }
}
