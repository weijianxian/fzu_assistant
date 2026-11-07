import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  int status = 200;
  String? body;
  Map<String, List<String>> headers = {};
  final requests = <RequestOptions>[];
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
    return ResponseBody.fromString(body ?? '', status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WebDavSyncService service;
  late _Adapter adapter;
  const config = WebDavConfig(
    directory: 'https://dav.example/user/fzu',
    username: 'student',
    password: 'secret',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    adapter = _Adapter();
    service = WebDavSyncService(dio: Dio()..httpClientAdapter = adapter);
  });
  tearDown(() => service.dio.close(force: true));

  test(
    'interface style restores immediately; legacy backups remain valid',
    () async {
      final settings = AppSettings();
      await settings.load();
      addTearDown(settings.dispose);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SpKeys.interfaceStyle, 'cards');
      final cards = await service.exportSnapshot();
      await service.restore(
        cards,
        apply: (snapshot) => applyWebDavSettings(settings, snapshot),
      );
      expect(settings.interfaceStyle.value, InterfaceStyle.cards);
      expect(prefs.getString(SpKeys.interfaceStyle), 'cards');

      await prefs.setString(SpKeys.interfaceStyle, 'continuousCards');
      final continuous = await service.exportSnapshot();
      final decoded = WebDavSnapshot.fromJson(continuous.toJson());
      await service.restore(
        decoded,
        apply: (snapshot) => applyWebDavSettings(settings, snapshot),
      );
      expect(settings.interfaceStyle.value, InterfaceStyle.continuousCards);
      expect(prefs.getString(SpKeys.interfaceStyle), 'continuousCards');

      final legacy = cards.toJson();
      legacy['values'] = {...cards.values}..remove(SpKeys.interfaceStyle);
      final restored = WebDavSnapshot.fromJson(legacy);
      expect(restored.values[SpKeys.interfaceStyle], 'classic');
      await service.restore(
        restored,
        apply: (snapshot) => applyWebDavSettings(settings, snapshot),
      );
      expect(settings.interfaceStyle.value, InterfaceStyle.classic);
      expect(prefs.getString(SpKeys.interfaceStyle), 'classic');
      for (final value in ['unknown', null, 1]) {
        legacy['values'] = {...cards.values, SpKeys.interfaceStyle: value};
        expect(() => WebDavSnapshot.fromJson(legacy), throwsFormatException);
      }
      legacy['values'] = {...cards.values}..remove(SpKeys.themeKey);
      expect(() => WebDavSnapshot.fromJson(legacy), throwsFormatException);
    },
  );

  test(
    'snapshot whitelist excludes login data, caches and WebDAV credentials',
    () async {
      SharedPreferences.setMockInitialValues({
        'username': 'private-login',
        'password': 'private-password',
        'fzu_sso_cookie': 'cookie',
        SpKeys.cacheCoursesMap: '{"cached":true}',
        'webdav_directory': 'https://dav.example',
        'webdav_username': 'private-webdav',
        SpKeys.west2AdjustmentsEnabled: true,
        SpKeys.themeMode: 'dark',
      });
      await service.saveConfig(config);
      final snapshot = await service.exportSnapshot();
      expect(
        snapshot.values.keys.toSet(),
        WebDavSyncService.defaults.keys.toSet(),
      );
      expect(snapshot.values[SpKeys.themeMode], 'dark');
      expect(snapshot.values['west2_adjustments_access'], 'allow');
      expect(snapshot.values['papers_access'], 'tip');
      final text = jsonEncode(snapshot.toJson());
      expect(text, isNot(contains('secret')));
      expect(text, isNot(contains('private-')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((key) => key.contains('password')), [
        'password',
      ]);
      expect((await service.loadConfig()).password, 'secret');
    },
  );

  test(
    'remote preview and conditional PUT target only the selected directory',
    () async {
      final local = await service.exportSnapshot();
      adapter.body = jsonEncode(local.toJson());
      adapter.headers = {
        'etag': ['"backup-one"'],
      };
      final remote = await service.readRemote(config);
      expect(remote.snapshot!.values, local.values);
      expect(
        adapter.requests.single.uri.toString(),
        'https://dav.example/user/fzu/fzu-assistant-sync.json',
      );
      expect(adapter.requests.single.followRedirects, isFalse);
      expect(
        adapter.requests.single.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('student:secret'))}',
      );
      adapter.status = 204;
      await service.upload(config, local, remote);
      expect(adapter.requests.last.headers['If-Match'], '"backup-one"');
      expect(jsonDecode(utf8.decode(adapter.uploaded)), local.toJson());
      adapter.status = 412;
      await expectLater(
        service.upload(config, local, remote),
        throwsA(predicate((error) => error.toString().contains('远端文件已改变'))),
      );
    },
  );

  test('new remote file uses If-None-Match and redirects never forward credentials', () async {
    adapter.status = 404;
    final remote = await service.readRemote(config);
    expect(remote.snapshot, isNull);
    adapter.status = 201;
    await service.upload(config, await service.exportSnapshot(), remote);
    expect(adapter.requests.last.headers['If-None-Match'], '*');
    adapter.status = 302;
    adapter.headers = {
      'location': ['https://elsewhere.example/stolen'],
    };
    final before = adapter.requests.length;
    await expectLater(
      service.readRemote(config),
      throwsA(predicate((error) => error.toString().contains('跳转'))),
    );
    expect(adapter.requests.length, before + 1);
  });

  test('invalid snapshots never mutate existing data; restore retains credentials and caches', () async {
    final local = await service.exportSnapshot();
    final malformed =
        jsonDecode(jsonEncode(local.toJson())) as Map<String, dynamic>;
    malformed['values'][CustomCourseStore.storageKey] = '[{"name":"broken"}]';
    expect(() => WebDavSnapshot.fromJson(malformed), throwsFormatException);
    malformed['values'] = {...local.values, 'password': 'do-not-import'};
    expect(() => WebDavSnapshot.fromJson(malformed), throwsFormatException);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('password', 'retained');
    await prefs.setString(SpKeys.cacheCoursesMap, 'retained-cache');
    await prefs.setString(SpKeys.themeMode, 'dark');
    await service.restore(local);
    expect(prefs.getString(SpKeys.themeMode), 'system');
    expect(prefs.getString('password'), 'retained');
    expect(prefs.getString(SpKeys.cacheCoursesMap), 'retained-cache');
  });

  test(
    'oversized remote files and credential-bearing directory URLs are rejected',
    () async {
      adapter.headers = {
        'content-length': ['${WebDavSyncService.maxBytes + 1}'],
      };
      await expectLater(service.readRemote(config), throwsFormatException);
      for (final directory in [
        'ftp://dav.example/',
        'https://user:pass@dav.example/',
        'https://dav.example/?token=secret',
      ]) {
        expect(
          () => WebDavConfig(
            directory: directory,
            username: '',
            password: '',
          ).fileUri,
          throwsFormatException,
        );
      }
    },
  );
}
