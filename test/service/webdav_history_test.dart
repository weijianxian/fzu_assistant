import 'dart:async';
import 'dart:convert';

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
    username: 'student',
    password: 'webdav-private',
  );
  final indexUri = config.fileUri.resolve('fzu-assistant-history.json');
  late WebDavTestServer server;
  late WebDavSyncService service;
  late SharedPreferences preferences;
  var accountGeneration = 0;

  WebDavSnapshot snapshot({
    String mode = 'system',
    int schema = 2,
    String createdAt = '2026-11-08T02:00:00Z',
  }) => WebDavSnapshot.fromJson({
    'format': WebDavSyncService.format,
    if (schema == 1) 'version': 1 else 'schemaVersion': schema,
    if (schema == 2) 'appVersion': {'version': '1.6.3', 'buildNumber': '176'},
    'createdAt': createdAt,
    'values': {...WebDavSyncService.defaults, SpKeys.themeMode: mode},
  });

  Future<void> publish(WebDavSnapshot value) =>
      service.upload(config, value, const WebDavRemote(snapshot: null));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    server = WebDavTestServer();
    accountGeneration = 0;
    service = WebDavSyncService(
      dio: Dio()..httpClientAdapter = server,
      appVersion: () async =>
          const WebDavAppVersion(version: '1.6.3', buildNumber: '176'),
      captureAccountValidity: () {
        final captured = accountGeneration;
        return () => captured == accountGeneration;
      },
    );
    preferences = await SharedPreferences.getInstance();
    await CustomCourseStore.instance.load();
  });
  tearDown(() => service.dio.close(force: true));

  test(
    'new exports roundtrip data schema and creating App version separately',
    () async {
      final value = await service.exportSnapshot();
      expect(value.schemaVersion, 2);
      expect(value.appVersion!.label, '1.6.3+176');
      final json = value.toJson();
      expect(json['schemaVersion'], 2);
      expect(json.containsKey('version'), isFalse);
      expect(json['appVersion'], {'version': '1.6.3', 'buildNumber': '176'});
      final restored = WebDavSnapshot.fromJson(jsonDecode(jsonEncode(json)));
      expect(restored.toJson(), json);
      expect(restored.fingerprint, value.fingerprint);
      final differentExporter = {
        ...json,
        'appVersion': {'version': '1.6.4', 'buildNumber': '180'},
      };
      expect(
        WebDavSnapshot.fromJson(differentExporter).fingerprint,
        value.fingerprint,
      );
    },
  );

  test('released v1 backups without interface style or metadata migrate explicitly', () {
    final json = snapshot(schema: 1).toJson();
    json['values'] = {...WebDavSyncService.defaults}
      ..remove(SpKeys.interfaceStyle);
    final migrated = WebDavSnapshot.fromJson(json);
    expect(migrated.schemaVersion, 1);
    expect(migrated.appVersion, isNull);
    expect(migrated.values[SpKeys.interfaceStyle], 'classic');
    expect(
      WebDavSnapshot.fromJson(migrated.toJson()).fingerprint,
      migrated.fingerprint,
    );
    for (final key in [SpKeys.themeKey, SpKeys.papersAccess]) {
      json['values'] = {...WebDavSyncService.defaults}..remove(key);
      expect(() => WebDavSnapshot.fromJson(json), throwsFormatException);
    }
    final v2 = snapshot().toJson();
    v2['values'] = {...WebDavSyncService.defaults}
      ..remove(SpKeys.interfaceStyle);
    expect(() => WebDavSnapshot.fromJson(v2), throwsFormatException);
  });

  test(
    'unknown future data schemas cannot be read or overwritten as old backups',
    () async {
      final future = {...snapshot().toJson(), 'schemaVersion': 3};
      server.seed(config.fileUri, future);
      await expectLater(service.readRemote(config), throwsFormatException);
      expect(
        server.requests.where((request) => request.method == 'PUT'),
        isEmpty,
      );
      expect(jsonDecode(server.files[config.fileUri.path]!), future);
      for (final bad in [0, -1, '2', 2.0, null]) {
        expect(
          () => WebDavSnapshot.fromJson({
            ...snapshot().toJson(),
            'schemaVersion': bad,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test('first publication saves a browseable immutable snapshot', () async {
    final value = snapshot();
    await publish(value);
    final entries = await service.listHistory(config);
    expect(entries, hasLength(1));
    expect(entries.single.appVersion!.label, '1.6.3+176');
    expect(entries.single.schemaVersion, 2);
    expect(entries.single.reason, WebDavHistoryReason.upload);
    expect(
      (await service.readHistorySnapshot(config, entries.single)).toJson(),
      value.toJson(),
    );
    final immutableWrites = server.requests.where(
      (request) =>
          request.method == 'PUT' &&
          RegExp(r'/fzu-assistant-history/[a-f0-9]{64}\.json$')
              .hasMatch(request.uri.path),
    );
    expect(immutableWrites, hasLength(1));
    expect(immutableWrites.single.headers['If-None-Match'], '*');
    final writes = server.requests.where((request) => request.method == 'PUT');
    expect(writes.last.uri, config.fileUri);
    expect(writes.last.headers['If-None-Match'], '*');
  });

  test('upload archives the legacy remote before replacing it', () async {
    final old = snapshot(mode: 'light', schema: 1);
    server.seed(config.fileUri, old.toJson());
    final previous = await service.readRemote(config);
    final current = snapshot(mode: 'dark');
    await service.upload(config, current, previous);
    final entries = await service.listHistory(config);
    expect(entries, hasLength(2));
    final oldEntry = entries.singleWhere((entry) => entry.schemaVersion == 1);
    expect(oldEntry.reason, WebDavHistoryReason.beforeUpload);
    expect(oldEntry.appVersion, isNull);
    expect(
      (await service.readHistorySnapshot(config, oldEntry)).values,
      old.values,
    );
    final put = server.requests.lastWhere(
      (request) => request.method == 'PUT' && request.uri == config.fileUri,
    );
    expect(put.headers['If-Match'], previous.etag);
    expect(jsonDecode(server.files[config.fileUri.path]!), current.toJson());
  });

  test('restoring history keeps a local recovery point and requires a new sync choice', () async {
    final historic = snapshot(mode: 'light');
    await publish(historic);
    final entry = (await service.listHistory(config)).single;
    await preferences.setString(SpKeys.themeMode, 'dark');
    final before = await service.exportSnapshot();
    await service.rememberSynced(config, before);
    await preferences.setString('fzu_sso_cookie', 'private-cookie');
    final read = await service.readHistorySnapshot(config, entry);
    final applied = <WebDavSnapshot>[];
    await service.restore(read, expectedLocal: before, apply: applied.add);
    expect(preferences.getString(SpKeys.themeMode), 'light');
    expect(applied.single.fingerprint, historic.fingerprint);
    expect(
      (await service.loadLocalRecovery())!.fingerprint,
      before.fingerprint,
    );
    expect(preferences.getString('fzu_sso_cookie'), 'private-cookie');
    expect(preferences.getString('webdav_sync_baseline'), isNull);
    expect(jsonDecode(server.files[config.fileUri.path]!), historic.toJson());
    await service.restore((await service.loadLocalRecovery())!);
    expect(preferences.getString(SpKeys.themeMode), 'dark');
    expect(
      (await service.loadLocalRecovery())!.values[SpKeys.themeMode],
      'light',
    );
  });

  test(
    'restoration failures roll back settings and the previous baseline',
    () async {
      await preferences.setString(SpKeys.themeMode, 'dark');
      final before = await service.exportSnapshot();
      await service.rememberSynced(config, before);
      final baseline = preferences.getString('webdav_sync_baseline');
      final applied = <String>[];
      await expectLater(
        service.restore(
          snapshot(mode: 'light'),
          apply: (value) {
            applied.add(value.values[SpKeys.themeMode] as String);
            if (applied.length == 1) throw StateError('UI apply failed');
          },
        ),
        throwsStateError,
      );
      expect(preferences.getString(SpKeys.themeMode), 'dark');
      expect(preferences.getString('webdav_sync_baseline'), baseline);
      expect(applied, ['light', 'dark']);
      expect(
        (await service.loadLocalRecovery())!.fingerprint,
        before.fingerprint,
      );
    },
  );

  test('a changed main ETag prevents replacing the current file and retains both snapshots', () async {
    final old = snapshot(mode: 'light');
    server.seed(config.fileUri, old.toJson());
    final previous = await service.readRemote(config);
    final otherDevice = snapshot(
      mode: 'dark',
      createdAt: '2026-11-08T03:00:00Z',
    );
    server.seed(config.fileUri, otherDevice.toJson());
    await expectLater(
      service.upload(config, snapshot(), previous),
      throwsA(predicate((error) => error.toString().contains('远端文件已改变'))),
    );
    expect(
      jsonDecode(server.files[config.fileUri.path]!),
      otherDevice.toJson(),
    );
    expect(await service.listHistory(config), hasLength(2));
  });

  test(
    'repeated history publication validates immutable files after 412',
    () async {
      await publish(snapshot(mode: 'light'));
      final previous = await service.readRemote(config);
      await service.upload(config, snapshot(mode: 'dark'), previous);
      expect(await service.listHistory(config), hasLength(2));
      final metadataPuts = server.requests.where(
        (request) =>
            request.method == 'PUT' && request.uri.path.contains('/metadata/'),
      );
      expect(metadataPuts, hasLength(3));
      expect(
        metadataPuts.every(
          (request) => request.headers['If-None-Match'] == '*',
        ),
        isTrue,
      );
      expect(
        server.requests.where(
          (request) => request.method == 'PUT' && request.uri == indexUri,
        ),
        isEmpty,
      );
      expect(server.files.containsKey(indexUri.path), isFalse);
    },
  );

  test('failed history writes never replace the primary backup', () async {
    final old = snapshot(mode: 'light');
    server.seed(config.fileUri, old.toJson());
    final previous = await service.readRemote(config);
    server.beforeRequest = (request, _) =>
        request.method == 'PUT' && server.isHistory(request.uri)
        ? ResponseBody.fromString('', 403)
        : null;
    await expectLater(
      service.upload(config, snapshot(mode: 'dark'), previous),
      throwsException,
    );
    expect(jsonDecode(server.files[config.fileUri.path]!), old.toJson());
    expect(
      server.requests.where(
        (request) => request.method == 'PUT' && request.uri == config.fileUri,
      ),
      isEmpty,
    );
  });

  test(
    'foreign history indexes and future index versions are not overwritten',
    () async {
      for (final index in [
        {'format': 'someone-else', 'schemaVersion': 1, 'entries': []},
        {'format': 'fzu-assistant-history', 'schemaVersion': 2, 'entries': []},
      ]) {
        server.seed(indexUri, index);
        await expectLater(publish(snapshot()), throwsFormatException);
        expect(jsonDecode(server.files[indexUri.path]!), index);
      }
      expect(
        server.requests.where((request) => request.method == 'PUT'),
        isEmpty,
      );
    },
  );

  test('history never follows injected hrefs or paths and never forwards authentication', () async {
    await publish(snapshot());
    final entry = (await service.listHistory(config)).single.toJson();
    final index = {
      'format': 'fzu-assistant-history',
      'schemaVersion': 1,
      'entries': [entry],
    };
    for (final id in [
      '../other',
      'https://elsewhere.example/file',
      '/secret',
    ]) {
      server.seed(indexUri, {
        ...index,
        'entries': [
          {...entry, 'id': id},
        ],
      });
      await expectLater(service.listHistory(config), throwsFormatException);
    }
    server.seed(indexUri, {
      ...index,
      'entries': [
        {...entry, 'href': 'https://elsewhere.example/file'},
      ],
    });
    await expectLater(service.listHistory(config), throwsFormatException);
    expect(
      server.requests.every(
        (request) =>
            request.uri.origin == config.fileUri.origin &&
            request.uri.path.startsWith('/dav/fzu/') &&
            !request.followRedirects,
      ),
      isTrue,
    );
  });

  for (final change in ['configuration', 'account']) {
    test(
      'changing $change during history writes prevents publishing to the old target',
      () async {
        await service.saveConfig(config);
        var changed = false;
        server.beforeRequest = (request, _) async {
          if (!changed &&
              request.method == 'PUT' &&
              request.uri.path.contains('/fzu-assistant-history/')) {
            changed = true;
            if (change == 'account') {
              accountGeneration++;
            } else {
              await service.saveConfig(
                const WebDavConfig(
                  directory: 'https://dav.example/dav/new/',
                  username: 'new-user',
                  password: 'new-password',
                ),
              );
            }
          }
          return null;
        };
        await expectLater(
          publish(snapshot()),
          throwsA(isA<WebDavLocalChanged>()),
        );
        expect(server.files.containsKey(config.fileUri.path), isFalse);
        expect(server.files.containsKey(indexUri.path), isFalse);
        expect(
          server.requests.where(
            (request) =>
                request.method == 'PUT' && request.uri == config.fileUri,
          ),
          isEmpty,
        );
      },
    );
  }

  test('history operations share the global manual/automatic lock', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final pending = service.exclusive(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    try {
      await expectLater(service.listHistory(config), throwsException);
      await expectLater(publish(snapshot()), throwsException);
      await expectLater(service.restore(snapshot()), throwsException);
      expect(server.requests, isEmpty);
    } finally {
      release.complete();
      await pending;
    }
  });

  test('an explicit configuration save invalidates an earlier preview without networking', () async {
    await service.saveConfig(config);
    server.seed(config.fileUri, snapshot().toJson());
    final preview = await service.readRemote(config);
    final requestCount = server.requests.length;
    final captured = service.captureValidity();
    await service.saveConfig(
      const WebDavConfig(
        directory: 'https://dav.example/dav/changed/',
        username: 'changed-user',
        password: 'changed-password',
      ),
    );
    expect(captured(), isFalse);
    expect(server.requests, hasLength(requestCount));
    await expectLater(
      service.upload(config, snapshot(mode: 'dark'), preview),
      throwsA(isA<WebDavLocalChanged>()),
    );
    expect(server.requests, hasLength(requestCount));
    expect(jsonDecode(server.files[config.fileUri.path]!), snapshot().toJson());
  });

  test(
    'exports, immutable history and recovery points exclude sensitive data',
    () async {
      await preferences.setString('password', 'private-login');
      await preferences.setString('fzu_sso_cookie', 'private-cookie');
      await preferences.setString(SpKeys.cacheCoursesMap, 'private-cache');
      await service.saveConfig(config);
      final exported = await service.exportSnapshot();
      await publish(exported);
      await service.restore(snapshot(mode: 'dark'));
      final payloads = [
        ...server.files.values,
        preferences.getString('webdav_local_recovery_v1')!,
      ].join('\n');
      for (final private in [
        'private-login',
        'private-cookie',
        'private-cache',
        'webdav-private',
        'webdav_directory',
        'webdav_sync_baseline',
        'fzu_webdav_password',
      ]) {
        expect(payloads, isNot(contains(private)));
      }
      expect(
        exported.values.keys.toSet(),
        WebDavSyncService.defaults.keys.toSet(),
      );
    },
  );
}
