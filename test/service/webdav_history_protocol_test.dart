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
    directory: 'https://dav.example/dav/fzu/',
    username: 'test',
    password: 'test-only',
  );
  final legacyUri = config.fileUri.resolve('fzu-assistant-history.json');
  final metadataDirectory = config.fileUri.resolve(
    'fzu-assistant-history/metadata/',
  );
  late WebDavTestServer server;
  late WebDavSyncService service;

  WebDavSnapshot snapshot(String mode) => WebDavSnapshot.fromJson({
    'format': WebDavSyncService.format,
    'schemaVersion': 2,
    'createdAt': '2026-11-09T00:00:00Z',
    'appVersion': {'version': '1.6.3', 'buildNumber': '176'},
    'values': {...WebDavSyncService.defaults, SpKeys.themeMode: mode},
  });

  String idOf(WebDavSnapshot value) =>
      sha256.convert(utf8.encode(jsonEncode(value.toJson()))).toString();

  Uri snapshotUri(WebDavSnapshot value) =>
      config.fileUri.resolve('fzu-assistant-history/${idOf(value)}.json');

  Uri metadataUri(WebDavSnapshot value) =>
      metadataDirectory.resolve('${idOf(value)}.json');

  Map<String, Object> entry(WebDavSnapshot value) => {
    'id': idOf(value),
    'createdAt': value.createdAt.toIso8601String(),
    'recordedAt': '2026-11-09T01:00:00Z',
    'schemaVersion': value.schemaVersion,
    'appVersion': value.appVersion!.toJson(),
    'customCourseCount': value.customCourseCount,
    'hiddenCourseCount': value.hiddenCourseCount,
    'reason': 'upload',
  };

  Map<String, Object> metadata(WebDavSnapshot value) => {
    'format': 'fzu-assistant-history-entry',
    'schemaVersion': 1,
    'entry': entry(value),
  };

  void seedPublished(WebDavSnapshot value) {
    server.seed(snapshotUri(value), value.toJson());
    server.seed(metadataUri(value), metadata(value));
  }

  Future<void> publish(WebDavSnapshot value) =>
      service.upload(config, value, const WebDavRemote(snapshot: null));

  Iterable<RequestOptions> puts() =>
      server.requests.where((request) => request.method == 'PUT');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await CustomCourseStore.instance.load();
    server = WebDavTestServer();
    service = WebDavSyncService(
      dio: Dio()..httpClientAdapter = server,
      captureAccountValidity: () =>
          () => true,
    );
  });
  tearDown(() => service.dio.close(force: true));

  test(
    'history works with no ETags; an existing main file stays protected',
    () async {
      server.etagHeader = (_, _) => null;
      final value = snapshot('light');
      await publish(value);
      final history = await service.listHistory(config);
      expect(history.single.id, idOf(value));
      expect(
        (await service.readHistorySnapshot(config, history.single)).toJson(),
        value.toJson(),
      );
      final previous = await service.readRemote(config);
      expect(previous.etag, isNull);
      server.requests.clear();
      await expectLater(
        service.upload(config, snapshot('dark'), previous),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('主同步文件') &&
                error.toString().contains('If-Match'),
          ),
        ),
      );
      expect(puts(), isEmpty);
      expect(jsonDecode(server.files[config.fileUri.path]!), value.toJson());
      await service.saveConfig(config);
      await service.setAutoSyncEnabled(true);
      await service.rememberSynced(config, value);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SpKeys.themeMode, 'dark');
      expect(
        await service.autoSync(apply: (_) {}),
        WebDavAutoSyncResult.manualUploadRequired,
      );
      expect(puts(), isEmpty);
    },
  );

  for (final etag in [
    null,
    'W/"weak"',
    'w/"weak"',
    '*',
    '"one", "two"',
    'bare',
  ]) {
    test(
      'main validator $etag cannot cause an unconditional overwrite',
      () async {
        final old = snapshot('light');
        server.seed(config.fileUri, old.toJson());
        server.etagHeader = (_, _) => etag;
        final previous = await service.readRemote(config);
        await expectLater(
          service.upload(config, snapshot('dark'), previous),
          throwsException,
        );
        expect(puts(), isEmpty);
        expect(jsonDecode(server.files[config.fileUri.path]!), old.toJson());
      },
    );
  }

  test(
    'main If-Match preserves opaque case and trims HTTP whitespace',
    () async {
      final old = snapshot('light');
      server.seed(config.fileUri, old.toJson());
      server.etags[config.fileUri.path] = '"MiXeD/revision-1"';
      server.etagHeader = (request, etag) =>
          request.uri == config.fileUri ? ' \t$etag\t ' : null;
      final previous = await service.readRemote(config);
      await service.upload(config, snapshot('dark'), previous);
      expect(puts().last.headers['If-Match'], '"MiXeD/revision-1"');
      expect(puts().last.headers.containsKey('If-None-Match'), isFalse);
    },
  );

  for (final legacyEtag in [null, 'W/"weak"']) {
    test('a legacy index with ETag $legacyEtag is merged read-only', () async {
      final old = snapshot('light');
      server.seed(snapshotUri(old), old.toJson());
      server.seed(legacyUri, {
        'format': 'fzu-assistant-history',
        'schemaVersion': 1,
        'entries': [entry(old)],
      });
      server.seed(config.fileUri, old.toJson());
      server.etagHeader = (request, etag) =>
          server.isHistory(request.uri) ? legacyEtag : etag;
      final indexBefore = server.files[legacyUri.path];
      final previous = await service.readRemote(config);
      await service.upload(config, snapshot('dark'), previous);
      final history = await service.listHistory(config);
      expect(history, hasLength(2));
      final legacy = history.singleWhere((item) => item.id == idOf(old));
      expect(
        (await service.readHistorySnapshot(config, legacy)).toJson(),
        old.toJson(),
      );
      expect(server.files[legacyUri.path], indexBefore);
      expect(puts().where((request) => request.uri == legacyUri), isEmpty);
      expect(
        puts()
            .where((request) => server.isHistory(request.uri))
            .every((request) => request.headers['If-None-Match'] == '*'),
        isTrue,
      );
    });
  }

  test(
    'new metadata and the legacy index deduplicate the same snapshot',
    () async {
      final value = snapshot('light');
      seedPublished(value);
      server.seed(legacyUri, {
        'format': 'fzu-assistant-history',
        'schemaVersion': 1,
        'entries': [entry(value)],
      });
      expect(await service.listHistory(config), hasLength(1));
      server.seed(metadataUri(value), {
        ...metadata(value),
        'entry': {...entry(value), 'customCourseCount': 1},
      });
      await expectLater(service.listHistory(config), throwsFormatException);
    },
  );

  test('concurrent independent appends survive a main-file 412', () async {
    final old = snapshot('light');
    final local = snapshot('dark');
    final other = snapshot('system');
    await publish(old);
    final previous = await service.readRemote(config);
    var raced = false;
    server.beforeRequest = (request, _) {
      if (!raced &&
          request.method == 'PUT' &&
          request.uri == metadataUri(local)) {
        raced = true;
        seedPublished(other);
        server.seed(config.fileUri, other.toJson());
      }
      return null;
    };
    await expectLater(
      service.upload(config, local, previous),
      throwsA(predicate((error) => error.toString().contains('远端文件已改变'))),
    );
    expect(raced, isTrue);
    expect((await service.listHistory(config)).map((item) => item.id).toSet(), {
      idOf(old),
      idOf(local),
      idOf(other),
    });
    expect(jsonDecode(server.files[config.fileUri.path]!), other.toJson());
    expect(puts().where((request) => request.uri == legacyUri), isEmpty);
  });

  for (final legacyConflict in [false, true]) {
    test(
      '${legacyConflict ? 'unrelated legacy/metadata conflict' : 'unrelated corrupt metadata'} blocks a new main write',
      () async {
        final old = snapshot('light');
        final local = snapshot('dark');
        final unrelated = snapshot('system');
        server.seed(config.fileUri, old.toJson());
        seedPublished(unrelated);
        if (legacyConflict) {
          server.seed(legacyUri, {
            'format': 'fzu-assistant-history',
            'schemaVersion': 1,
            'entries': [entry(unrelated)],
          });
          server.seed(metadataUri(unrelated), {
            ...metadata(unrelated),
            'entry': {...entry(unrelated), 'customCourseCount': 1},
          });
        } else {
          server.seed(metadataUri(unrelated), {
            ...metadata(unrelated),
            'format': 'unknown-history-format',
          });
        }
        final previous = await service.readRemote(config);
        await expectLater(
          service.upload(config, local, previous),
          throwsFormatException,
        );
        expect(jsonDecode(server.files[config.fileUri.path]!), old.toJson());
        expect(
          puts().where((request) => request.uri == config.fileUri),
          isEmpty,
        );
        final reads = server.requests.where(
          (request) =>
              request.method == 'GET' && request.uri == metadataUri(unrelated),
        );
        expect(reads, hasLength(1));
        expect(
          server.requests.indexOf(reads.single),
          greaterThan(
            server.requests.lastIndexWhere(
              (request) => request.method == 'PROPFIND',
            ),
          ),
        );
        expect(
          server.requests.where(
            (request) =>
                request.method == 'GET' &&
                request.uri == snapshotUri(unrelated),
          ),
          isEmpty,
        );
      },
    );
  }

  test(
    'same-snapshot append collision keeps first metadata after one 412',
    () async {
      final value = snapshot('light');
      final first = {
        ...metadata(value),
        'entry': {...entry(value), 'reason': 'beforeUpload'},
      };
      server.beforeRequest = (request, _) {
        if (request.method == 'PUT' && request.uri == metadataUri(value)) {
          // A different client published this metadata after our enumeration.
          server.seed(metadataUri(value), first);
        }
        return null;
      };
      await publish(value);
      expect(jsonDecode(server.files[metadataUri(value).path]!), first);
      expect(
        (await service.listHistory(config)).single.reason,
        WebDavHistoryReason.beforeUpload,
      );
      expect(
        puts().where((request) => request.uri == metadataUri(value)),
        hasLength(1),
      );
      final writes = puts().toList();
      expect(writes[0].uri, snapshotUri(value));
      expect(writes[1].uri, metadataUri(value));
      expect(writes[2].uri, config.fileUri);
      for (final request in writes) {
        expect(request.headers['If-None-Match'], '*');
      }
    },
  );

  test(
    'conflicting immutable metadata is validated and never overwritten',
    () async {
      final old = snapshot('light');
      final value = snapshot('dark');
      server.seed(config.fileUri, old.toJson());
      seedPublished(value);
      final corrupt = {
        ...metadata(value),
        'entry': {...entry(value), 'hiddenCourseCount': 3},
      };
      server.seed(metadataUri(value), corrupt);
      final previous = await service.readRemote(config);
      await expectLater(
        service.upload(config, value, previous),
        throwsFormatException,
      );
      expect(jsonDecode(server.files[metadataUri(value).path]!), corrupt);
      expect(jsonDecode(server.files[config.fileUri.path]!), old.toJson());
      expect(puts().where((request) => request.uri == config.fileUri), isEmpty);
    },
  );

  for (final phase in ['snapshot', 'metadata']) {
    test(
      'failed $phase publication preserves the main and hides orphan snapshots',
      () async {
        final old = snapshot('light');
        final value = snapshot('dark');
        server.seed(config.fileUri, old.toJson());
        final previous = await service.readRemote(config);
        final failingUri = phase == 'snapshot'
            ? snapshotUri(value)
            : metadataUri(value);
        server.beforeRequest = (request, _) =>
            request.method == 'PUT' && request.uri == failingUri
            ? ResponseBody.fromString('', 503)
            : null;
        await expectLater(
          service.upload(config, value, previous),
          throwsException,
        );
        expect(jsonDecode(server.files[config.fileUri.path]!), old.toJson());
        expect(
          puts().where((request) => request.uri == config.fileUri),
          isEmpty,
        );
        expect(server.files.containsKey(metadataUri(value).path), isFalse);
        expect(
          server.files.containsKey(snapshotUri(value).path),
          phase == 'metadata',
        );
        expect((await service.listHistory(config)).single.id, idOf(old));
      },
    );
  }

  test(
    'lost metadata response can be retried without duplicating history',
    () async {
      final old = snapshot('light');
      final value = snapshot('dark');
      server.seed(config.fileUri, old.toJson());
      final previous = await service.readRemote(config);
      var failed = false;
      server.beforeRequest = (request, data) {
        if (!failed &&
            request.method == 'PUT' &&
            request.uri == metadataUri(value)) {
          failed = true;
          server.seed(request.uri, utf8.decode(data));
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'test-only lost response',
          );
        }
        return null;
      };
      await expectLater(
        service.upload(config, value, previous),
        throwsException,
      );
      expect(jsonDecode(server.files[config.fileUri.path]!), old.toJson());
      await service.upload(config, value, previous);
      expect(await service.listHistory(config), hasLength(2));
      expect(jsonDecode(server.files[config.fileUri.path]!), value.toJson());
    },
  );

  for (final status in [405, 501]) {
    test(
      'unsupported PROPFIND $status fails before changing the main',
      () async {
        final old = snapshot('light');
        server.seed(config.fileUri, old.toJson());
        final previous = await service.readRemote(config);
        server.beforeRequest = (request, _) => request.method == 'PROPFIND'
            ? ResponseBody.fromString('', status)
            : null;
        await expectLater(
          service.upload(config, snapshot('dark'), previous),
          throwsA(
            predicate(
              (error) => error.toString().contains('PROPFIND Depth: 1'),
            ),
          ),
        );
        expect(puts(), isEmpty);
        expect(jsonDecode(server.files[config.fileUri.path]!), old.toJson());
      },
    );
  }

  test(
    'an incomplete post-publication listing prevents the main PUT',
    () async {
      final value = snapshot('light');
      var lists = 0;
      server.directories.add(metadataDirectory.path);
      server.beforeRequest = (request, _) {
        if (request.method == 'PROPFIND' && ++lists == 2) {
          return ResponseBody.fromString(
            webDavListing([(metadataDirectory.path, true)]),
            207,
          );
        }
        return null;
      };
      await expectLater(publish(value), throwsFormatException);
      expect(server.files.containsKey(metadataUri(value).path), isTrue);
      expect(server.files.containsKey(config.fileUri.path), isFalse);
      expect(puts().where((request) => request.uri == config.fileUri), isEmpty);
    },
  );

  test(
    'post-publication listing must retain every initially listed metadata ID',
    () async {
      final old = snapshot('light');
      final value = snapshot('dark');
      seedPublished(old);
      server.seed(config.fileUri, old.toJson());
      final previous = await service.readRemote(config);
      var lists = 0;
      server.beforeRequest = (request, _) {
        if (request.method == 'PROPFIND' && ++lists == 2) {
          return ResponseBody.fromString(
            webDavListing([
              (metadataDirectory.path, true),
              (metadataUri(value).path, false),
            ]),
            207,
          );
        }
        return null;
      };
      await expectLater(
        service.upload(config, value, previous),
        throwsFormatException,
      );
      expect(jsonDecode(server.files[config.fileUri.path]!), old.toJson());
      expect(puts().where((request) => request.uri == config.fileUri), isEmpty);
    },
  );

  test(
    'a legacy hit validates overlapping metadata before updating the main',
    () async {
      final old = snapshot('light');
      seedPublished(old);
      server.seed(config.fileUri, old.toJson());
      server.seed(legacyUri, {
        'format': 'fzu-assistant-history',
        'schemaVersion': 1,
        'entries': [entry(old)],
      });
      server.seed(metadataUri(old), {
        ...metadata(old),
        'entry': {...entry(old), 'hiddenCourseCount': 3},
      });
      final previous = await service.readRemote(config);
      await expectLater(
        service.upload(config, snapshot('dark'), previous),
        throwsA(predicate((error) => error.toString().contains('新旧历史记录不一致'))),
      );
      expect(jsonDecode(server.files[config.fileUri.path]!), old.toJson());
      expect(puts(), isEmpty);
      await expectLater(service.listHistory(config), throwsFormatException);
    },
  );

  final validId = 'a' * 64;
  for (final href in [
    'https://elsewhere.example/$validId.json',
    '//elsewhere.example/dav/fzu/fzu-assistant-history/metadata/$validId.json',
    'https://user:password@dav.example${metadataDirectory.path}$validId.json',
    '/dav/elsewhere/$validId.json',
    '../metadata/$validId.json',
    '%2e%2e/metadata/$validId.json',
    '%252e%252e/$validId.json',
    '$validId%2f.json',
    '$validId%5c.json',
    '$validId.json?token=untrusted',
    '$validId.json#fragment',
    'file:///C:/private/$validId.json',
    'javascript:untrusted',
    'unexpected.json',
    'nested/$validId.json',
  ]) {
    test(
      'PROPFIND rejects unsafe href $href before any metadata GET',
      () async {
        server.beforeRequest = (request, _) => request.method == 'PROPFIND'
            ? ResponseBody.fromString(
                webDavListing([(metadataDirectory.path, true), (href, false)]),
                207,
              )
            : null;
        await expectLater(service.listHistory(config), throwsFormatException);
        expect(
          server.requests
              .where((request) => request.method == 'GET')
              .map((request) => request.uri),
          [legacyUri],
        );
        expect(
          server.requests.every(
            (request) =>
                request.uri.origin == config.fileUri.origin &&
                !request.followRedirects,
          ),
          isTrue,
        );
      },
    );
  }

  for (final kind in [
    'absolute URI',
    'absolute path',
    'relative',
    'default namespace',
  ]) {
    test(
      'PROPFIND accepts $kind and rebuilds a fixed metadata target',
      () async {
        final value = snapshot('light');
        seedPublished(value);
        final href = switch (kind) {
          'absolute URI' => metadataUri(value).toString(),
          'relative' => '${idOf(value)}.json',
          _ => metadataUri(value).path,
        };
        var listing = webDavListing([
          (metadataDirectory.path, true),
          (href, false),
        ]);
        if (kind == 'default namespace') {
          listing = listing
              .replaceAll('xmlns:d=', 'xmlns=')
              .replaceAll('d:', '');
        }
        server.beforeRequest = (request, _) => request.method == 'PROPFIND'
            ? ResponseBody.fromString(listing, 207)
            : null;
        expect((await service.listHistory(config)).single.id, idOf(value));
        expect(server.requests.last.uri, metadataUri(value));
      },
    );
  }

  for (final xml in [
    '<html><body>upstream error</body></html>',
    '<d:multistatus xmlns:d="DAV:">',
    '<multistatus xmlns="wrong"/>',
    '<multistatus xmlns="DAV:"/>',
    '<!DOCTYPE multistatus SYSTEM "https://elsewhere.example/xxe">'
        '<multistatus xmlns="DAV:"/>',
    webDavListing([(metadataDirectory.path, true)])
        .replaceAll('200 OK', '403 Forbidden'),
    webDavListing([(metadataDirectory.path, true)])
        .replaceAll('<d:href>', '<d:href><d:nested/>'),
  ]) {
    test('PROPFIND rejects malformed or failed XML ${xml.hashCode}', () async {
      server.beforeRequest = (request, _) => request.method == 'PROPFIND'
          ? ResponseBody.fromString(xml, 207)
          : null;
      await expectLater(service.listHistory(config), throwsFormatException);
      expect(server.requests, hasLength(2));
      expect(puts(), isEmpty);
    });
  }

  test('metadata GET redirects never forward credentials', () async {
    final value = snapshot('light');
    seedPublished(value);
    server.beforeRequest = (request, _) =>
        request.method == 'GET' && request.uri == metadataUri(value)
        ? ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': ['https://elsewhere.example/steal'],
            },
          )
        : null;
    await expectLater(
      service.listHistory(config),
      throwsA(predicate((error) => error.toString().contains('跳转'))),
    );
    expect(
      server.requests.every(
        (request) =>
            request.uri.origin == config.fileUri.origin &&
            !request.followRedirects,
      ),
      isTrue,
    );
  });

  test(
    'metadata ID and schema are validated against the fixed filename',
    () async {
      final value = snapshot('light');
      seedPublished(value);
      for (final invalid in [
        {...metadata(value), 'schemaVersion': 2},
        {...metadata(value), 'href': 'https://elsewhere.example/snapshot'},
        {
          ...metadata(value),
          'entry': {...entry(value), 'id': 'b' * 64},
        },
      ]) {
        server.seed(metadataUri(value), invalid);
        await expectLater(service.listHistory(config), throwsFormatException);
      }
    },
  );

  test('metadata GET and PROPFIND have independent byte limits', () async {
    final value = snapshot('light');
    seedPublished(value);
    for (final method in ['GET', 'PROPFIND']) {
      server.beforeRequest = (request, _) =>
          request.method == method &&
              (method == 'PROPFIND' || request.uri == metadataUri(value))
          ? ResponseBody.fromString(
              ' ' *
                  (method == 'GET'
                      ? 16 * 1024 + 1
                      : WebDavSyncService.maxBytes + 1),
              method == 'GET' ? 200 : 207,
            )
          : null;
      await expectLater(service.listHistory(config), throwsFormatException);
    }
  });

  test('PROPFIND bounds entry count before issuing metadata GETs', () async {
    server.beforeRequest = (request, _) => request.method == 'PROPFIND'
        ? ResponseBody.fromString(
            webDavListing([
              (metadataDirectory.path, true),
              for (var i = 0; i < 10001; i++)
                (
                  '${metadataDirectory.path}${i.toRadixString(16).padLeft(64, '0')}.json',
                  false,
                ),
            ]),
            207,
          )
        : null;
    await expectLater(service.listHistory(config), throwsFormatException);
    expect(server.requests, hasLength(2));
    expect(puts(), isEmpty);
  });
}
