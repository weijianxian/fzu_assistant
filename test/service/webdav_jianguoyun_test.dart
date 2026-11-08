import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'webdav_test_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const config = WebDavConfig(
    directory: 'https://dav.jianguoyun.com/dav/fzu_assistant/',
    username: 'local-test',
    password: 'local-test-only',
  );
  final root = config.fileUri.resolve('.');
  late WebDavTestServer server;
  late WebDavSyncService service;
  var generation = 0;

  WebDavSnapshot snapshot(String mode) => WebDavSnapshot.fromJson({
    'format': WebDavSyncService.format,
    'schemaVersion': 2,
    'createdAt': '2026-11-09T00:00:00Z',
    'values': {...WebDavSyncService.defaults, SpKeys.themeMode: mode},
  });

  String idOf(WebDavSnapshot value) =>
      sha256.convert(utf8.encode(jsonEncode(value.toJson()))).toString();
  Uri historyUri(WebDavSnapshot value, {bool metadata = false}) => root.resolve(
    'fzu-assistant-history/'
    '${metadata ? 'metadata/' : ''}${idOf(value)}.json',
  );
  bool isStage(Uri uri) =>
      RegExp(r'/fzu-assistant-upload-[a-f0-9]{32}/(?:payload)?$')
          .hasMatch(uri.path);
  Future<void> publish(WebDavSnapshot value) =>
      service.upload(config, value, const WebDavRemote(snapshot: null));
  Iterable<RequestOptions> getMoves() =>
      server.requests.where((request) => request.method == 'MOVE');
  void expectCleanStages() {
    expect(
      server.files.keys.where(
        (path) => path.contains('/fzu-assistant-upload-'),
      ),
      isEmpty,
    );
    expect(
      server.directories.where(
        (path) => path.contains('/fzu-assistant-upload-'),
      ),
      isEmpty,
    );
  }

  void expectConfined() {
    for (final request in server.requests) {
      expect(request.uri.origin, root.origin);
      expect(request.uri.path, startsWith(root.path));
      expect(request.followRedirects, isFalse);
      if (request.method == 'MOVE') {
        final target = Uri.parse(request.headers['Destination'] as String);
        expect(target.origin, root.origin);
        expect(target.path, startsWith(root.path));
        expect(target.userInfo, isEmpty);
        expect(target.hasQuery || target.hasFragment, isFalse);
        expect(request.headers['Overwrite'], 'F');
        expect(request.headers['Content-Length'], 0);
      }
      if (request.method == 'MKCOL' && isStage(request.uri)) {
        expect(request.uri.resolve('../'), root);
      }
    }
  }

  Future<Object> failureOf(Future<void> operation) async {
    try {
      await operation;
    } catch (error) {
      return error;
    }
    throw StateError('Expected operation to fail');
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await CustomCourseStore.instance.load();
    generation = 0;
    server = WebDavTestServer()
      ..ignoreIfNoneMatch = true
      ..bareEtags = true
      ..moveConflictStatus = 409
      ..directories.add(root.path);
    service = WebDavSyncService(
      dio: Dio()..httpClientAdapter = server,
      captureAccountValidity: () {
        final captured = generation;
        return () => generation == captured;
      },
    );
  });
  tearDown(() => service.dio.close(force: true));

  test('all first creates use MOVE, despite ignored If-None-Match', () async {
    final a = snapshot('light');
    await publish(a);
    expect(
      getMoves().map((request) => request.headers['Destination']).toSet(),
      {
        config.fileUri.toString(),
        historyUri(a).toString(),
        historyUri(a, metadata: true).toString(),
      },
    );
    final puts = server.requests.where((request) => request.method == 'PUT');
    expect(puts, hasLength(3));
    expect(puts.every((request) => isStage(request.uri)), isTrue);
    expect(
      puts.every((request) => !request.headers.containsKey('If-None-Match')),
      isTrue,
    );
    expect(jsonDecode(server.files[config.fileUri.path]!), a.toJson());
    final history = await service.listHistory(config);
    expect(history.single.id, idOf(a));
    expectCleanStages();
    expectConfined();
  });

  test(
    'bare updates work; stale 412 and MOVE 409 preserve both histories',
    () async {
      final a = snapshot('light');
      final b = snapshot('dark');
      await publish(a);
      final remoteA = await service.readRemote(config);
      final originalMetadata = server.files[historyUri(a, metadata: true).path];
      await service.upload(config, b, remoteA);
      final update = server.requests.lastWhere(
        (request) => request.method == 'PUT' && request.uri == config.fileUri,
      );
      expect(update.headers['If-Match'], remoteA.etag);
      expect(update.headers['If-Match'], isNot(startsWith('"')));
      expect(
        server.files[historyUri(a, metadata: true).path],
        originalMetadata,
      );
      final failure = await failureOf(service.upload(config, a, remoteA));
      expect(failure.toString(), contains('远端文件已改变'));
      expect(jsonDecode(server.files[config.fileUri.path]!), b.toJson());
      expect(
        server.files[historyUri(a, metadata: true).path],
        originalMetadata,
      );
      final history = await service.listHistory(config);
      expect(history.map((entry) => entry.id).toSet(), {idOf(a), idOf(b)});
      for (final entry in history) {
        expect(
          (await service.readHistorySnapshot(config, entry)).toJson(),
          (entry.id == idOf(a) ? a : b).toJson(),
        );
      }
      expectCleanStages();
      expectConfined();
    },
  );

  test(
    'a main-file creation race maps MOVE 409 to conflict, without repair',
    () async {
      final winner = snapshot('dark');
      var raced = false;
      server.beforeRequest = (request, _) {
        if (request.method == 'MOVE' &&
            request.headers['Destination'] == config.fileUri.toString()) {
          server.seed(config.fileUri, winner.toJson());
          raced = true;
        }
        return null;
      };
      final failure = await failureOf(publish(snapshot('light')));
      expect(raced, isTrue);
      expect(failure.toString(), contains('远端文件已改变'));
      expect(jsonDecode(server.files[config.fileUri.path]!), winner.toJson());
      expect(
        server.requests.where(
          (request) => request.uri.path == '/dav/' || request.uri.path == '/',
        ),
        isEmpty,
      );
      expect(
        getMoves().where(
          (request) =>
              request.headers['Destination'] == config.fileUri.toString(),
        ),
        hasLength(1),
      );
      expectCleanStages();
    },
  );

  for (final metadata in [false, true]) {
    test(
      'conflicting corrupt ${metadata ? 'metadata' : 'snapshot'} blocks main update',
      () async {
        final a = snapshot('light');
        final b = snapshot('dark');
        server.seed(config.fileUri, a.toJson());
        final previous = await service.readRemote(config);
        final conflict = historyUri(b, metadata: metadata);
        server.beforeRequest = (request, _) {
          if (request.method == 'MOVE' &&
              request.headers['Destination'] == conflict.toString()) {
            server.seed(conflict, {'unrelated': 'keep'});
          }
          return null;
        };
        await expectLater(
          service.upload(config, b, previous),
          throwsFormatException,
        );
        expect(jsonDecode(server.files[config.fileUri.path]!), a.toJson());
        expect(jsonDecode(server.files[conflict.path]!), {'unrelated': 'keep'});
        expect(
          server.requests.where(
            (request) =>
                request.method == 'PUT' && request.uri == config.fileUri,
          ),
          isEmpty,
        );
        expectCleanStages();
      },
    );
  }

  test(
    'connection testing creates by MOVE and deletes only its own resources',
    () async {
      await service.testConnection(config);
      expect(getMoves(), hasLength(1));
      final destination = Uri.parse(
        getMoves().single.headers['Destination'] as String,
      );
      expect(
        destination.path,
        matches(r'/fzu-assistant-test-[a-f0-9]{32}\.tmp$'),
      );
      expect(server.files, isEmpty);
      expect(server.directories, {root.path});
      expectConfined();
    },
  );

  test(
    'a connection-file MOVE 409 never deletes the other writer target',
    () async {
      Uri? target;
      server.beforeRequest = (request, _) {
        if (request.method == 'MOVE') {
          target = Uri.parse(request.headers['Destination'] as String);
          server.seed(target!, 'other-writer');
        }
        return null;
      };
      await expectLater(service.testConnection(config), throwsException);
      expect(server.files[target!.path], 'other-writer');
      expect(
        server.requests.where(
          (request) => request.method == 'DELETE' && request.uri == target,
        ),
        isEmpty,
      );
      expectCleanStages();
    },
  );

  test(
    'MOVE 201 plus staging cleanup failure still removes the connection target',
    () async {
      Uri? stage;
      Uri? target;
      server.beforeRequest = (request, _) {
        if (request.method == 'MOVE') {
          stage = request.uri.resolve('.');
          target = Uri.parse(request.headers['Destination'] as String);
        }
        if (request.method == 'DELETE' && request.uri == stage) {
          return ResponseBody.fromString('', 403);
        }
        return null;
      };
      final failure = await failureOf(service.testConnection(config));
      expect(failure.toString(), contains(stage!.path));
      expect(failure.toString(), contains(target!.path));
      expect(failure.toString(), contains('已清理'));
      expect(server.files.containsKey(target!.path), isFalse);
      expect(server.directories, contains(stage!.path));
      expect(
        server.requests.where(
          (request) => request.method == 'DELETE' && request.uri == target,
        ),
        hasLength(1),
      );
    },
  );

  for (final failTargetDelete in [false, true]) {
    test(
      'MOVE 201 broken response retains connection target ownership; delete failure=$failTargetDelete',
      () async {
        Uri? target;
        server.beforeRequest = (request, _) {
          if (request.method == 'MOVE') {
            target = Uri.parse(request.headers['Destination'] as String);
            server.files[target!.path] = server.files.remove(request.uri.path)!;
            server.etags[target!.path] = server.etags.remove(request.uri.path)!;
            return ResponseBody(
              Stream.error(StateError('broken MOVE response')),
              201,
            );
          }
          if (failTargetDelete &&
              request.method == 'DELETE' &&
              request.uri == target) {
            return ResponseBody.fromString('', 403);
          }
          return null;
        };
        final failure = await failureOf(service.testConnection(config));
        expect(failure.toString(), contains('创建确认失败'));
        expect(failure.toString(), contains(target!.path));
        expect(failure.toString(), isNot(contains('结果未知')));
        expect(failure.toString(), contains(failTargetDelete ? '清理失败' : '已清理'));
        expect(server.files.containsKey(target!.path), failTargetDelete);
        expect(
          server.requests.where(
            (request) => request.method == 'DELETE' && request.uri == target,
          ),
          hasLength(1),
        );
        expect(getMoves(), hasLength(1));
        expectCleanStages();
      },
    );
  }

  for (final mainTarget in [false, true]) {
    test(
      'MOVE 201 broken response never rolls back published ${mainTarget ? 'main' : 'history'}',
      () async {
        final a = snapshot('light');
        final target = mainTarget ? config.fileUri : historyUri(a);
        server.beforeRequest = (request, _) {
          if (request.method == 'MOVE' &&
              request.headers['Destination'] == target.toString()) {
            server.files[target.path] = server.files.remove(request.uri.path)!;
            server.etags[target.path] = server.etags.remove(request.uri.path)!;
            return ResponseBody(
              Stream.error(StateError('broken MOVE response')),
              201,
            );
          }
          return null;
        };
        final failure = await failureOf(publish(a));
        expect(failure.toString(), contains('创建确认失败'));
        expect(failure.toString(), contains('已确认创建目标 ${target.path}'));
        expect(failure.toString(), isNot(contains('结果未知')));
        expect(jsonDecode(server.files[target.path]!), a.toJson());
        expect(
          server.requests.where(
            (request) => request.method == 'DELETE' && request.uri == target,
          ),
          isEmpty,
        );
        expectCleanStages();
      },
    );
  }

  test('staging MKCOL 405 never grants ownership or permits cleanup', () async {
    Uri? unowned;
    server.beforeRequest = (request, _) {
      if (request.method == 'MKCOL' && isStage(request.uri)) {
        unowned = request.uri;
        server.directories.add(request.uri.path);
        server.seed(request.uri.resolve('keep'), 'existing');
        return ResponseBody.fromString('', 405);
      }
      return null;
    };
    await expectLater(service.testConnection(config), throwsException);
    expect(server.files[unowned!.resolve('keep').path], 'existing');
    expect(
      server.requests.where(
        (request) => {'PUT', 'DELETE', 'MOVE'}.contains(request.method),
      ),
      isEmpty,
    );
  });

  test(
    'a staging payload failure cleans the exact owned file and directory',
    () async {
      server.beforeRequest = (request, _) =>
          request.method == 'PUT' ? ResponseBody.fromString('', 503) : null;
      await expectLater(service.testConnection(config), throwsException);
      expect(getMoves(), isEmpty);
      expect(server.files, isEmpty);
      expectCleanStages();
      expect(
        server.requests.where((request) => request.method == 'DELETE'),
        hasLength(2),
      );
    },
  );

  test('201 ownership survives an unreadable claim response stream', () async {
    server.beforeRequest = (request, _) {
      if (request.method == 'MKCOL' && isStage(request.uri)) {
        server.directories.add(request.uri.path);
        return ResponseBody(Stream.error(StateError('broken response')), 201);
      }
      return null;
    };
    await expectLater(service.testConnection(config), throwsException);
    expect(server.requests.map((request) => request.method), [
      'MKCOL',
      'DELETE',
    ]);
    expectCleanStages();
  });

  for (final accountChange in [false, true]) {
    test(
      '${accountChange ? 'account' : 'configuration'} invalidation before MOVE cleans staging and retains main',
      () async {
        final a = snapshot('light');
        server.seed(config.fileUri, a.toJson());
        final previous = await service.readRemote(config);
        server.beforeRequest = (request, _) async {
          if (request.method == 'PUT' && isStage(request.uri)) {
            if (accountChange) {
              generation++;
            } else {
              await service.saveConfig(
                const WebDavConfig(
                  directory: 'https://dav.example/changed/',
                  username: 'new-user',
                  password: 'new-test-only',
                ),
              );
            }
          }
          return null;
        };
        await expectLater(
          service.upload(config, snapshot('dark'), previous),
          throwsA(isA<WebDavLocalChanged>()),
        );
        expect(getMoves(), isEmpty);
        expect(jsonDecode(server.files[config.fileUri.path]!), a.toJson());
        expectCleanStages();
        expectConfined();
      },
    );
  }

  test(
    'configuration invalidation after MOVE 201 retains WebDavLocalChanged',
    () async {
      final a = snapshot('light');
      server.seed(config.fileUri, a.toJson());
      final previous = await service.readRemote(config);
      Uri? published;
      server.beforeRequest = (request, _) async {
        if (request.method == 'MOVE' && published == null) {
          published = Uri.parse(request.headers['Destination'] as String);
          await service.saveConfig(config);
        }
        return null;
      };
      await expectLater(
        service.upload(config, snapshot('dark'), previous),
        throwsA(isA<WebDavLocalChanged>()),
      );
      expect(server.files.containsKey(published!.path), isTrue);
      expect(
        server.requests.where(
          (request) => request.method == 'DELETE' && request.uri == published,
        ),
        isEmpty,
      );
      expect(jsonDecode(server.files[config.fileUri.path]!), a.toJson());
      expectCleanStages();
    },
  );

  test(
    'unknown MOVE result is not retried or deleted; owned staging is cleaned',
    () async {
      Uri? target;
      server.beforeRequest = (request, _) {
        if (request.method == 'MOVE') {
          target = Uri.parse(request.headers['Destination'] as String);
          server.seed(target!, server.files.remove(request.uri.path)!);
          server.etags.remove(request.uri.path);
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return null;
      };
      final failure = await failureOf(service.testConnection(config));
      expect(failure.toString(), contains('创建结果未知'));
      expect(failure.toString(), contains(target!.path));
      expect(server.files.containsKey(target!.path), isTrue);
      expect(getMoves(), hasLength(1));
      expect(
        server.requests.where(
          (request) => request.method == 'DELETE' && request.uri == target,
        ),
        isEmpty,
      );
      expectCleanStages();
    },
  );

  test(
    'unknown MKCOL result reports possible unowned collection without cleanup',
    () async {
      Uri? uncertain;
      server.beforeRequest = (request, _) {
        if (request.method == 'MKCOL') {
          uncertain = request.uri;
          server.directories.add(request.uri.path);
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return null;
      };
      final failure = await failureOf(service.testConnection(config));
      expect(failure.toString(), contains('临时目录创建结果未知'));
      expect(failure.toString(), contains(uncertain!.path));
      expect(server.requests.map((request) => request.method), ['MKCOL']);
    },
  );

  for (final path in ['/', '/dav/']) {
    test('official account root $path is rejected before any writes', () async {
      final target = WebDavConfig(
        directory: 'https://dav.jianguoyun.com$path',
        username: config.username,
        password: config.password,
      );
      await expectLater(service.testConnection(target), throwsException);
      await expectLater(
        service.upload(
          target,
          snapshot('light'),
          const WebDavRemote(snapshot: null),
        ),
        throwsException,
      );
      expect(server.requests, isEmpty);
    });
  }

  for (final etag in [
    null,
    'W/"weak"',
    'w/bare',
    '*',
    'one,two',
    ' bare ',
    'a\\b',
    '"one", "two"',
  ]) {
    test(
      'unsafe Jianguoyun validator $etag cannot initiate any writes',
      () async {
        final a = snapshot('light');
        server.seed(config.fileUri, a.toJson());
        server.etagHeader = (_, _) => etag;
        final previous = await service.readRemote(config);
        await expectLater(
          service.upload(config, snapshot('dark'), previous),
          throwsException,
        );
        expect(server.requests.map((request) => request.method), ['GET']);
      },
    );
  }

  for (final directory in [
    'https://dav.example/dav/fzu/',
    'https://dav.jianguoyun.com.evil/dav/fzu/',
    'http://dav.jianguoyun.com/dav/fzu/',
    'https://dav.jianguoyun.com:444/dav/fzu/',
    'https://dav.jianguoyun.com/other/fzu/',
  ]) {
    test('bare-tag compatibility does not extend to $directory', () async {
      final target = WebDavConfig(
        directory: directory,
        username: config.username,
        password: config.password,
      );
      server.seed(target.fileUri, snapshot('light').toJson());
      final previous = await service.readRemote(target);
      await expectLater(
        service.upload(target, snapshot('dark'), previous),
        throwsException,
      );
      expect(server.requests.map((request) => request.method), ['GET']);
    });
  }

  test('automatic upload uses the same raw If-Match compatibility', () async {
    final a = snapshot('system');
    await publish(a);
    await service.saveConfig(config);
    await service.setAutoSyncEnabled(true);
    await service.rememberSynced(config, a);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(SpKeys.themeMode, 'dark');
    expect(
      await service.autoSync(apply: (_) {}),
      WebDavAutoSyncResult.uploaded,
    );
    final main = server.requests.lastWhere(
      (request) => request.method == 'PUT' && request.uri == config.fileUri,
    );
    expect(main.headers['If-Match'], startsWith('revision-'));
    expectCleanStages();
  });
}
