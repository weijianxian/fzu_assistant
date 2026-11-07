import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/calendar_sync.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/calendar_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/reminder_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late CalendarSyncService service;
  final calls = <MethodCall>[];

  Map<String, Object> state({bool enabled = true}) => {
    'owner': calendarAccountKey('student'),
    'enabled': enabled,
    'granted': true,
    'lastSuccess': 1000,
  };

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mockReminderChannel();
    final auth = AuthStorage();
    await auth.saveCredentials('student', 'test-only');
    await auth.saveAcademicSession({
      'studentId': 'student',
      'userId': 'cached-identifier',
      'cookies': ['session=test; Path=/'],
    });
    expect(await ApiClient.instance.restoreCachedSession(), isTrue);
    service = CalendarSyncService();
    calls.clear();
    messenger.setMockMethodCallHandler(CalendarSyncService.channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'calendarState' ? <String, Object>{} : null;
    });
  });

  tearDown(() async {
    await ApiClient.instance.clearSession();
    service.status.dispose();
    messenger.setMockMethodCallHandler(CalendarSyncService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'calendar defaults off and a disabled sync does not refresh or write',
    () async {
      expect(service.status.value.enabled, isFalse);
      await service.load();
      expect(service.status.value.enabled, isFalse);
      expect(await service.syncNow(), isFalse);
      expect(calls.map((call) => call.method), ['calendarState']);
    },
  );

  test('another account cannot inherit enabled calendar sync', () async {
    messenger.setMockMethodCallHandler(CalendarSyncService.channel, (_) async {
      return {...state(), 'owner': calendarAccountKey('another-student')};
    });
    await service.load();
    expect(service.status.value.enabled, isFalse);
    expect(service.status.value.lastSuccess, isNull);
    expect(await service.syncNow(), isFalse);
  });

  test(
    'an older enabled response cannot replace the latest disabled state',
    () async {
      final entered = Completer<void>();
      final oldResponse = Completer<Map<String, Object>>();
      var reads = 0;
      messenger.setMockMethodCallHandler(CalendarSyncService.channel, (
        _,
      ) async {
        if (++reads == 1) {
          entered.complete();
          return oldResponse.future;
        }
        return state(enabled: false);
      });
      final oldLoad = service.load();
      await entered.future;
      await service.load();
      oldResponse.complete(state());
      await oldLoad;
      expect(service.status.value.enabled, isFalse);
      expect(await service.syncNow(), isFalse);
    },
  );

  test('disconnect invalidates an in-flight enabled response', () async {
    final entered = Completer<void>();
    final oldResponse = Completer<Map<String, Object>>();
    messenger.setMockMethodCallHandler(CalendarSyncService.channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'calendarState') {
        entered.complete();
        return oldResponse.future;
      }
      return null;
    });
    final loading = service.load();
    await entered.future;
    await service.disconnect();
    oldResponse.complete(state());
    await loading;
    expect(service.status.value.enabled, isFalse);
    expect(service.status.value.lastSuccess, isNull);
    expect(await service.syncNow(), isFalse);
    expect(calls.map((call) => call.method), [
      'calendarState',
      'calendarDisconnect',
    ]);
  });

  test('logout fences a pending account status response', () async {
    final entered = Completer<void>();
    final oldResponse = Completer<Map<String, Object>>();
    messenger.setMockMethodCallHandler(CalendarSyncService.channel, (
      call,
    ) async {
      if (call.method == 'calendarState') {
        entered.complete();
        return oldResponse.future;
      }
      return null;
    });
    final loading = service.load();
    await entered.future;
    await ApiClient.instance.clearSession();
    oldResponse.complete(state());
    await loading;
    expect(service.status.value.enabled, isFalse);
    expect(service.status.value.lastSuccess, isNull);
  });
}
