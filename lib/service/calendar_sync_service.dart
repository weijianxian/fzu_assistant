import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fzu_assistant/model/calendar_sync.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';

class CalendarSyncStatus {
  const CalendarSyncStatus({
    this.enabled = false,
    this.granted = false,
    this.includeExams = true,
    this.reminder = 15,
    this.failed = false,
    this.lastSuccess,
    this.count = 0,
    this.inserted = 0,
    this.updated = 0,
    this.deleted = 0,
  });
  final bool enabled, granted, includeExams, failed;
  final int reminder, count, inserted, updated, deleted;
  final DateTime? lastSuccess;
}

class CalendarSyncService {
  static final instance = CalendarSyncService();
  static bool get supported => WidgetSyncService.supported;
  static const channel = WidgetSyncService.channel;
  final status = ValueNotifier(const CalendarSyncStatus());
  int _revision = 0;

  Future<void> load() async {
    if (!supported) return;
    final revision = ++_revision;
    final account = ApiClient.instance.studentId;
    final raw = await channel.invokeMapMethod<String, dynamic>('calendarState');
    if (raw == null ||
        revision != _revision ||
        account != ApiClient.instance.studentId) {
      return;
    }
    final sameAccount =
        account != null &&
        account.isNotEmpty &&
        raw['owner'] == calendarAccountKey(account);
    final last = sameAccount ? (raw['lastSuccess'] as num?)?.toInt() : null;
    status.value = CalendarSyncStatus(
      enabled: sameAccount && raw['enabled'] == true,
      granted: raw['granted'] == true,
      includeExams: !sameAccount || raw['includeExams'] != false,
      reminder: sameAccount ? (raw['reminder'] as int? ?? 15) : 15,
      failed: sameAccount && raw['failed'] == true,
      lastSuccess: last == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(last, isUtc: true),
      count: sameAccount ? (raw['count'] as int? ?? 0) : 0,
      inserted: sameAccount ? (raw['inserted'] as int? ?? 0) : 0,
      updated: sameAccount ? (raw['updated'] as int? ?? 0) : 0,
      deleted: sameAccount ? (raw['deleted'] as int? ?? 0) : 0,
    );
  }

  Future<bool> requestPermission() async {
    final result = await AndroidPermissionsService.channel.invokeMethod<bool>(
      'requestCalendar',
    );
    await load();
    return result == true && status.value.granted;
  }

  Future<void> configure({
    bool? enabled,
    bool? includeExams,
    int? reminder,
  }) async {
    final account = ApiClient.instance.studentId;
    if (account == null || account.isEmpty) throw StateError('请先登录教务账号');
    final current = status.value;
    ++_revision;
    await channel.invokeMethod<void>('calendarConfigure', {
      'settings': {
        'owner': calendarAccountKey(account),
        'enabled': enabled ?? current.enabled,
        'includeExams': includeExams ?? current.includeExams,
        'reminder': reminder ?? current.reminder,
      },
    });
    await WidgetSyncService.instance.reconcile();
    await load();
  }

  Future<bool> syncNow() async {
    if (!status.value.enabled) return false;
    final refreshed = await WidgetSyncService.instance.refreshNow();
    await load();
    return refreshed &&
        !status.value.failed &&
        status.value.lastSuccess != null;
  }

  Future<void> clearAll() async {
    ++_revision;
    try {
      await channel.invokeMethod<void>('calendarClear');
    } finally {
      // Clearing disables only calendar sync; keep widget refreshes if enabled.
      await WidgetSyncService.instance.reconcile();
      await load();
    }
  }

  Future<void> disconnect() async {
    ++_revision;
    status.value = const CalendarSyncStatus();
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('calendarDisconnect');
    } on MissingPluginException {
      // Optional integration is absent in desktop and test hosts.
    } on PlatformException {
      // The shared nightly generation has already been revoked by logout.
    }
  }
}
