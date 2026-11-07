import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/webdav_settings_page.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Service extends WebDavSyncService {
  int uploads = 0;
  int restores = 0;
  int saves = 0;
  int connectionTests = 0;
  WebDavConfig? testedConfig;
  Completer<void>? pendingTest;
  Object? testError;

  @override
  Future<void> testConnection(WebDavConfig config) async {
    connectionTests++;
    testedConfig = config;
    await pendingTest?.future;
    if (testError != null) throw testError!;
  }

  final snapshot = WebDavSnapshot.fromJson({
    'format': WebDavSyncService.format,
    'version': 1,
    'createdAt': '2026-11-03T00:00:00Z',
    'values': {...WebDavSyncService.defaults, SpKeys.themeMode: 'dark'},
  });
  @override
  Future<WebDavConfig> loadConfig() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.containsKey('webdav_directory')) return super.loadConfig();
    return const WebDavConfig(
      directory: 'https://dav.example/fzu/',
      username: 'test',
      password: 'test',
    );
  }

  @override
  Future<void> saveConfig(WebDavConfig config) async {
    saves++;
    await super.saveConfig(config);
  }

  @override
  Future<WebDavSnapshot> exportSnapshot() async => snapshot;
  @override
  Future<WebDavRemote> readRemote(WebDavConfig config) async =>
      WebDavRemote(snapshot: snapshot, etag: '"old"');
  @override
  Future<void> upload(
    WebDavConfig config,
    WebDavSnapshot snapshot,
    WebDavRemote previous,
  ) async {
    uploads++;
  }

  @override
  Future<void> restore(
    WebDavSnapshot snapshot, {
    WebDavSnapshot? expectedLocal,
    void Function(WebDavSnapshot)? apply,
    bool Function()? canApply,
  }) async {
    restores++;
    await super.restore(
      snapshot,
      expectedLocal: expectedLocal,
      apply: apply,
      canApply: canApply,
    );
  }
}

void main() {
  testWidgets('connection test uses unsaved inputs without persisting them', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'webdav_directory': 'https://saved.example/dav/',
      'webdav_username': 'saved-user',
      'webdav_auto_sync': true,
      'webdav_sync_baseline': 'unchanged-baseline',
    });
    FlutterSecureStorage.setMockInitialValues({
      'fzu_webdav_password': 'saved-password',
    });
    final preferences = await SharedPreferences.getInstance();
    final before = {
      for (final key in preferences.getKeys()) key: preferences.get(key),
    };
    final settings = AppSettings();
    final service = _Service()..pendingTest = Completer<void>();
    await tester.pumpWidget(
      AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WebDavSettingsPage(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://unsaved.example/folder/',
    );
    await tester.enterText(find.byType(TextField).at(1), 'new-user');
    await tester.enterText(find.byType(TextField).at(2), 'new-password');
    final button = find.widgetWithText(OutlinedButton, '测试连接');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    expect(service.connectionTests, 1);
    expect(service.testedConfig!.directory, 'https://unsaved.example/folder/');
    expect(service.testedConfig!.username, 'new-user');
    expect(service.testedConfig!.password, 'new-password');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    await tester.tap(button);
    await tester.pump();
    expect(service.connectionTests, 1);
    service.pendingTest!.complete();
    await tester.pumpAndSettle();
    expect(find.text('连接有效，目录可读写且测试文件已清理。'), findsOneWidget);
    expect(service.saves, 0);
    expect(service.uploads, 0);
    expect(service.restores, 0);
    expect({
      for (final key in preferences.getKeys()) key: preferences.get(key),
    }, before);
    expect((await service.loadConfig()).password, 'saved-password');
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
    service.dio.close(force: true);
  });

  testWidgets('connection failures are visible and permit another attempt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final settings = AppSettings();
    final service = _Service()..testError = Exception('测试连接失败');
    await tester.pumpWidget(
      AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WebDavSettingsPage(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, '测试连接');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('测试连接失败'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isTrue,
    );
    expect(service.saves, 0);
    expect(service.uploads, 0);
    expect(service.restores, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
    service.dio.close(force: true);
  });

  testWidgets(
    'automatic sync saves config when enabled and can be disabled with invalid input',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final settings = AppSettings();
      final service = _Service();
      final reopenedService = _Service();
      addTearDown(settings.dispose);
      addTearDown(() => service.dio.close(force: true));
      addTearDown(() => reopenedService.dio.close(force: true));

      Widget page(WebDavSyncService api) => AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WebDavSettingsPage(service: api),
        ),
      );

      await tester.pumpWidget(page(service));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(await service.loadAutoSyncEnabled(), isFalse);
      expect(service.saves, 0);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'https://dav.example/updated/');
      await tester.enterText(fields.at(1), 'updated-user');
      await tester.enterText(fields.at(2), 'updated-secret');
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(await service.loadAutoSyncEnabled(), isTrue);
      expect(service.saves, 1);
      final saved = await reopenedService.loadConfig();
      expect(saved.directory, 'https://dav.example/updated/');
      expect(saved.username, 'updated-user');
      expect(saved.password, 'updated-secret');

      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), 'this is not a WebDAV directory');
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(await service.loadAutoSyncEnabled(), isFalse);
      expect(service.saves, 1);
      expect((await reopenedService.loadConfig()).directory, saved.directory);
      expect(find.byType(SelectableText), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(page(reopenedService));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      final directory = tester.widget<TextField>(find.byType(TextField).first);
      expect(directory.controller!.text, saved.directory);
      expect(reopenedService.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'WebDAV fields inherit the shared login outline and input height',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      final service = _Service();
      await tester.pumpWidget(
        AppSettingsProvider(
          settings: settings,
          child: MaterialApp(
            theme: settings.lightTheme,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WebDavSettingsPage(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(3));
      final decorations = tester
          .widgetList<InputDecorator>(find.byType(InputDecorator))
          .map((decorator) => decorator.decoration)
          .toList();
      expect(decorations, hasLength(3));
      final passwordDecoration = decorations.last;
      expect(passwordDecoration.border, isA<OutlineInputBorder>());
      expect(
        (passwordDecoration.border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(12),
      );
      for (final decoration in decorations) {
        expect(decoration.border, passwordDecoration.border);
        expect(decoration.contentPadding, passwordDecoration.contentPadding);
      }
      for (final field in fields) {
        expect(field.decoration!.prefixIcon, isNotNull);
      }
      final heights = find
          .byType(EditableText)
          .evaluate()
          .map((element) => InputDecorator.containerOf(element)!.size.height)
          .toList();
      expect(heights, hasLength(3));
      expect(heights.every((height) => height == heights.first), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
      service.dio.close(force: true);
    },
  );

  testWidgets(
    'upload and download only replace data after the preview is confirmed',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final settings = AppSettings();
      await settings.load();
      final service = _Service();
      await tester.pumpWidget(
        AppSettingsProvider(
          settings: settings,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WebDavSettingsPage(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, '上传到 WebDAV'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '上传到 WebDAV'));
      // The page deliberately keeps its progress indicator animated while the
      // confirmation awaits a decision. Advance only the dialog transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('自定义课程数'), findsOneWidget);
      expect(service.uploads, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(service.uploads, 0);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(service.uploads, 0);
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, '下载并覆盖本地'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '下载并覆盖本地'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(service.restores, 0);
      expect(settings.themeModeKey.value, 'system');
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();
      expect(service.restores, 1);
      expect(settings.themeModeKey.value, 'dark');
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
      service.dio.close(force: true);
    },
  );
}
