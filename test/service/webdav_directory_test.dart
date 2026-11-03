import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DirectoryAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final uploads = <List<int>>[];
  late ResponseBody Function(RequestOptions request) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length > 30) throw StateError('Directory retry did not stop');
    if (requestStream != null) {
      uploads.add(await requestStream.expand((chunk) => chunk).toList());
    }
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _status(int code, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromString('', code, headers: headers);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const config = WebDavConfig(
    directory: 'https://dav.example/dav/fzu/',
    username: 'student',
    password: 'secret',
  );
  late _DirectoryAdapter adapter;
  late WebDavSyncService service;
  late WebDavSnapshot snapshot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    adapter = _DirectoryAdapter();
    service = WebDavSyncService(dio: Dio()..httpClientAdapter = adapter);
    snapshot = await service.exportSnapshot();
  });
  tearDown(() => service.dio.close(force: true));

  Future<void> upload({
    WebDavConfig target = config,
    WebDavRemote previous = const WebDavRemote(snapshot: null),
  }) => service.upload(target, snapshot, previous);

  List<String> getMethods() =>
      adapter.requests.map((request) => request.method).toList();

  void expectConfinedRequests() {
    for (final request in adapter.requests) {
      expect(request.uri.origin, 'https://dav.example');
      expect(request.followRedirects, isFalse);
      expect(
        request.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('student:secret'))}',
      );
    }
  }

  test('an existing writable directory does not trigger MKCOL', () async {
    adapter.respond = (_) => _status(204);
    await upload();
    expect(getMethods(), ['PUT']);
    expect(adapter.requests.single.headers['If-None-Match'], '*');
    expectConfinedRequests();
  });

  test(
    '409 creates the selected directory and retries the same upload once',
    () async {
      var puts = 0;
      adapter.respond = (request) =>
          _status(request.method == 'PUT' && puts++ == 0 ? 409 : 201);
      await upload();
      expect(getMethods(), ['PUT', 'MKCOL', 'PUT']);
      expect(adapter.requests[1].uri, config.fileUri.resolve('.'));
      expect(adapter.requests.first.uri, config.fileUri);
      expect(adapter.requests.last.uri, config.fileUri);
      for (final request in adapter.requests.where(
        (item) => item.method == 'PUT',
      )) {
        expect(request.headers['If-None-Match'], '*');
      }
      expect(adapter.uploads, hasLength(2));
      expect(adapter.uploads[0], adapter.uploads[1]);
      expect(jsonDecode(utf8.decode(adapter.uploads.last)), snapshot.toJson());
      expectConfinedRequests();
    },
  );

  test(
    'missing ancestors are created from the existing parent downwards',
    () async {
      const nested = WebDavConfig(
        directory: 'https://dav.example/dav/team/fzu/',
        username: 'student',
        password: 'secret',
      );
      final existing = {'https://dav.example/dav/'};
      adapter.respond = (request) {
        if (request.method == 'PUT') {
          return _status(
            existing.contains(nested.fileUri.resolve('.').toString())
                ? 201
                : 409,
          );
        }
        final uri = request.uri;
        if (existing.contains(uri.toString())) return _status(405);
        if (!existing.contains(uri.resolve('..').toString())) {
          return _status(409);
        }
        existing.add(uri.toString());
        return _status(201);
      };
      await upload(target: nested);
      expect(
        adapter.requests
            .map((item) => '${item.method} ${item.uri.path}')
            .toList(),
        [
          'PUT /dav/team/fzu/fzu-assistant-sync.json',
          'MKCOL /dav/team/fzu/',
          'MKCOL /dav/team/',
          'MKCOL /dav/team/fzu/',
          'PUT /dav/team/fzu/fzu-assistant-sync.json',
        ],
      );
      expect(
        existing,
        containsAll([
          'https://dav.example/dav/team/',
          'https://dav.example/dav/team/fzu/',
        ]),
      );
      expectConfinedRequests();
    },
  );

  test(
    'an existing collection returned as 405 permits one PUT retry',
    () async {
      var puts = 0;
      adapter.respond = (request) {
        if (request.method == 'MKCOL') return _status(405);
        return _status(puts++ == 0 ? 409 : 201);
      };
      await upload();
      expect(getMethods(), ['PUT', 'MKCOL', 'PUT']);
      expect(adapter.requests[1].uri, config.fileUri.resolve('.'));
    },
  );

  test('directory repair retains existing-backup ETag protection', () async {
    var puts = 0;
    adapter.respond = (request) =>
        _status(request.method == 'PUT' && puts++ == 0 ? 409 : 201);
    await upload(
      previous: WebDavRemote(snapshot: snapshot, etag: '"original"'),
    );
    final putsMade = adapter.requests.where((item) => item.method == 'PUT');
    expect(putsMade, hasLength(2));
    for (final request in putsMade) {
      expect(request.headers['If-Match'], '"original"');
      expect(request.headers.containsKey('If-None-Match'), isFalse);
    }
  });

  test(
    'encoded Unicode directory paths are not double encoded during creation',
    () async {
      const encoded = WebDavConfig(
        directory: 'https://dav.example/dav/%E8%AF%BE%E8%A1%A8/',
        username: 'student',
        password: 'secret',
      );
      var puts = 0;
      adapter.respond = (request) =>
          _status(request.method == 'PUT' && puts++ == 0 ? 409 : 201);
      await upload(target: encoded);
      expect(
        adapter.requests[1].uri.toString(),
        'https://dav.example/dav/%E8%AF%BE%E8%A1%A8/',
      );
      expect(adapter.requests.last.uri, encoded.fileUri);
      expectConfinedRequests();
    },
  );

  for (final code in [401, 403]) {
    test(
      'PUT authentication failure $code never attempts to create folders',
      () async {
        adapter.respond = (_) => _status(code);
        await expectLater(upload(), throwsException);
        expect(getMethods(), ['PUT']);
      },
    );
  }

  test(
    'MKCOL permission failure stops without retrying PUT or deleting',
    () async {
      adapter.respond = (request) =>
          _status(request.method == 'PUT' ? 409 : 403);
      await expectLater(upload(), throwsException);
      expect(getMethods(), ['PUT', 'MKCOL']);
    },
  );

  test('MKCOL redirects are not followed with credentials', () async {
    adapter.respond = (request) => request.method == 'PUT'
        ? _status(409)
        : _status(
            301,
            headers: {
              'location': ['https://elsewhere.example/stolen/'],
            },
          );
    await expectLater(upload(), throwsException);
    expect(getMethods(), ['PUT', 'MKCOL']);
    expectConfinedRequests();
  });

  test('a second PUT conflict does not restart directory repair', () async {
    adapter.respond = (request) => _status(request.method == 'PUT' ? 409 : 201);
    await expectLater(upload(), throwsException);
    expect(getMethods(), ['PUT', 'MKCOL', 'PUT']);
  });

  test(
    'uncreatable ancestors stop at the origin instead of recursing forever',
    () async {
      adapter.respond = (_) => _status(409);
      await expectLater(upload(), throwsException);
      expect(adapter.requests.length, lessThanOrEqualTo(6));
      expect(
        adapter.requests.where((request) => request.method == 'PUT'),
        hasLength(1),
      );
      expect(
        adapter.requests.where((request) => request.method == 'DELETE'),
        isEmpty,
      );
      expectConfinedRequests();
    },
  );

  test(
    'GET 409 reports no backup without creating a directory during reading',
    () async {
      adapter.respond = (_) => _status(409);
      final remote = await service.readRemote(config);
      expect(remote.snapshot, isNull);
      expect(getMethods(), ['GET']);
    },
  );

  test(
    'connection testing repairs its directory and deletes only its probe file',
    () async {
      var puts = 0;
      adapter.respond = (request) {
        if (request.method == 'PUT') return _status(puts++ == 0 ? 409 : 201);
        if (request.method == 'GET') {
          return ResponseBody.fromBytes(adapter.uploads.last, 200);
        }
        return _status(request.method == 'MKCOL' ? 201 : 204);
      };
      await service.testConnection(config);
      expect(getMethods(), ['PUT', 'MKCOL', 'PUT', 'GET', 'DELETE']);
      final probe = adapter.requests.first.uri;
      expect(probe, isNot(config.fileUri));
      expect(
        probe.pathSegments.last,
        matches(r'^fzu-assistant-test-[0-9a-f]{32}\.tmp$'),
      );
      expect(adapter.requests[1].uri, config.fileUri.resolve('.'));
      expect(adapter.requests.last.uri, probe);
      expect(adapter.uploads[0], adapter.uploads[1]);
      expectConfinedRequests();
    },
  );
}
