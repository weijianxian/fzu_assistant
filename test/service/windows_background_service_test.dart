import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/service/desktop_window.dart';
import 'package:fzu_assistant/service/windows_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/windows_background.dart';

const labels = WindowsBackgroundLabels(
  appName: '福大助手',
  showWindow: '显示窗口',
  exit: '退出应用',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_control');
  late FakeBackgroundWindow native;
  late DesktopWindow window;
  late FakeBackgroundTray tray;
  late WindowsBackgroundService service;
  late List<String> exits;

  Future<void> configure() async {
    await service.initialize();
    service.updateLabels(labels);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> close() async {
    expect(native.requestClose().cancelled, isTrue);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    native = FakeBackgroundWindow();
    window = DesktopWindow.forTesting(native);
    tray = FakeBackgroundTray();
    service = WindowsBackgroundService.forTesting(window: window, tray: tray);
    exits = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          exits.add(call.method);
          tray.events.add('window.exit');
          return null;
        });
  });

  tearDown(() {
    service.dispose();
    window.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('old installs keep close-to-exit and never create a tray', () async {
    await configure();
    expect(service.enabled, isFalse);
    expect(tray.calls, isEmpty);
    await close();
    expect(exits, ['closeWindow']);
    expect(native.isVisible, isTrue);
    expect(native.calls, isNot(contains('hide')));
  });

  test(
    'opting in persists and close hides without stopping notifications',
    () async {
      await configure();
      var notificationsStopped = false;
      service.beforeExit = () async => notificationsStopped = true;
      expect(await service.setEnabled(true), isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          SpKeys.windowsCloseToTray,
        ),
        isTrue,
      );
      await close();
      expect(service.hidden, isTrue);
      expect(native.isVisible, isFalse);
      expect(tray.ready, isTrue);
      expect(exits, isEmpty);
      expect(notificationsStopped, isFalse);
    },
  );

  test(
    'labels arriving during startup still initialize a saved tray',
    () async {
      SharedPreferences.setMockInitialValues({SpKeys.windowsCloseToTray: true});
      service.updateLabels(labels);
      await service.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(service.enabled, isTrue);
      expect(service.trayReady, isTrue);
      expect(tray.labels, labels);
      expect(exits, isEmpty);
    },
  );

  test(
    'tray activation restores minimized window and focuses existing process',
    () async {
      await configure();
      await service.setEnabled(true);
      await close();
      native.isMinimized = true;
      native.calls.clear();
      await tray.onRestore!();
      expect(native.calls, ['restore', 'show', 'focus']);
      expect(native.isVisible, isTrue);
      expect(service.hidden, isFalse);
      expect(exits, isEmpty);
    },
  );

  test('toast activation also restores with close-to-tray off', () async {
    await configure();
    native.isMinimized = true;
    await service.restoreWindow();
    expect(native.calls, ['restore', 'show', 'focus']);
    expect(tray.calls, isEmpty);
    expect(service.enabled, isFalse);
  });

  test('disabling while hidden shows window before removing tray', () async {
    await configure();
    await service.setEnabled(true);
    await close();
    expect(await service.setEnabled(false), isTrue);
    expect(native.isVisible, isTrue);
    expect(service.hidden, isFalse);
    expect(service.enabled, isFalse);
    expect(tray.ready, isFalse);
    await close();
    expect(exits, ['closeWindow']);
  });

  for (final throws in [false, true]) {
    test(
      'tray failure (throws=$throws) rejects opt-in and preserves visible exit',
      () async {
        await configure();
        tray.creationFails = throws;
        tray.remainUnavailable = !throws;
        expect(await service.setEnabled(true), isFalse);
        expect(service.failed, isTrue);
        expect(service.enabled, isFalse);
        expect(service.trayReady, isFalse);
        expect(native.isVisible, isTrue);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            SpKeys.windowsCloseToTray,
          ),
          isNot(isTrue),
        );
        await close();
        expect(exits, ['closeWindow']);
        expect(native.calls, isNot(contains('hide')));
      },
    );
  }

  test(
    'persisted opt-in with unavailable tray stays visible and can exit',
    () async {
      SharedPreferences.setMockInitialValues({SpKeys.windowsCloseToTray: true});
      tray.creationFails = true;
      await configure();
      expect(service.enabled, isTrue);
      expect(service.failed, isTrue);
      expect(native.isVisible, isTrue);
      expect(service.hidden, isFalse);
      await close();
      expect(exits, ['closeWindow']);
      expect(native.calls, isNot(contains('hide')));
    },
  );

  test('a native hide failure cannot trap the process', () async {
    await configure();
    await service.setEnabled(true);
    native.hideFails = true;
    await close();
    expect(native.isVisible, isTrue);
    expect(exits, ['closeWindow']);
  });

  test(
    'close and disable serialize so the last command leaves a visible window',
    () async {
      await configure();
      await service.setEnabled(true);
      final gate = Completer<void>();
      tray.creationWait = gate.future;
      native.requestClose();
      final disable = service.setEnabled(false);
      gate.complete();
      await disable;
      expect(service.enabled, isFalse);
      expect(service.hidden, isFalse);
      expect(native.isVisible, isTrue);
      expect(tray.ready, isFalse);
      expect(exits, isEmpty);
    },
  );

  test(
    'tray Exit awaits notification shutdown before removing icon and process',
    () async {
      await configure();
      await service.setEnabled(true);
      final shutdown = Completer<void>();
      service.beforeExit = () async {
        tray.events.add('notifications.stopping');
        await shutdown.future;
        tray.events.add('notifications.stopped');
      };
      final exit = tray.onExit!();
      await Future<void>.delayed(Duration.zero);
      expect(exits, isEmpty);
      expect(tray.ready, isTrue);
      shutdown.complete();
      await exit;
      expect(tray.events, [
        'notifications.stopping',
        'notifications.stopped',
        'tray.destroy',
        'window.exit',
      ]);
      expect(exits, ['closeWindow']);
    },
  );

  test('notification cleanup failure still permits explicit exit', () async {
    await configure();
    await service.setEnabled(true);
    service.beforeExit = () async => throw StateError('Cleanup failed');
    await service.exitApplication();
    expect(exits, ['closeWindow']);
    expect(tray.ready, isFalse);
  });

  test(
    'exit channel failure restores the window and allows another exit',
    () async {
      await configure();
      await service.setEnabled(true);
      await close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'exit_failed');
          });
      await expectLater(
        service.exitApplication(),
        throwsA(isA<PlatformException>()),
      );
      expect(native.isVisible, isTrue);
      expect(service.hidden, isFalse);
      expect(service.failed, isTrue);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            exits.add(call.method);
            return null;
          });
      await service.exitApplication();
      expect(exits, ['closeWindow']);
    },
  );

  test(
    'non-Windows performs no window, tray, preference or exit action',
    () async {
      service.dispose();
      service = WindowsBackgroundService.forTesting(
        window: window,
        tray: tray,
        isSupported: false,
      );
      await configure();
      service.updateLabels(labels);
      expect(await service.setEnabled(true), isFalse);
      await service.restoreWindow();
      await service.exitApplication();
      expect(window.onCloseRequested, isNull);
      expect(native.calls, isEmpty);
      expect(tray.calls, ['destroy']); // Disposal of the initial test instance.
      expect(exits, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          SpKeys.windowsCloseToTray,
        ),
        isFalse,
      );
    },
  );
}
