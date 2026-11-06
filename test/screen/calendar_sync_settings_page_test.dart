import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar_sync.dart';
import 'package:fzu_assistant/screen/settings/calendar_sync_settings_page.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/calendar_sync_service.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lectures_fixture.dart';
import '../fixtures/reminder_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final api = ApiClient.instance;
  final calls = <MethodCall>[];
  final previousAdapter = api.dio.httpClientAdapter;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mockReminderChannel();
    api.dio.httpClientAdapter = LecturesFixtureAdapter();
    await api.login('20230001', 'test-only', '1234');
    calls.clear();
    messenger.setMockMethodCallHandler(CalendarSyncService.channel, (
      call,
    ) async {
      calls.add(call);
      return switch (call.method) {
        'calendarState' => {
          'owner': calendarAccountKey('20230001'),
          'enabled': false,
          'granted': false,
          'includeExams': true,
          'reminder': 15,
        },
        'getState' => {'enabled': false, 'minutes': 1380},
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(AndroidPermissionsService.channel, (
      call,
    ) async {
      calls.add(call);
      return false;
    });
  });
  tearDown(() async {
    await api.clearSession();
    api.dio.httpClientAdapter = previousAdapter;
    messenger.setMockMethodCallHandler(CalendarSyncService.channel, null);
    messenger.setMockMethodCallHandler(AndroidPermissionsService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final language in ['zh', 'en']) {
    testWidgets('$language 日历权限拒绝不启用同步，大字窄屏及横屏无溢出', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(320, 920);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const CalendarSyncSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CalendarSyncSettingsPage)),
      )!;
      expect(find.text(l10n.calendarSync), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      expect(CalendarSyncService.instance.status.value.enabled, isFalse);
      expect(
        calls.where((call) => call.method == 'calendarConfigure'),
        isEmpty,
      );
      expect(
        calls.where((call) => call.method == 'requestCalendar'),
        hasLength(1),
      );
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.calendarSyncPermissionRequired),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '),
      );
      for (final (size, insets) in [
        (const Size(320, 920), const FakeViewPadding(top: 24, bottom: 34)),
        (
          const Size(920, 400),
          const FakeViewPadding(left: 48, top: 24, bottom: 34),
        ),
        (
          const Size(920, 400),
          const FakeViewPadding(right: 48, top: 24, bottom: 34),
        ),
      ]) {
        tester.view.physicalSize = size;
        tester.view.padding = insets;
        tester.view.viewPadding = insets;
        await tester.pumpAndSettle();
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(ListView)),
          Rect.fromLTRB(
            insets.left,
            tester.getRect(find.byType(AppBar)).bottom,
            size.width - insets.right,
            size.height,
          ),
        );
        final lastRow = find.ancestor(
          of: find.text(l10n.calendarSyncPermissionRequired),
          matching: find.byType(ListTile),
        );
        expect(
          tester.getRect(lastRow).bottom,
          closeTo(size.height - insets.bottom, 0.01),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      expect(WidgetSyncService.instance.status.value.running, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('$language 清理日程必须确认，关闭同步并保留小组件设置', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 620);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
      addTearDown(tester.view.reset);
      var enabled = true;
      messenger.setMockMethodCallHandler(CalendarSyncService.channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'calendarClear') {
          enabled = false;
          return null;
        }
        return switch (call.method) {
          'calendarState' => {
            'owner': calendarAccountKey('20230001'),
            'enabled': enabled,
            'granted': true,
            'includeExams': true,
            'reminder': 15,
          },
          'getState' => {'enabled': true, 'minutes': 1380},
          _ => null,
        };
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CalendarSyncSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CalendarSyncSettingsPage)),
      )!;
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final clear = find.byType(OutlinedButton);
      expect(tester.getRect(clear).bottom, lessThanOrEqualTo(620 - 34));
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text(l10n.learningCancel));
      await tester.pumpAndSettle();
      expect(calls.where((call) => call.method == 'calendarClear'), isEmpty);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'calendarClear'),
        hasLength(1),
      );
      expect(CalendarSyncService.instance.status.value.enabled, isFalse);
      expect(WidgetSyncService.instance.enabled.value, isTrue);
      expect(find.text(l10n.calendarSyncCleared), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
