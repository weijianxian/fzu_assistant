import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PausedStorage extends FlutterSecureStorage {
  final entered = Completer<void>();
  final release = Completer<void>();
  bool failNext = false;
  bool _paused = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (!_paused) {
      _paused = true;
      entered.complete();
      await release.future;
      if (failNext) throw Exception('synthetic secure storage failure');
    }
    await super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const updated = WebDavConfig(
    directory: 'https://new.example/dav/',
    username: 'new-user',
    password: 'new-secret',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'webdav_directory': 'https://old.example/dav/',
      'webdav_username': 'old-user',
      'webdav_sync_baseline': 'old-baseline',
      'webdav_auto_sync': true,
    });
    FlutterSecureStorage.setMockInitialValues({
      'fzu_webdav_password': 'old-secret',
    });
  });

  for (final reason in ['account', 'disposed', 'storage failure']) {
    test(
      'guarded save rolls back when $reason changes during a write',
      () async {
        var account = 0;
        var mounted = true;
        final storage = _PausedStorage();
        final service = WebDavSyncService(
          storage: storage,
          captureAccountValidity: () {
            final captured = account;
            return () => account == captured;
          },
        );
        addTearDown(() => service.dio.close(force: true));
        final pending = service.saveConfig(updated, canSave: () => mounted);
        final rejected = expectLater(
          pending,
          reason == 'storage failure'
              ? throwsException
              : throwsA(isA<WebDavLocalChanged>()),
        );
        await storage.entered.future;
        if (reason == 'account') account++;
        if (reason == 'disposed') mounted = false;
        if (reason == 'storage failure') storage.failNext = true;
        storage.release.complete();
        await rejected;
        final saved = await service.loadConfig();
        expect(saved.directory, 'https://old.example/dav/');
        expect(saved.username, 'old-user');
        expect(saved.password, 'old-secret');
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString('webdav_sync_baseline'), 'old-baseline');
        expect(preferences.getBool('webdav_auto_sync'), isTrue);
      },
    );
  }

  test(
    'a newer configuration wins over a guarded save already writing',
    () async {
      final storage = _PausedStorage();
      final service = WebDavSyncService(storage: storage);
      final other = WebDavSyncService(storage: storage);
      addTearDown(() => service.dio.close(force: true));
      addTearDown(() => other.dio.close(force: true));
      final pending = service.saveConfig(updated, canSave: () => true);
      final rejected = expectLater(pending, throwsA(isA<WebDavLocalChanged>()));
      await storage.entered.future;
      final newer = other.saveConfig(
        const WebDavConfig(
          directory: 'https://latest.example/dav/',
          username: 'latest-user',
          password: 'latest-secret',
        ),
      );
      storage.release.complete();
      await rejected;
      await newer;
      final saved = await service.loadConfig();
      expect(saved.directory, 'https://latest.example/dav/');
      expect(saved.username, 'latest-user');
      expect(saved.password, 'latest-secret');
    },
  );
}
