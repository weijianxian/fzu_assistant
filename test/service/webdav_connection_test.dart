import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ProbeAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final statuses = <String, int>{'PUT': 201, 'GET': 200, 'DELETE': 204};
  final headers = <String, Map<String, List<String>>>{};
  String? getBody;
  String? failMethod;
  List<int> uploaded = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      uploaded = await requestStream.expand((chunk) => chunk).toList();
    }
    if (options.method == failMethod) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
    }
    return ResponseBody.fromString(
      options.method == 'GET' ? getBody ?? utf8.decode(uploaded) : '',
      statuses[options.method]!,
      headers: headers[options.method] ?? {},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WebDavSyncService service;
  late _ProbeAdapter adapter;
  const config = WebDavConfig(
    directory: 'https://dav.example/user/fzu',
    username: 'student',
    password: 'secret',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    adapter = _ProbeAdapter();
    service = WebDavSyncService(dio: Dio()..httpClientAdapter = adapter);
  });
  tearDown(() => service.dio.close(force: true));

  test(
    'connection probe verifies read/write and removes only its random file',
    () async {
      await service.testConnection(config);
      expect(adapter.requests.map((request) => request.method), [
        'PUT',
        'GET',
        'DELETE',
      ]);
      final target = adapter.requests.first.uri;
      expect(target.origin, 'https://dav.example');
      expect(
        target.path,
        matches(r'^/user/fzu/fzu-assistant-test-[0-9a-f]{32}\.tmp$'),
      );
      expect(target, isNot(config.fileUri));
      expect(adapter.requests.map((request) => request.uri).toSet(), {target});
      expect(adapter.requests.first.headers['If-None-Match'], '*');
      for (final request in adapter.requests) {
        expect(request.followRedirects, isFalse);
        expect(
          request.headers['Authorization'],
          'Basic ${base64Encode(utf8.encode('student:secret'))}',
        );
      }
      expect(adapter.uploaded, isNotEmpty);
      expect(adapter.uploaded.length, lessThanOrEqualTo(1024));
      expect(utf8.decode(adapter.uploaded), isNot(contains('secret')));
    },
  );

  test('each probe uses a different file and never saves inputs or exports app data', () async {
    const saved = {
      'webdav_directory': 'https://saved.example/keep/',
      'webdav_username': 'saved-user',
      'custom_courses_v1': 'private-course-data',
      'webdav_sync_baseline': 'preserved-baseline',
    };
    SharedPreferences.setMockInitialValues(saved);
    FlutterSecureStorage.setMockInitialValues({
      'fzu_webdav_password': 'saved-password',
    });
    await service.testConnection(config);
    await service.testConnection(config);
    final created = adapter.requests
        .where((request) => request.method == 'PUT')
        .map((request) => request.uri)
        .toList();
    expect(created.toSet(), hasLength(2));
    final preferences = await SharedPreferences.getInstance();
    expect({
      for (final key in preferences.getKeys()) key: preferences.get(key),
    }, saved);
    expect((await service.loadConfig()).password, 'saved-password');
    expect(
      utf8.decode(adapter.uploaded),
      isNot(contains('private-course-data')),
    );
  });

  for (final status in [200, 204]) {
    test('PUT $status is accepted before verification and cleanup', () async {
      adapter.statuses['PUT'] = status;
      await service.testConnection(config);
      expect(adapter.requests.last.method, 'DELETE');
    });
  }

  for (final status in [401, 403, 404, 412]) {
    test(
      'PUT $status fails without deleting an uncreated or existing file',
      () async {
        adapter.statuses['PUT'] = status;
        await expectLater(service.testConnection(config), throwsException);
        expect(adapter.requests.map((request) => request.method), ['PUT']);
      },
    );
  }

  test('a PUT redirect is rejected without forwarding credentials', () async {
    adapter.statuses['PUT'] = 302;
    adapter.headers['PUT'] = {
      'location': ['https://another.example/private'],
    };
    await expectLater(service.testConnection(config), throwsException);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.followRedirects, isFalse);
    expect(adapter.requests.single.uri.host, 'dav.example');
  });

  for (final status in [401, 404, 500, 302]) {
    test('GET $status fails and still cleans up its created file', () async {
      adapter.statuses['GET'] = status;
      adapter.headers['GET'] = {
        'location': ['https://another.example/login'],
      };
      await expectLater(service.testConnection(config), throwsException);
      expect(adapter.requests.map((request) => request.method), [
        'PUT',
        'GET',
        'DELETE',
      ]);
      expect(
        adapter.requests.every((request) => request.uri.host == 'dav.example'),
        isTrue,
      );
    });
  }

  test(
    'a login page returned as HTTP 200 cannot pass the content check',
    () async {
      adapter.getBody = '<html><form>Sign in</form></html>';
      await expectLater(service.testConnection(config), throwsException);
      expect(adapter.requests.last.method, 'DELETE');
    },
  );

  test('oversized probe responses fail and are cleaned up', () async {
    adapter.getBody = 'x' * 1025;
    await expectLater(service.testConnection(config), throwsException);
    expect(adapter.requests.last.method, 'DELETE');
  });

  test('GET transport errors still clean up a confirmed upload', () async {
    adapter.failMethod = 'GET';
    await expectLater(service.testConnection(config), throwsException);
    expect(adapter.requests.last.method, 'DELETE');
  });

  for (final status in [200, 204, 404]) {
    test('DELETE $status confirms the temporary file is gone', () async {
      adapter.statuses['DELETE'] = status;
      await service.testConnection(config);
      expect(adapter.requests.last.method, 'DELETE');
    });
  }

  test('cleanup failures report the test file requiring attention', () async {
    adapter.statuses['DELETE'] = 403;
    Object? failure;
    try {
      await service.testConnection(config);
    } catch (error) {
      failure = error;
    }
    expect(failure, isNotNull);
    expect(failure.toString(), contains('清理'));
    expect(
      failure.toString(),
      contains(adapter.requests.first.uri.pathSegments.last),
    );
  });

  test(
    'an uncertain PUT failure identifies a possibly retained test file',
    () async {
      adapter.failMethod = 'PUT';
      Object? failure;
      try {
        await service.testConnection(config);
      } catch (error) {
        failure = error;
      }
      expect(failure, isNotNull);
      expect(
        failure.toString(),
        contains(adapter.requests.first.uri.pathSegments.last),
      );
    },
  );

  test('invalid directory URLs are rejected before any request', () async {
    await expectLater(
      service.testConnection(
        const WebDavConfig(
          directory: 'https://user:password@dav.example/',
          username: '',
          password: '',
        ),
      ),
      throwsFormatException,
    );
    expect(adapter.requests, isEmpty);
  });
}
