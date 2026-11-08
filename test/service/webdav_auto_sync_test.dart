import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'webdav_test_server.dart';

class _RemoteAdapter implements HttpClientAdapter {
  final history = WebDavTestServer();
  WebDavSnapshot? remote;
  String? etag = '"remote-one"';
  Future<void> Function()? duringGet;
  final requests = <RequestOptions>[];
  final uploads = <WebDavSnapshot>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (history.isHistory(options.uri)) {
      return history.fetch(options, requestStream, cancelFuture);
    }
    requests.add(options);
    if (options.method == 'GET') {
      await duringGet?.call();
      return ResponseBody.fromString(
        remote == null ? '' : jsonEncode(remote!.toJson()),
        remote == null ? 404 : 200,
        headers: {
          if (etag != null) 'etag': [etag!],
        },
      );
    }
    if (options.method == 'PUT') {
      final data = await requestStream!.expand((chunk) => chunk).toList();
      final snapshot = WebDavSnapshot.fromJson(jsonDecode(utf8.decode(data)));
      uploads.add(snapshot);
      remote = snapshot;
      return ResponseBody.fromString('', 204);
    }
    throw StateError('Unexpected HTTP method ${options.method}');
  }

  @override
  void close({bool force = false}) {}
}

class _ObservedRestoreService extends WebDavSyncService {
  _ObservedRestoreService(Dio dio) : super(dio: dio);
  final restoreQueued = Completer<void>();

  @override
  Future<void> restore(
    WebDavSnapshot snapshot, {
    WebDavSnapshot? expectedLocal,
    void Function(WebDavSnapshot)? apply,
    bool Function()? canApply,
  }) {
    final operation = super.restore(
      snapshot,
      expectedLocal: expectedLocal,
      apply: apply,
      canApply: canApply,
    );
    restoreQueued.complete();
    return operation;
  }
}

WebDavSnapshot _snapshot({
  String mode = 'system',
  bool injection = true,
  String createdAt = '2026-11-03T00:00:00Z',
}) => WebDavSnapshot.fromJson({
  'format': WebDavSyncService.format,
  'version': 1,
  'createdAt': createdAt,
  'values': {
    ...WebDavSyncService.defaults,
    SpKeys.themeMode: mode,
    SpKeys.siteInjectionEnabled: injection,
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const config = WebDavConfig(
    directory: 'https://dav.example/user/fzu/',
    username: 'student',
    password: 'secret',
  );
  late WebDavSyncService service;
  late _RemoteAdapter adapter;
  late SharedPreferences preferences;
  late List<WebDavSnapshot> applied;

  Future<void> enable() async {
    await service.saveConfig(config);
    await service.setAutoSyncEnabled(true);
  }

  Future<WebDavAutoSyncResult> sync() => service.autoSync(apply: applied.add);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    await CustomCourseStore.instance.load();
    adapter = _RemoteAdapter();
    service = WebDavSyncService(dio: Dio()..httpClientAdapter = adapter);
    applied = [];
  });
  tearDown(() => service.dio.close(force: true));

  test(
    'automatic sync defaults off and does not contact a saved server',
    () async {
      await service.saveConfig(config);
      expect(await service.loadAutoSyncEnabled(), isFalse);
      expect(await sync(), WebDavAutoSyncResult.skipped);
      expect(adapter.requests, isEmpty);
      expect(applied, isEmpty);
    },
  );

  test(
    'automatic sync without a configured directory makes no requests',
    () async {
      await service.setAutoSyncEnabled(true);
      expect(await sync(), WebDavAutoSyncResult.skipped);
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'an empty remote is created with If-None-Match and remembered',
    () async {
      await enable();
      await preferences.setString(SpKeys.themeMode, 'dark');
      expect(await sync(), WebDavAutoSyncResult.uploaded);
      expect(adapter.requests.map((request) => request.method), ['GET', 'PUT']);
      expect(adapter.requests.last.headers['If-None-Match'], '*');
      expect(adapter.uploads.single.values[SpKeys.themeMode], 'dark');
      expect(applied, isEmpty);
      expect(await sync(), WebDavAutoSyncResult.unchanged);
      expect(adapter.uploads, hasLength(1));
      final exported = await service.exportSnapshot();
      expect(exported.values.containsKey('webdav_auto_sync'), isFalse);
      expect(exported.values.containsKey('webdav_sync_baseline'), isFalse);
    },
  );

  test(
    'identical payloads ignore timestamps and establish a baseline',
    () async {
      await enable();
      adapter.remote = _snapshot(createdAt: '2000-01-01T00:00:00Z');
      expect(await sync(), WebDavAutoSyncResult.unchanged);
      expect(adapter.uploads, isEmpty);
      expect(applied, isEmpty);
      await preferences.setString(SpKeys.themeMode, 'dark');
      expect(await sync(), WebDavAutoSyncResult.uploaded);
    },
  );

  test(
    'different data without a baseline requires a manual first choice',
    () async {
      await enable();
      adapter.remote = _snapshot(mode: 'dark');
      expect(await sync(), WebDavAutoSyncResult.conflict);
      expect(adapter.uploads, isEmpty);
      expect(applied, isEmpty);
      expect(preferences.getString(SpKeys.themeMode), isNull);
    },
  );

  test('only local changes upload with the remote strong ETag', () async {
    await enable();
    adapter.remote = _snapshot();
    await service.rememberSynced(config, adapter.remote!);
    await preferences.setString(SpKeys.themeMode, 'dark');
    expect(await sync(), WebDavAutoSyncResult.uploaded);
    expect(adapter.requests.last.headers['If-Match'], '"remote-one"');
    expect(adapter.uploads.single.values[SpKeys.themeMode], 'dark');
    expect(applied, isEmpty);
    expect(await sync(), WebDavAutoSyncResult.unchanged);
  });

  test('only remote changes download and apply without uploading', () async {
    await enable();
    await service.rememberSynced(config, _snapshot());
    adapter.remote = _snapshot(mode: 'dark', injection: false);
    expect(await sync(), WebDavAutoSyncResult.downloaded);
    expect(preferences.getString(SpKeys.themeMode), 'dark');
    expect(preferences.getBool(SpKeys.siteInjectionEnabled), isFalse);
    expect(applied.single.fingerprint, adapter.remote!.fingerprint);
    expect(adapter.uploads, isEmpty);
    expect(await sync(), WebDavAutoSyncResult.unchanged);
  });

  test(
    'changes on both sides preserve both versions for manual choice',
    () async {
      await enable();
      await service.rememberSynced(config, _snapshot());
      adapter.remote = _snapshot(mode: 'dark');
      await preferences.setBool(SpKeys.siteInjectionEnabled, false);
      expect(await sync(), WebDavAutoSyncResult.conflict);
      expect(preferences.getBool(SpKeys.siteInjectionEnabled), isFalse);
      expect(preferences.getString(SpKeys.themeMode), isNull);
      expect(adapter.remote!.values[SpKeys.siteInjectionEnabled], isTrue);
      expect(adapter.uploads, isEmpty);
      expect(applied, isEmpty);
    },
  );

  for (final etag in [null, 'W/"weak-version"']) {
    test(
      'local changes do not overwrite an existing file with ETag $etag',
      () async {
        await enable();
        adapter.remote = _snapshot();
        adapter.etag = etag;
        await service.rememberSynced(config, adapter.remote!);
        await preferences.setString(SpKeys.themeMode, 'dark');
        expect(await sync(), WebDavAutoSyncResult.manualUploadRequired);
        expect(adapter.uploads, isEmpty);
        expect(applied, isEmpty);
        expect(adapter.remote!.values[SpKeys.themeMode], 'system');
      },
    );
  }

  test('local edits while GET is pending prevent automatic writes', () async {
    await enable();
    await service.rememberSynced(config, _snapshot());
    adapter.remote = _snapshot(mode: 'dark');
    adapter.duringGet = () async {
      await preferences.setBool(SpKeys.siteInjectionEnabled, false);
    };
    expect(await sync(), WebDavAutoSyncResult.conflict);
    expect(preferences.getBool(SpKeys.siteInjectionEnabled), isFalse);
    expect(preferences.getString(SpKeys.themeMode), isNull);
    expect(adapter.uploads, isEmpty);
    expect(applied, isEmpty);
  });

  test('turning automatic sync off during GET prevents writes', () async {
    await enable();
    await service.rememberSynced(config, _snapshot());
    adapter.remote = _snapshot(mode: 'dark');
    adapter.duringGet = () => service.setAutoSyncEnabled(false);
    expect(await sync(), WebDavAutoSyncResult.skipped);
    expect(preferences.getString(SpKeys.themeMode), isNull);
    expect(adapter.uploads, isEmpty);
    expect(applied, isEmpty);
  });

  for (final change in [
    (
      'directory',
      const WebDavConfig(
        directory: 'https://dav.example/user/changed/',
        username: 'student',
        password: 'secret',
      ),
    ),
    (
      'username',
      const WebDavConfig(
        directory: 'https://dav.example/user/fzu/',
        username: 'changed-student',
        password: 'secret',
      ),
    ),
    (
      'password',
      const WebDavConfig(
        directory: 'https://dav.example/user/fzu/',
        username: 'student',
        password: 'changed-secret',
      ),
    ),
  ]) {
    test(
      'changing the ${change.$1} during GET invalidates the pending sync',
      () async {
        await enable();
        await service.rememberSynced(config, _snapshot());
        adapter.remote = _snapshot(mode: 'dark');
        adapter.duringGet = () => service.saveConfig(change.$2);
        expect(await sync(), WebDavAutoSyncResult.skipped);
        expect(adapter.requests.single.uri, config.fileUri);
        final saved = await service.loadConfig();
        expect(saved.directory, change.$2.directory);
        expect(saved.username, change.$2.username);
        expect(saved.password, change.$2.password);
        expect(preferences.getString(SpKeys.themeMode), isNull);
        expect(adapter.uploads, isEmpty);
        expect(applied, isEmpty);
      },
    );
  }

  test(
    'turning sync off while a restore waits for course edits prevents import',
    () async {
      service.dio.close(force: true);
      final observed = _ObservedRestoreService(
        Dio()..httpClientAdapter = adapter,
      );
      service = observed;
      await enable();
      await service.rememberSynced(config, _snapshot());
      adapter.remote = _snapshot(mode: 'dark');
      final release = Completer<void>();
      final entered = Completer<void>();
      final blocker = CustomCourseStore.instance.restoreFromSync(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final operation = sync();
      try {
        await observed.restoreQueued.future;
        await service.setAutoSyncEnabled(false);
      } finally {
        release.complete();
        await blocker;
      }
      expect(await operation, WebDavAutoSyncResult.skipped);
      expect(await service.loadAutoSyncEnabled(), isFalse);
      expect(preferences.getString(SpKeys.themeMode), isNull);
      expect(adapter.uploads, isEmpty);
      expect(applied, isEmpty);
    },
  );

  test(
    'manual operations and automatic sync share a lock across instances',
    () async {
      await enable();
      final release = Completer<void>();
      final entered = Completer<void>();
      final manual = service.exclusive(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final second = WebDavSyncService();
      addTearDown(() => second.dio.close(force: true));
      try {
        expect(
          await second.autoSync(apply: applied.add),
          WebDavAutoSyncResult.skipped,
        );
        await expectLater(second.exclusive(() async {}), throwsException);
        expect(adapter.requests, isEmpty);
      } finally {
        release.complete();
        await manual;
      }
      expect(await sync(), WebDavAutoSyncResult.uploaded);
    },
  );

  test('a pending automatic sync prevents another automatic run', () async {
    await enable();
    final release = Completer<void>();
    final entered = Completer<void>();
    adapter.duringGet = () async {
      entered.complete();
      await release.future;
    };
    final first = sync();
    await entered.future;
    try {
      expect(await sync(), WebDavAutoSyncResult.skipped);
      await expectLater(service.exclusive(() async {}), throwsException);
      expect(adapter.requests, hasLength(1));
    } finally {
      release.complete();
      await first;
    }
    expect(adapter.uploads, hasLength(1));
  });

  for (final changed in [
    const WebDavConfig(
      directory: 'https://dav.example/user/fzu/',
      username: 'another-student',
      password: 'secret',
    ),
    const WebDavConfig(
      directory: 'https://dav.example/user/other/',
      username: 'student',
      password: 'secret',
    ),
  ]) {
    test(
      'a baseline for another target is never reused: ${changed.directory} ${changed.username}',
      () async {
        await enable();
        await service.rememberSynced(config, _snapshot());
        await service.saveConfig(changed);
        adapter.remote = _snapshot(mode: 'dark');
        expect(await sync(), WebDavAutoSyncResult.conflict);
        expect(adapter.requests.single.uri, changed.fileUri);
        expect(adapter.uploads, isEmpty);
        expect(applied, isEmpty);
      },
    );
  }

  test(
    'queued custom course edits are checked again before a remote restore',
    () async {
      final store = CustomCourseStore.instance;
      final original = await service.exportSnapshot();
      final release = Completer<void>();
      final entered = Completer<void>();
      final blocker = store.restoreFromSync(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final course = CustomCourse(
        id: 'edited-during-sync',
        account: 'student',
        term: '202601',
        name: 'Local edit',
        teacher: '',
        location: '',
        startClass: 1,
        endClass: 2,
        startWeek: 1,
        endWeek: 16,
        weekday: 1,
        single: true,
        double: true,
        remark: '',
        color: 0xff83b6b1,
      );
      final save = store.save(course);
      final restoration = expectLater(
        service.restore(
          _snapshot(mode: 'dark'),
          expectedLocal: original,
          apply: applied.add,
        ),
        throwsA(isA<WebDavLocalChanged>()),
      );
      release.complete();
      await blocker;
      await save;
      await restoration;
      expect(store.value.single.id, course.id);
      expect(
        preferences.getString(CustomCourseStore.storageKey),
        contains(course.id),
      );
      expect(preferences.getString(SpKeys.themeMode), isNull);
      expect(applied, isEmpty);
    },
  );
}
