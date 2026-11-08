import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/webdav_settings_page.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/reveal_widget.dart';
import '../service/webdav_test_server.dart';

const _captureWebDav = bool.fromEnvironment('WEBDAV_CAPTURE');
final _captureKey = GlobalKey();

Widget _captureBuilder(BuildContext context, Widget? child) =>
    _captureWebDav ? RepaintBoundary(key: _captureKey, child: child!) : child!;

void _captureViewport(WidgetTester tester) {
  if (!_captureWebDav) return;
  tester.view.physicalSize = const Size(400, 840);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _capturePage(WidgetTester tester, String name) async {
  if (!_captureWebDav) return;
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final target = File('build/agent-handoffs/webdav-$name.png');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

class _Service extends WebDavSyncService {
  _Service({super.captureAccountValidity});

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
    config.fileUri;
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
  Future<void> saveConfig(
    WebDavConfig config, {
    bool Function()? canSave,
  }) async {
    saves++;
    await super.saveConfig(config, canSave: canSave);
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const font = String.fromEnvironment('WEBDAV_CAPTURE_FONT');
    if (!_captureWebDav || font.isEmpty) return;
    await (FontLoader('Roboto')..addFont(
          File(font).readAsBytes().then((bytes) => bytes.buffer.asByteData()),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'the password footer tests before saving current inputs and preserves the sync baseline',
    (tester) async {
      _captureViewport(tester);
      SharedPreferences.setMockInitialValues({
        'webdav_sync_baseline': 'existing-baseline',
        'webdav_auto_sync': false,
      });
      FlutterSecureStorage.setMockInitialValues({});
      final settings = AppSettings();
      final service = _Service();
      addTearDown(settings.dispose);
      addTearDown(() => service.dio.close(force: true));
      await tester.pumpWidget(
        AppSettingsProvider(
          settings: settings,
          child: MaterialApp(
            theme: settings.lightTheme,
            builder: _captureBuilder,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WebDavSettingsPage(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _capturePage(tester, 'connection');
      final l10n = AppLocalizations.of(
        tester.element(find.byType(WebDavSettingsPage)),
      )!;
      expect(find.text(l10n.webdavDescription), findsNothing);
      expect(find.text(l10n.webdavTestDescription), findsNothing);
      final inputs = tester
          .widgetList<InputDecorator>(find.byType(InputDecorator))
          .map((input) => input.decoration)
          .toList();
      expect(inputs, hasLength(3));
      expect(inputs.first.labelText, l10n.webdavDirectory);
      expect(inputs.first.hintText, l10n.webdavDirectoryHint);
      expect(inputs[1].labelText, l10n.webdavUsername);
      expect(inputs.last.labelText, isNotEmpty);
      for (final input in inputs) {
        expect(input.helperText, isNull);
        expect(input.helper, isNull);
      }
      final save = find.widgetWithText(FilledButton, l10n.webdavSave);
      expect(save, findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, l10n.webdavSave),
        findsNothing,
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'not a directory');
      await revealWidget(tester, save);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(save).top,
        greaterThan(tester.getRect(fields.at(2)).bottom),
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('webdav_directory'), isNull);
      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), 'https://explicit.example/fzu/');
      await tester.enterText(fields.at(1), 'saved-user');
      await tester.enterText(fields.at(2), 'saved-secret');
      await revealWidget(tester, save);
      await tester.pumpAndSettle();
      final list = find.byType(ListView).first;
      final idleListRect = tester.getRect(list);
      final idleAppBarRect = tester.getRect(find.byType(AppBar));
      service.pendingTest = Completer<void>();
      await tester.tap(save);
      await tester.pump();
      expect(service.saves, 0);
      expect(preferences.getString('webdav_directory'), isNull);
      expect(await service.storage.read(key: 'fzu_webdav_password'), isNull);
      expect(service.testedConfig!.directory, 'https://explicit.example/fzu/');
      expect(service.testedConfig!.username, 'saved-user');
      expect(service.testedConfig!.password, 'saved-secret');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      for (final field in tester.widgetList<TextField>(fields)) {
        expect(field.enabled, isFalse);
      }
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(0);
      await tester.pump();
      final progress = find.byType(LinearProgressIndicator);
      expect(progress, findsOneWidget);
      final progressRect = tester.getRect(progress);
      expect(progressRect.height, 4);
      expect(progressRect.bottom, closeTo(idleListRect.top, 0.01));
      expect(tester.getRect(find.byType(AppBar)), idleAppBarRect);
      expect(tester.getRect(list), idleListRect);
      await _capturePage(tester, 'appbar-loading');
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      scrollable.position.jumpTo(
        scrollable.position.maxScrollExtent.clamp(0, 160).toDouble(),
      );
      await tester.pump();
      expect(scrollable.position.pixels, greaterThan(0));
      expect(
        tester.getRect(progress),
        progressRect,
        reason: 'The loading bar must stay fixed while the list scrolls.',
      );
      await _capturePage(tester, 'appbar-loading-scrolled');
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      expect(service.connectionTests, 2); // Invalid directory, then this test.
      expect(service.saves, 0);
      final busyScrollOffset = scrollable.position.pixels;
      service.pendingTest!.complete();
      await tester.pumpAndSettle();
      expect(progress, findsNothing);
      expect(tester.getRect(find.byType(AppBar)), idleAppBarRect);
      expect(tester.getRect(list), idleListRect);
      expect(scrollable.position.pixels, closeTo(busyScrollOffset, 0.01));
      expect(find.text(l10n.webdavSaved), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      final saved = await service.loadConfig();
      expect(saved.directory, 'https://explicit.example/fzu/');
      expect(saved.username, 'saved-user');
      expect(saved.password, 'saved-secret');
      expect(service.connectionTests, 2);
      expect(service.saves, 1);
      expect(service.uploads, 0);
      expect(service.restores, 0);
      expect(
        preferences.getString('webdav_sync_baseline'),
        'existing-baseline',
      );
      expect(preferences.getBool('webdav_auto_sync'), isFalse);
      expect(
        preferences.getKeys().any((key) => key.contains('password')),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final outcome in ['failure', 'account', 'configuration', 'disposed']) {
    testWidgets('test and save rejects $outcome without overwriting config', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'webdav_directory': 'https://saved.example/dav/',
        'webdav_username': 'old-user',
        'webdav_sync_baseline': 'old-baseline',
        'webdav_auto_sync': true,
      });
      FlutterSecureStorage.setMockInitialValues({
        'fzu_webdav_password': 'old-secret',
      });
      var accountRevision = 0;
      final service = _Service(
        captureAccountValidity: () {
          final captured = accountRevision;
          return () => captured == accountRevision;
        },
      )..pendingTest = Completer<void>();
      final settings = AppSettings();
      addTearDown(settings.dispose);
      addTearDown(() => service.dio.close(force: true));
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
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'https://new.example/dav/');
      await tester.enterText(fields.at(1), 'new-user');
      await tester.enterText(fields.at(2), 'new-secret');
      final save = find.widgetWithText(FilledButton, '测试并保存');
      await revealWidget(tester, save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pump();
      expect(service.connectionTests, 1);
      expect(service.saves, 0);
      if (outcome == 'failure') service.testError = Exception('probe failed');
      if (outcome == 'account') accountRevision++;
      if (outcome == 'configuration') {
        final otherPage = WebDavSyncService();
        addTearDown(() => otherPage.dio.close(force: true));
        await otherPage.saveConfig(
          const WebDavConfig(
            directory: 'https://other.example/dav/',
            username: 'other-user',
            password: 'other-secret',
          ),
        );
      }
      final preferences = await SharedPreferences.getInstance();
      final before = {
        for (final key in preferences.getKeys()) key: preferences.get(key),
      };
      final oldPassword = await service.storage.read(
        key: 'fzu_webdav_password',
      );
      if (outcome == 'disposed') {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      service.pendingTest!.complete();
      await tester.pumpAndSettle();
      expect(service.saves, 0);
      expect({
        for (final key in preferences.getKeys()) key: preferences.get(key),
      }, before);
      expect(
        await service.storage.read(key: 'fzu_webdav_password'),
        oldPassword,
      );
      expect(preferences.getString('webdav_sync_baseline'), 'old-baseline');
      expect(preferences.getBool('webdav_auto_sync'), isTrue);
      expect(service.uploads, 0);
      expect(service.restores, 0);
      if (outcome != 'disposed') {
        expect(find.byType(SelectableText), findsOneWidget);
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final width in [360.0, 1000.0]) {
    testWidgets('test and save aligns with input outlines at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final settings = AppSettings();
      final service = _Service();
      addTearDown(settings.dispose);
      addTearDown(() => service.dio.close(force: true));
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
      final button = tester.getRect(find.widgetWithText(FilledButton, '测试并保存'));
      for (final element in find.byType(EditableText).evaluate()) {
        final container = InputDecorator.containerOf(element)!;
        final outline = container.localToGlobal(Offset.zero) & container.size;
        expect(button.left, closeTo(outline.left, 0.01));
        expect(button.right, closeTo(outline.right, 0.01));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
    await revealWidget(tester, button);
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
    await revealWidget(tester, button);
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
    'upload, download and history restore require preview confirmation and preserve recovery',
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
      await revealWidget(
        tester,
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
      await revealWidget(
        tester,
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
      // CustomCourseStore keeps one process-wide edit queue. Exercise all real
      // restores in the same widget clock, as they run in one application.
      await _historyPreviewFlow(tester);
      await _localRecoveryFlow(tester);
    },
  );
}

Future<void> _historyPreviewFlow(WidgetTester tester) async {
  _captureViewport(tester);
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  const config = WebDavConfig(
    directory: 'https://dav.example/fzu/',
    username: 'test',
    password: 'private',
  );
  final server = WebDavTestServer();
  final service = WebDavSyncService(
    dio: Dio()..httpClientAdapter = server,
    appVersion: () async =>
        const WebDavAppVersion(version: '1.6.3', buildNumber: '176'),
  );
  addTearDown(() => service.dio.close(force: true));
  await service.saveConfig(config);
  final legacy = WebDavSnapshot.fromJson({
    'format': WebDavSyncService.format,
    'version': 1,
    'createdAt': '2026-11-01T00:00:00Z',
    'values': {...WebDavSyncService.defaults, SpKeys.themeMode: 'light'},
  });
  server.seed(config.fileUri, legacy.toJson());
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(SpKeys.themeMode, 'dark');
  final current = await service.exportSnapshot();
  // Dio's stream setup may schedule real asynchronous work; prepare the
  // remote store outside the fake widget clock, then test the UI normally.
  await tester.runAsync(() async {
    await service.upload(config, current, await service.readRemote(config));
  });
  final primary = server.files[config.fileUri.path];
  final settings = AppSettings();
  await settings.load();
  addTearDown(settings.dispose);
  await tester.pumpWidget(
    AppSettingsProvider(
      settings: settings,
      child: MaterialApp(
        theme: settings.lightTheme,
        builder: _captureBuilder,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WebDavSettingsPage(service: service),
      ),
    ),
  );
  await tester.pumpAndSettle();

  Future<void> pumpUntil(Finder finder) async {
    for (
      var attempt = 0;
      attempt < 20 && finder.evaluate().isEmpty;
      attempt++
    ) {
      // A streamed Dio response can complete on the real event queue.
      // Flush that queue while the progress indicator keeps animating.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> previewLegacy() async {
    final history = find.byIcon(Icons.history);
    await revealWidget(tester, history);
    await tester.pumpAndSettle();
    await tester.tap(history);
    await tester.pump();
    await pumpUntil(find.textContaining('数据格式版本: 1'));
    await tester.pump(const Duration(milliseconds: 300));
    await _capturePage(tester, 'history');
    expect(
      find.textContaining('数据格式版本: 1'),
      findsOneWidget,
      reason: [
        ...server.requests.map(
          (request) => '${request.method} ${request.uri.path}',
        ),
        ...tester.widgetList<Text>(find.byType(Text)).map((text) => text.data),
      ].join('\n'),
    );
    await tester.tap(find.textContaining('数据格式版本: 1'));
    await tester.pump();
    await pumpUntil(find.byType(AlertDialog));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('数据格式版本: 1'), findsOneWidget);
    expect(find.text('备份创建 App 版本: 旧备份未记录'), findsOneWidget);
  }

  await previewLegacy();
  expect(settings.themeModeKey.value, 'dark');
  await tester.tap(find.widgetWithText(TextButton, '取消'));
  await tester.pumpAndSettle();
  expect(settings.themeModeKey.value, 'dark');
  await previewLegacy();
  await tester.tap(find.widgetWithText(FilledButton, '确认'));
  await tester.pumpAndSettle();
  expect(settings.themeModeKey.value, 'light');
  expect(preferences.getString(SpKeys.themeMode), 'light');
  expect((await service.loadLocalRecovery())!.values[SpKeys.themeMode], 'dark');
  expect(server.files[config.fileUri.path], primary);
  expect(preferences.getString('webdav_sync_baseline'), isNull);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
}

Future<void> _localRecoveryFlow(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({SpKeys.themeMode: 'dark'});
  FlutterSecureStorage.setMockInitialValues({});
  final service = WebDavSyncService(appVersion: () async => null);
  addTearDown(() => service.dio.close(force: true));
  final preferences = await SharedPreferences.getInstance();
  final light = WebDavSnapshot.fromJson({
    ...(await service.exportSnapshot()).toJson(),
    'values': {...WebDavSyncService.defaults, SpKeys.themeMode: 'light'},
  });
  await service.restore(light);
  final settings = AppSettings();
  await settings.load();
  addTearDown(settings.dispose);
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
  await tester.enterText(find.byType(TextField).first, 'invalid directory');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final recovery = find.ancestor(
    of: find.byIcon(Icons.settings_backup_restore),
    matching: find.byType(ListTile),
  );
  await revealWidget(tester, recovery);
  await tester.pumpAndSettle();
  expect(recovery.hitTestable(), findsOneWidget);
  await tester.tap(recovery);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(preferences.getString('webdav_directory'), isNull);
  await tester.tap(find.widgetWithText(FilledButton, '确认'));
  await tester.pumpAndSettle();
  expect(settings.themeModeKey.value, 'dark');
  expect(preferences.getString(SpKeys.themeMode), 'dark');
  expect(preferences.getString('webdav_directory'), isNull);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
}
