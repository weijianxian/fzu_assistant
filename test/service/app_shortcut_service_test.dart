import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/app_shortcut_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  late AppShortcutService service;
  var takes = 0;
  final calls = <MethodCall>[];

  Future<void> receive(String action) async {
    await messenger.handlePlatformMessage(
      AppShortcutService.channel.name,
      codec.encodeMethodCall(MethodCall('action', action)),
      (_) {},
    );
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    service = AppShortcutService();
    takes = 0;
    calls.clear();
    messenger.setMockMethodCallHandler(AppShortcutService.channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'takePendingAction') {
        takes++;
        return 'campusCode';
      }
      return null;
    });
  });
  tearDown(() {
    AppShortcutService.channel.setMethodCallHandler(null);
    messenger.setMockMethodCallHandler(AppShortcutService.channel, null);
    service.pendingAction.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'cold action remains pending until authenticated Home consumes it once',
    () async {
      await service.initialize();
      expect(service.pendingAction.value, AppShortcutAction.campusCode);
      expect(service.consumePendingAction(authenticated: false), isNull);
      expect(service.pendingAction.value, AppShortcutAction.campusCode);
      expect(
        service.consumePendingAction(authenticated: true),
        AppShortcutAction.campusCode,
      );
      expect(service.consumePendingAction(authenticated: true), isNull);
      await service.initialize();
      expect(takes, 1);
      expect(service.pendingAction.value, isNull);
    },
  );

  test(
    'warm actions can change tabs after the initial intent was consumed',
    () async {
      await service.initialize();
      service.consumePendingAction(authenticated: true);
      await receive('schedule');
      expect(
        service.consumePendingAction(authenticated: true),
        AppShortcutAction.schedule,
      );
      await receive('campusCode');
      expect(
        service.consumePendingAction(authenticated: true),
        AppShortcutAction.campusCode,
      );
      await receive('unrecognizedExternalAction');
      expect(service.pendingAction.value, isNull);
    },
  );

  test('iOS shares the pending contract and localized labels', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await service.initialize();
    await service.updateLabels(campusCode: '一码通');
    expect(service.pendingAction.value, AppShortcutAction.campusCode);
    expect(calls.last.method, 'setLabels');
    expect(calls.last.arguments, {'campusCode': '一码通'});
  });

  test('desktop does not call mobile native methods', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await service.initialize();
    await service.updateLabels(campusCode: 'Campus code');
    expect(calls, isEmpty);
    expect(service.pendingAction.value, isNull);
  });
}
