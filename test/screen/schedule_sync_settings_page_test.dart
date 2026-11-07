import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/schedule_sync_settings_page.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/calendar_sync_service.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';

import '../fixtures/reveal_widget.dart';

void main() {
  late _SyncService sync;
  late _CalendarService calendar;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    sync = _SyncService();
    calendar = _CalendarService();
  });
  tearDown(() {
    sync.enabled.dispose();
    sync.minutes.dispose();
    sync.status.dispose();
    calendar.status.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  Future<AppLocalizations> open(
    WidgetTester tester, {
    String language = 'zh',
    InterfaceStyle style = InterfaceStyle.classic,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Colors.blue, interfaceStyle: style),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: ScheduleSyncSettingsPage(
          syncService: sync,
          calendarService: calendar,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(ScheduleSyncSettingsPage)),
    )!;
  }

  for (final style in InterfaceStyle.values) {
    for (final language in ['zh', 'en']) {
      testWidgets('$style $language 手动同步不依赖自动开关或闹钟权限，重复点击只执行一次', (
        tester,
      ) async {
        sync.enabled.value = false;
        sync.refreshGate = Completer<bool>();
        final l10n = await open(tester, style: style, language: language);
        final button = find.byKey(const Key('schedule-sync-now'));
        final filled = find.descendant(
          of: button,
          matching: find.byType(FilledButton),
        );
        final onPressed = tester.widget<FilledButton>(filled).onPressed!;
        onPressed();
        onPressed();
        await tester.pump();
        expect(sync.refreshes, 1);
        expect(sync.permissionRequests, 0);
        expect(tester.widget<FilledButton>(filled).onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        sync.refreshGate!.complete(true);
        await tester.pumpAndSettle();
        expect(find.text(l10n.scheduleSyncUpdated), findsOneWidget);
        expect(sync.enabled.value, isFalse);
        expect(sync.status.value.exactAllowed, isFalse);
        expect(calendar.loads, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('$style $language 窄屏大字及两侧刘海横屏的权限项可见且避让底部', (tester) async {
        final l10n = await open(
          tester,
          style: style,
          language: language,
          textScale: 1.4,
        );
        for (final (size, insets) in [
          (const Size(320, 900), const FakeViewPadding(top: 24, bottom: 34)),
          (
            const Size(900, 400),
            const FakeViewPadding(left: 48, top: 24, bottom: 34),
          ),
          (
            const Size(900, 400),
            const FakeViewPadding(right: 48, top: 24, bottom: 34),
          ),
        ]) {
          tester.view.physicalSize = size;
          tester.view.padding = insets;
          tester.view.viewPadding = insets;
          await tester.pumpAndSettle();
          final permission = find.text(l10n.reminderExactPermission);
          await revealWidget(tester, permission);
          expect(find.byType(ExpansionTile), findsNothing);
          expect(permission.hitTestable(), findsOneWidget);
          final tile = find.widgetWithText(
            ListTile,
            l10n.reminderExactPermission,
          );
          final bounds = tester.getRect(tile);
          expect(bounds.left, greaterThanOrEqualTo(insets.left));
          expect(bounds.right, lessThanOrEqualTo(size.width - insets.right));
          expect(bounds.bottom, lessThanOrEqualTo(size.height - insets.bottom));
          expect(tester.getRect(find.byType(ListView)).bottom, size.height);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }

  testWidgets('统一开关、北京时间和权限修改可保存，返回前台重新读取状态', (tester) async {
    final l10n = await open(tester);
    final enabled = find.byType(SwitchListTile);
    await revealWidget(tester, enabled);
    await tester.tap(enabled);
    await tester.pumpAndSettle();
    expect(sync.enabled.value, isFalse);
    final timeTile = find.widgetWithText(ListTile, l10n.widgetSyncTime);
    expect(tester.widget<ListTile>(timeTile).onTap, isNull);
    await tester.tap(enabled);
    await tester.pumpAndSettle();
    final choose = tester.widget<ListTile>(timeTile).onTap!;
    choose();
    choose();
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialTime,
      const TimeOfDay(hour: 23, minute: 0),
    );
    final material = MaterialLocalizations.of(
      tester.element(find.byType(TimePickerDialog)),
    );
    await tester.tap(find.byTooltip(material.inputTimeModeButtonLabel));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '22');
    await tester.enterText(find.byType(TextField).at(1), '15');
    await tester.tap(find.text(material.okButtonLabel));
    await tester.pumpAndSettle();
    expect(sync.minutes.value, 22 * 60 + 15);
    final permission = find.text(l10n.reminderExactPermission);
    await revealWidget(tester, permission);
    await tester.tap(permission);
    await tester.pumpAndSettle();
    expect(sync.permissionRequests, 1);
    expect(sync.status.value.exactAllowed, isTrue);
    final previous = sync.reconciles;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(sync.reconciles, previous + 1);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('失败保留最近成功时间，日历写入失败不能报整体成功', (tester) async {
    sync.status.value = WidgetSyncStatus(
      lastSuccess: DateTime.utc(2026, 11, 6, 15, 45),
    );
    sync.succeeds = false;
    final l10n = await open(tester, language: 'en');
    await tester.tap(find.byKey(const Key('schedule-sync-now')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.widgetSyncFailed), findsOneWidget);
    expect(find.textContaining('23:45'), findsOneWidget);
    expect(find.textContaining('Beijing time'), findsWidgets);
    sync.succeeds = true;
    calendar.status.value = const CalendarSyncStatus(
      enabled: true,
      granted: true,
      failed: true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-sync-now')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarSyncFailed), findsOneWidget);
    expect(find.text(l10n.scheduleSyncUpdated), findsNothing);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('读取失败可重试，读取前禁用修改和联网同步', (tester) async {
    sync.failLoad = true;
    final l10n = await open(tester);
    expect(find.text(l10n.calendarSyncLoadFailed), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    sync.failLoad = false;
    await tester.tap(find.byKey(const Key('schedule-sync-now')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarSyncLoadFailed), findsNothing);
    expect(sync.refreshes, 0);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('非 Android 不读取同步状态或展示操作', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final l10n = await open(tester);
    expect(find.text(l10n.scheduleSyncUnsupported), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(sync.reconciles, 0);
    expect(calendar.loads, 0);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}

class _SyncService extends WidgetSyncService {
  bool failLoad = false, succeeds = true;
  int reconciles = 0, refreshes = 0, permissionRequests = 0;
  Completer<bool>? refreshGate;

  @override
  Future<void> reconcile() async {
    reconciles++;
    if (failLoad) throw StateError('cannot read state');
  }

  @override
  Future<void> configure({bool? enabled, int? minutes}) async {
    if (enabled != null) this.enabled.value = enabled;
    if (minutes != null) this.minutes.value = minutes;
  }

  @override
  Future<bool> refreshNow() async {
    refreshes++;
    final previous = status.value;
    status.value = WidgetSyncStatus(
      exactAllowed: previous.exactAllowed,
      running: true,
      lastSuccess: previous.lastSuccess,
    );
    final refreshed = await refreshGate?.future ?? succeeds;
    status.value = WidgetSyncStatus(
      exactAllowed: previous.exactAllowed,
      failed: !refreshed,
      lastSuccess: refreshed
          ? DateTime.utc(2026, 11, 7, 15)
          : previous.lastSuccess,
    );
    return refreshed;
  }

  @override
  Future<void> requestExactPermission() async {
    permissionRequests++;
    status.value = const WidgetSyncStatus(exactAllowed: true);
  }
}

class _CalendarService extends CalendarSyncService {
  int loads = 0;
  @override
  Future<void> load() async {
    loads++;
  }
}
