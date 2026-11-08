import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A conditional WebDAV store shared by protocol tests. It never hides history
/// requests in tests that cover history, but lets older focused tests route
/// their existing main-file responses independently.
class WebDavTestServer implements HttpClientAdapter {
  final files = <String, String>{};
  final etags = <String, String>{};
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];
  FutureOr<ResponseBody?> Function(RequestOptions, List<int>)? beforeRequest;
  int _revision = 0;

  bool isHistory(Uri uri) =>
      uri.path.endsWith('/fzu-assistant-history.json') ||
      RegExp(r'/fzu-assistant-history/[a-f0-9]{64}\.json$').hasMatch(uri.path);

  void seed(Uri uri, Object data) {
    files[uri.path] = data is String ? data : jsonEncode(data);
    etags[uri.path] = '"revision-${++_revision}"';
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
      return ResponseBody.fromString(
        existing ?? '',
        existing == null ? 404 : 200,
        headers: {
          if (etags[path] != null) 'etag': [etags[path]!],
        },
      );
    }
    if (options.method == 'MKCOL') return ResponseBody.fromString('', 201);
    if (options.method == 'PUT') {
      final match = options.headers['If-Match'];
      if ((options.headers['If-None-Match'] == '*' && existing != null) ||
          (match != null && match != etags[path])) {
        return ResponseBody.fromString('', 412);
      }
      files[path] = utf8.decode(data);
      etags[path] = '"revision-${++_revision}"';
      return ResponseBody.fromString(
        '',
        existing == null ? 201 : 204,
        headers: {
          'etag': [etags[path]!],
        },
      );
    }
    throw StateError('Unexpected request ${options.method} ${options.uri}');
  }

  @override
  void close({bool force = false}) {}
}
