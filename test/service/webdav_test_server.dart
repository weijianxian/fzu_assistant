import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

String webDavListing(Iterable<(String, bool)> resources) =>
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:multistatus xmlns:d="DAV:">'
    '${resources.map((resource) => '<d:response>'
        '<d:href>${const HtmlEscape(HtmlEscapeMode.element).convert(resource.$1)}</d:href>'
        '<d:propstat><d:prop><d:resourcetype>'
        '${resource.$2 ? '<d:collection/>' : ''}'
        '</d:resourcetype></d:prop>'
        '<d:status>HTTP/1.1 200 OK</d:status></d:propstat>'
        '</d:response>').join()}'
    '</d:multistatus>';

/// A conditional WebDAV store shared by protocol tests. It never hides history
/// requests in tests that cover history, but lets older focused tests route
/// their existing main-file responses independently.
class WebDavTestServer implements HttpClientAdapter {
  final files = <String, String>{};
  final etags = <String, String>{};
  final directories = <String>{};
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];
  FutureOr<ResponseBody?> Function(RequestOptions, List<int>)? beforeRequest;
  String? Function(RequestOptions, String?)? etagHeader;
  bool ignoreIfNoneMatch = false;
  bool bareEtags = false;
  int moveConflictStatus = 412;
  int _revision = 0;

  String _nextEtag() {
    final value = 'revision-${++_revision}';
    return bareEtags ? value : '"$value"';
  }

  bool isHistory(Uri uri) =>
      uri.path.endsWith('/fzu-assistant-history.json') ||
      uri.path.contains('/fzu-assistant-history/');

  void seed(Uri uri, Object data) {
    files[uri.path] = data is String ? data : jsonEncode(data);
    etags[uri.path] = _nextEtag();
    directories.add(uri.resolve('.').path);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data = requestStream == null
        ? <int>[]
        : await requestStream.expand((chunk) => chunk).toList();
    bodies.add(data);
    final override = await beforeRequest?.call(options, data);
    if (override != null) return override;
    final path = options.uri.path;
    final existing = files[path];
    if (options.method == 'GET') {
      final etag = etagHeader == null
          ? etags[path]
          : etagHeader!(options, etags[path]);
      return ResponseBody.fromString(
        existing ?? '',
        existing == null ? 404 : 200,
        headers: {
          if (etag != null) 'etag': [etag],
        },
      );
    }
    if (options.method == 'PROPFIND') {
      if (options.headers['Depth'] != '1') {
        throw StateError('PROPFIND must use Depth: 1');
      }
      if (!directories.contains(path)) return ResponseBody.fromString('', 404);
      return ResponseBody.fromString(
        webDavListing([
          (path, true),
          for (final file in files.keys)
            if (file.startsWith(path) &&
                !file.substring(path.length).contains('/'))
              (file, false),
        ]),
        207,
        headers: {
          'content-type': ['application/xml; charset=utf-8'],
        },
      );
    }
    if (options.method == 'MKCOL') {
      final created = directories.add(path);
      return ResponseBody.fromString('', created ? 201 : 405);
    }
    if (options.method == 'PUT') {
      final match = options.headers['If-Match'];
      if ((!ignoreIfNoneMatch &&
              options.headers['If-None-Match'] == '*' &&
              existing != null) ||
          (match != null && match != etags[path])) {
        return ResponseBody.fromString('', 412);
      }
      files[path] = utf8.decode(data);
      etags[path] = _nextEtag();
      directories.add(options.uri.resolve('.').path);
      return ResponseBody.fromString(
        '',
        existing == null ? 201 : 204,
        headers: {
          'etag': [etags[path]!],
        },
      );
    }
    if (options.method == 'MOVE') {
      final destination = Uri.parse(options.headers['Destination'] as String);
      if (destination.origin != options.uri.origin ||
          destination.userInfo.isNotEmpty ||
          destination.hasQuery ||
          destination.hasFragment ||
          options.headers['Overwrite'] != 'F') {
        throw StateError('Unsafe MOVE destination or overwrite mode');
      }
      if (existing == null) return ResponseBody.fromString('', 404);
      if (files.containsKey(destination.path)) {
        return ResponseBody.fromString('', moveConflictStatus);
      }
      files[destination.path] = files.remove(path)!;
      etags[destination.path] = etags.remove(path)!;
      directories.add(destination.resolve('.').path);
      return ResponseBody.fromString('', 201);
    }
    if (options.method == 'DELETE') {
      if (files.remove(path) != null) {
        etags.remove(path);
        return ResponseBody.fromString('', 204);
      }
      if (!directories.contains(path)) return ResponseBody.fromString('', 404);
      // Refuse recursive deletion so cleanup tests catch unknown children.
      if (files.keys.any((file) => file.startsWith(path)) ||
          directories.any((child) => child != path && child.startsWith(path))) {
        return ResponseBody.fromString('', 409);
      }
      directories.remove(path);
      return ResponseBody.fromString('', 204);
    }
    throw StateError('Unexpected request ${options.method} ${options.uri}');
  }

  @override
  void close({bool force = false}) {}
}
