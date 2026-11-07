import 'dart:async';

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
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lectures_fixture.dart';
import '../fixtures/reminder_channel.dart';
import '../fixtures/reveal_widget.dart';

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

  test('日程默认提前 15 分钟，保留用户已选择的不提醒', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final service = CalendarSyncService();
    addTearDown(service.status.dispose);
    final state = <String, Object>{'owner': calendarAccountKey('20230001')};
    messenger.setMockMethodCallHandler(
      CalendarSyncService.channel,
      (_) async => state,
    );
    await service.load();
    expect(service.status.value.reminder, 15);
    state['reminder'] = 0;
    await service.load();
    expect(service.status.value.reminder, 0);
    state['owner'] = calendarAccountKey('another-account');
    await service.load();
    expect(service.status.value.reminder, 15);
  });

  for (final style in InterfaceStyle.values) {
    group(style.name, () {
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
              theme: buildTheme(Colors.deepPurple, interfaceStyle: style),
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
          expect(
            find.text(l10n.calendarSyncPermissionRequired),
            findsOneWidget,
          );
          expect(find.byType(ExpansionTile), findsNothing);
          await revealWidget(tester, find.text(l10n.calendarSyncPermission));
          expect(
            find.text(l10n.calendarSyncPermission).hitTestable(),
            findsOneWidget,
          );
          expect(find.text(l10n.reminderExactPermission), findsNothing);
          final scrollable = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
          await tester.pumpAndSettle();
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
            final lastRow = find.byKey(const Key('calendar-sync-clear'));
            expect(
              tester.getRect(lastRow).bottom,
              lessThanOrEqualTo(size.height - insets.bottom),
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
              theme: buildTheme(Colors.deepPurple, interfaceStyle: style),
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
          final clear = find.byKey(const Key('calendar-sync-clear'));
          expect(tester.getRect(clear).bottom, lessThanOrEqualTo(620 - 34));
          await tester.tap(clear);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text(l10n.learningCancel));
          await tester.pumpAndSettle();
          expect(
            calls.where((call) => call.method == 'calendarClear'),
            isEmpty,
          );
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

        testWidgets('$language 提醒选项即时保存，不添加课表同步入口', (tester) async {
          final calendar = _CalendarService();
          final nightly = _NightlyService();
          await _pumpPage(tester, language, calendar, nightly, style);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CalendarSyncSettingsPage)),
          )!;
          expect(
            find.descendant(
              of: find.byKey(const Key('calendar-sync-enabled')),
              matching: find.text(l10n.calendarSyncDescription),
            ),
            findsOneWidget,
          );
          final reminder = find.byKey(const Key('calendar-sync-reminder'));
          await tester.ensureVisible(reminder);
          await tester.tap(reminder);
          await tester.pumpAndSettle();
          expect(find.byType(RadioListTile<int>), findsNWidgets(4));
          calendar.saveGate = Completer<void>();
          await tester.tap(find.text(l10n.calendarExportReminderMinutes(30)));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(RadioGroup<int>), findsNothing);
          expect(calendar.syncCalls, 0);
          expect(find.text(l10n.calendarSyncBusy), findsNothing);
          calendar.saveGate!.complete();
          await tester.pumpAndSettle();
          expect(calendar.status.value.reminder, 30);
          expect(find.text(l10n.calendarSyncSaved), findsOneWidget);
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          expect(find.text(l10n.calendarSyncPending), findsOneWidget);
          expect(find.byType(SnackBarAction), findsNothing);
          expect(find.text(l10n.scheduleSync), findsNothing);
          expect(calendar.syncCalls, 0);
          expect(find.byType(CalendarSyncSettingsPage), findsOneWidget);
          expect(find.text(l10n.calendarSyncTime), findsNothing);
          expect(find.text(l10n.reminderExactPermission), findsNothing);
          expect(find.byKey(const Key('calendar-sync-now')), findsNothing);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('$language 状态读取失败后停止加载且可以重试', (tester) async {
          final calendar = _CalendarService()..failLoad = true;
          await _pumpPage(tester, language, calendar, _NightlyService(), style);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CalendarSyncSettingsPage)),
          )!;
          expect(find.text(l10n.calendarSyncLoadFailed), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          final enable = tester.widget<SwitchListTile>(
            find.descendant(
              of: find.byKey(const Key('calendar-sync-enabled')),
              matching: find.byType(SwitchListTile),
            ),
          );
          expect(enable.onChanged, isNull);
          calendar.failLoad = false;
          await tester.tap(find.byKey(const Key('calendar-sync-retry')));
          await tester.pumpAndSettle();
          expect(find.text(l10n.calendarSyncLoadFailed), findsNothing);
          expect(
            tester
                .widget<SwitchListTile>(
                  find.descendant(
                    of: find.byKey(const Key('calendar-sync-enabled')),
                    matching: find.byType(SwitchListTile),
                  ),
                )
                .onChanged,
            isNotNull,
          );
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('$language 启用日历仍会首次写入，失败保留在日历设置页', (tester) async {
          final calendar = _CalendarService()..syncGate = Completer<bool>();
          final nightly = _NightlyService(exactAllowed: false)
            ..enabled.value = false;
          calendar.status.value = const CalendarSyncStatus(granted: true);
          await _pumpPage(tester, language, calendar, nightly, style);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CalendarSyncSettingsPage)),
          )!;
          expect(find.text(l10n.calendarSyncAlarmHint), findsNothing);
          final enabled = find.byType(SwitchListTile).first;
          await tester.tap(enabled);
          await tester.tap(enabled);
          await tester.pump();
          expect(calendar.syncCalls, 1);
          expect(tester.widget<SwitchListTile>(enabled).onChanged, isNull);
          calendar.syncGate!.complete(false);
          await tester.pumpAndSettle();
          expect(find.text(l10n.calendarSyncFailed), findsOneWidget);
          expect(find.text(l10n.scheduleSync), findsNothing);
          expect(find.byType(CalendarSyncSettingsPage), findsOneWidget);
          expect(nightly.enabled.value, isFalse);
          expect(nightly.permissionRequests, 0);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('$language 删除中显示删除进度，确认弹窗只能打开一次', (tester) async {
          final calendar = _CalendarService()..clearGate = Completer<void>();
          await _pumpPage(tester, language, calendar, _NightlyService(), style);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CalendarSyncSettingsPage)),
          )!;
          final clear = find.byKey(const Key('calendar-sync-clear'));
          await revealWidget(tester, clear);
          final clearTile = find.descendant(
            of: clear,
            matching: find.byType(ListTile),
          );
          final openClear = tester.widget<ListTile>(clearTile).onTap!;
          openClear();
          openClear();
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(
            find.byKey(const Key('calendar-sync-clear-confirm')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(calendar.clearCalls, 1);
          expect(find.text(l10n.calendarSyncClearing), findsWidgets);
          expect(find.text(l10n.calendarSyncBusy), findsNothing);
          expect(tester.widget<ListTile>(clearTile).onTap, isNull);
          calendar.clearGate!.complete();
          await tester.pumpAndSettle();
          expect(find.text(l10n.calendarSyncCleared), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        });
      }
    });
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  String language,
  CalendarSyncService calendar,
  WidgetSyncService nightly,
  InterfaceStyle style,
) async {
  tester.view.physicalSize = const Size(400, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Colors.deepPurple, interfaceStyle: style),
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CalendarSyncSettingsPage(
        calendarService: calendar,
        syncService: nightly,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _CalendarService extends CalendarSyncService {
  _CalendarService() {
    status.value = CalendarSyncStatus(
      enabled: true,
      granted: true,
      lastSuccess: DateTime.utc(2026, 11, 6, 23),
      count: 67,
    );
  }

  bool failLoad = false;
  int syncCalls = 0, clearCalls = 0;
  Completer<void>? saveGate, clearGate;
  Completer<bool>? syncGate;

  @override
  Future<void> load() async {
    if (failLoad) throw StateError('test load failure');
  }

  @override
  Future<void> configure({
    bool? enabled,
    bool? includeExams,
    int? reminder,
  }) async {
    await saveGate?.future;
    final previous = status.value;
    status.value = CalendarSyncStatus(
      enabled: enabled ?? previous.enabled,
      granted: previous.granted,
      includeExams: includeExams ?? previous.includeExams,
      reminder: reminder ?? previous.reminder,
      lastSuccess: previous.lastSuccess,
      count: previous.count,
    );
  }

  @override
  Future<bool> syncNow() async {
    syncCalls++;
    return await syncGate?.future ?? true;
  }

  @override
  Future<void> clearAll() async {
    clearCalls++;
    await clearGate?.future;
    status.value = const CalendarSyncStatus(granted: true);
  }
}

class _NightlyService extends WidgetSyncService {
  _NightlyService({bool exactAllowed = true}) {
    status.value = WidgetSyncStatus(exactAllowed: exactAllowed);
  }

  int permissionRequests = 0;

  @override
  Future<void> reconcile() async {}

  @override
  Future<void> requestExactPermission() async {
    permissionRequests++;
    status.value = const WidgetSyncStatus(exactAllowed: true);
  }
}
