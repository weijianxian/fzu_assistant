import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/calendar_sync_service.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';

enum _Operation { loading, saving, permission, syncing }

class ScheduleSyncSettingsPage extends HookWidget {
  const ScheduleSyncSettingsPage({
    super.key,
    this.syncService,
    this.calendarService,
  });

  final WidgetSyncService? syncService;
  final CalendarSyncService? calendarService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = syncService ?? WidgetSyncService.instance;
    final calendar = calendarService ?? CalendarSyncService.instance;
    final enabled = useValueListenable(service.enabled);
    final minutes = useValueListenable(service.minutes);
    final status = useValueListenable(service.status);
    final calendarStatus = useValueListenable(calendar.status);
    final operation = useState<_Operation?>(null);
    final modalOpen = useState(false);
    final ready = useState(false);
    final error = useState<String?>(null);
    final working =
        operation.value != null || modalOpen.value || status.running;
    final syncing = operation.value == _Operation.syncing || status.running;

    Future<void> run(_Operation next, Future<void> Function() action) async {
      if (operation.value != null ||
          modalOpen.value ||
          service.status.value.running) {
        return;
      }
      operation.value = next;
      error.value = null;
      try {
        await action();
      } catch (_) {
        if (context.mounted) {
          error.value = switch (next) {
            _Operation.loading => l10n.calendarSyncLoadFailed,
            _Operation.saving => l10n.calendarSyncSaveFailed,
            _Operation.permission => l10n.calendarSyncScheduleFailed,
            _Operation.syncing => l10n.widgetSyncFailed,
          };
        }
      } finally {
        if (context.mounted) operation.value = null;
      }
    }

    Future<void> readState() async {
      await service.reconcile();
      await calendar.load();
      if (context.mounted) ready.value = true;
    }

    Future<void> reload() => run(_Operation.loading, readState);

    Future<void> syncNow() => run(_Operation.syncing, () async {
      final refreshed = await service.refreshNow();
      await calendar.load();
      if (!context.mounted) return;
      if (!refreshed) {
        error.value = l10n.widgetSyncFailed;
      } else if (calendar.status.value.enabled &&
          calendar.status.value.failed) {
        error.value = l10n.calendarSyncFailed;
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.scheduleSyncUpdated)));
      }
    });

    Future<void> chooseTime() async {
      if (!ready.value ||
          working ||
          modalOpen.value ||
          operation.value != null ||
          service.status.value.running) {
        return;
      }
      modalOpen.value = true;
      TimeOfDay? time;
      try {
        time = await showTimePicker(
          context: context,
          helpText: l10n.reminderBeijingTime(l10n.widgetSyncTime),
          initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        );
      } finally {
        if (context.mounted) modalOpen.value = false;
      }
      if (time == null || !context.mounted) return;
      final selected = time.hour * 60 + time.minute;
      if (selected != minutes) {
        await run(
          _Operation.saving,
          () => service.configure(minutes: selected),
        );
      }
    }

    useEffect(() {
      if (WidgetSyncService.supported) unawaited(reload());
      return null;
    }, []);
    useOnAppLifecycleStateChange((_, state) {
      if (WidgetSyncService.supported && state == AppLifecycleState.resumed) {
        unawaited(reload());
      }
    });

    String dateTime(DateTime instant) {
      final time = instant.toUtc().add(const Duration(hours: 8));
      return l10n.reminderBeijingTime(
        '${MaterialLocalizations.of(context).formatMediumDate(time)} '
        '${TimeOfDay.fromDateTime(time).format(context)}',
      );
    }

    final failure =
        error.value ??
        (status.failed
            ? l10n.widgetSyncFailed
            : calendarStatus.enabled && calendarStatus.failed
            ? l10n.calendarSyncFailed
            : null);
    final canEdit = ready.value && !working;

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.scheduleSync)),
      body: AppListView(
        children: [
          ListTile(title: Text(l10n.scheduleSyncDescription)),
          if (!WidgetSyncService.supported)
            ListTile(title: Text(l10n.scheduleSyncUnsupported))
          else ...[
            SettingsSection(
              title: l10n.settingsSyncStatusSection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (operation.value != null && !syncing)
                    LinearProgressIndicator(
                      semanticsLabel: operation.value == _Operation.saving
                          ? l10n.calendarSyncSaving
                          : l10n.reminderPermissionLoading,
                    ),
                  SettingsStatus(
                    title: syncing
                        ? l10n.calendarSyncBusy
                        : failure ??
                              (!ready.value
                                  ? l10n.reminderPermissionLoading
                                  : status.lastSuccess == null
                                  ? l10n.widgetSyncNever
                                  : l10n.widgetSyncLastSuccess),
                    isError: failure != null,
                    details: [
                      if (status.lastSuccess != null)
                        dateTime(status.lastSuccess!),
                    ],
                    action: SettingsActionButton(
                      key: const Key('schedule-sync-now'),
                      label: syncing
                          ? l10n.calendarSyncBusy
                          : !ready.value
                          ? l10n.retry
                          : l10n.calendarSyncNow,
                      icon: Icons.sync,
                      busy: syncing,
                      onPressed: working
                          ? null
                          : !ready.value
                          ? reload
                          : syncNow,
                    ),
                  ),
                ],
              ),
            ),
            const SettingsDivider(),
            SettingsSection.list(
              title: l10n.settingsAutoSyncSection,
              children: [
                SettingSwitchTile.controlled(
                  key: const Key('schedule-sync-enabled'),
                  title: Text(l10n.widgetSyncEnabled),
                  subtitle: Text(l10n.scheduleSyncAutomaticDescription),
                  value: enabled,
                  onChanged: canEdit
                      ? (value) => run(
                          _Operation.saving,
                          () => service.configure(enabled: value),
                        )
                      : null,
                ),
                ChevronListTile(
                  title: Text(l10n.widgetSyncTime),
                  subtitle: Text(
                    l10n.reminderBeijingTime(
                      TimeOfDay(
                        hour: minutes ~/ 60,
                        minute: minutes % 60,
                      ).format(context),
                    ),
                  ),
                  onTap: canEdit && enabled ? chooseTime : null,
                ),
                if (enabled && status.nextAt != null)
                  ListTile(
                    title: Text(l10n.widgetSyncNext),
                    subtitle: Text(dateTime(status.nextAt!)),
                  ),
              ],
            ),
            const SettingsDivider(),
            SettingsSection.list(
              title: l10n.settingsPermissionsSection,
              children: [
                SettingsPermissionTile(
                  title: l10n.reminderExactPermission,
                  purpose: l10n.scheduleSyncAlarmPurpose,
                  granted: ready.value ? status.exactAllowed : null,
                  onTap: canEdit
                      ? () => run(_Operation.permission, () async {
                          await service.requestExactPermission();
                          await readState();
                        })
                      : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
