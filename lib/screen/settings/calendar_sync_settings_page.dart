import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/service/calendar_sync_service.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';

enum _Operation { loading, saving, permission, syncing, clearing }

class CalendarSyncSettingsPage extends HookWidget {
  const CalendarSyncSettingsPage({
    super.key,
    this.calendarService,
    this.syncService,
  });

  final CalendarSyncService? calendarService;
  final WidgetSyncService? syncService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final service = calendarService ?? CalendarSyncService.instance;
    final nightly = syncService ?? WidgetSyncService.instance;
    final status = useValueListenable(service.status);
    final nightlyStatus = useValueListenable(nightly.status);
    final minutes = useValueListenable(nightly.minutes);
    final operation = useState<_Operation?>(null);
    final modalOpen = useState(false);
    final ready = useState(false);
    final pendingChanges = useState(false);
    final error = useState<String?>(null);
    final scroll = useScrollController();
    final working =
        operation.value != null || modalOpen.value || nightlyStatus.running;
    final syncing =
        operation.value == _Operation.syncing || nightlyStatus.running;
    final clearing = operation.value == _Operation.clearing;

    Future<bool> run(_Operation next, Future<void> Function() action) async {
      if (!context.mounted ||
          operation.value != null ||
          modalOpen.value ||
          nightly.status.value.running) {
        return false;
      }
      operation.value = next;
      error.value = null;
      try {
        await action();
        return true;
      } catch (_) {
        if (context.mounted) {
          error.value = switch (operation.value) {
            _Operation.loading => l10n.calendarSyncLoadFailed,
            _Operation.saving => l10n.calendarSyncSaveFailed,
            _Operation.clearing => l10n.calendarSyncClearFailed,
            _Operation.permission => l10n.calendarSyncPermissionRequired,
            _ => l10n.calendarSyncFailed,
          };
        }
        return false;
      } finally {
        if (context.mounted) operation.value = null;
      }
    }

    Future<void> readState() async {
      await service.load();
      await nightly.reconcile();
      if (context.mounted) ready.value = true;
    }

    Future<void> reload() => run(_Operation.loading, readState);

    Future<void> sync() async {
      operation.value = _Operation.syncing;
      final success = await service.syncNow();
      if (!context.mounted) return;
      if (success) {
        pendingChanges.value = false;
      } else {
        error.value = l10n.calendarSyncFailed;
      }
    }

    void syncNow() => unawaited(run(_Operation.syncing, sync));

    Future<void> setEnabled(bool enabled) => run(_Operation.saving, () async {
      if (enabled &&
          !service.status.value.granted &&
          !await service.requestPermission()) {
        if (context.mounted) {
          error.value = l10n.calendarSyncPermissionRequired;
        }
        return;
      }
      if (!context.mounted) return;
      await service.configure(enabled: enabled);
      if (enabled && context.mounted) await sync();
    });

    Future<void> saveOptions({bool? includeExams, int? reminder}) async {
      final saved = await run(
        _Operation.saving,
        () => service.configure(includeExams: includeExams, reminder: reminder),
      );
      if (!saved || !context.mounted) return;
      pendingChanges.value = true;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.calendarSyncSaved),
            action: service.status.value.enabled
                ? SnackBarAction(
                    label: l10n.calendarSyncNow,
                    onPressed: syncNow,
                  )
                : null,
          ),
        );
    }

    Future<void> calendarPermission() => run(_Operation.permission, () async {
      if (service.status.value.granted) {
        await AndroidPermissionsService.openSettings(
          'android.permission.WRITE_CALENDAR',
        );
      } else if (!await service.requestPermission()) {
        await AndroidPermissionsService.openSettings(
          'android.permission.WRITE_CALENDAR',
        );
      }
      await readState();
    });

    Future<void> alarmPermission() => run(_Operation.permission, () async {
      await nightly.requestExactPermission();
      await readState();
    });

    Future<T?> showChoice<T>(Future<T?> Function() show) async {
      if (working || modalOpen.value || operation.value != null) return null;
      modalOpen.value = true;
      try {
        return await show();
      } finally {
        if (context.mounted) modalOpen.value = false;
      }
    }

    Future<void> chooseReminder() async {
      final selected = await showChoice(
        () => showSettingsChoiceSheet<int>(
          context: context,
          title: l10n.calendarExportReminder,
          selected: status.reminder,
          choices: [
            for (final value in [0, 5, 15, 30])
              SettingsChoice(
                value: value,
                label: value == 0
                    ? l10n.calendarExportNoReminder
                    : l10n.calendarExportReminderMinutes(value),
              ),
          ],
        ),
      );
      if (selected == null || !context.mounted || selected == status.reminder) {
        return;
      }
      await saveOptions(reminder: selected);
    }

    Future<void> chooseTime() async {
      final selected = await showChoice(
        () => showTimePicker(
          context: context,
          helpText: l10n.reminderBeijingTime(l10n.calendarSyncTime),
          initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        ),
      );
      if (selected == null || !context.mounted) return;
      final value = selected.hour * 60 + selected.minute;
      if (value == minutes) return;
      await run(_Operation.saving, () async {
        await nightly.configure(minutes: value);
        if (context.mounted && nightly.status.value.failed) {
          error.value = l10n.calendarSyncScheduleFailed;
        }
      });
    }

    Future<void> clearAll() async {
      final confirmed = await showChoice(
        () => showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(l10n.calendarSyncClear),
            content: Text(l10n.calendarSyncClearHint),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.learningCancel),
              ),
              FilledButton(
                key: const Key('calendar-sync-clear-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.calendarSyncClearConfirm),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final cleared = await run(_Operation.clearing, () async {
        if (!service.status.value.granted &&
            !await service.requestPermission()) {
          if (context.mounted) {
            error.value = l10n.calendarSyncPermissionRequired;
          }
          return;
        }
        await service.clearAll();
      });
      if (!context.mounted) return;
      if (cleared && error.value == null) {
        pendingChanges.value = false;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.calendarSyncCleared)));
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(error.value ?? l10n.calendarSyncClearFailed),
            ),
          );
      }
    }

    useEffect(() {
      unawaited(reload());
      return null;
    }, []);
    useEffect(() {
      pendingChanges.value = false;
      return null;
    }, [status.lastSuccess]);
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) unawaited(reload());
    });

    String dateTime(DateTime instant) {
      final time = instant.toUtc().add(const Duration(hours: 8));
      return l10n.reminderBeijingTime(
        '${MaterialLocalizations.of(context).formatMediumDate(time)} '
        '${TimeOfDay.fromDateTime(time).format(context)}',
      );
    }

    final needsCalendar = ready.value && !status.granted;
    final needsAlarm = ready.value && !nightlyStatus.exactAllowed;
    final failure =
        error.value ??
        (status.enabled && (status.failed || nightlyStatus.failed)
            ? l10n.calendarSyncFailed
            : null);
    final summaryTitle = syncing
        ? l10n.calendarSyncBusy
        : clearing
        ? l10n.calendarSyncClearing
        : failure ??
              (!status.enabled
                  ? l10n.calendarSyncOff
                  : needsCalendar
                  ? l10n.calendarSyncCalendarNeeded
                  : pendingChanges.value
                  ? l10n.calendarSyncPending
                  : status.lastSuccess != null
                  ? l10n.calendarSyncLastSuccess
                  : l10n.calendarSyncNever);
    final reminderText = status.reminder == 0
        ? l10n.calendarExportNoReminder
        : l10n.calendarExportReminderMinutes(status.reminder);
    final canEdit = ready.value && !working;
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.calendarSync),
        actions: [
          IconButton(
            tooltip: l10n.calendarSyncHelp,
            icon: const Icon(Icons.help_outline),
            onPressed: working
                ? null
                : () => unawaited(
                    showChoice<void>(
                      () => showAppBottomSheet<void>(
                        context: context,
                        builder: (_) => Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.calendarSyncHelp,
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              Text(l10n.calendarSyncScope),
                              const SizedBox(height: 12),
                              Text(l10n.calendarSyncRecurrenceHint),
                              const SizedBox(height: 12),
                              Text(l10n.calendarSyncPauseHelp),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: AppListView(
        controller: scroll,
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          SettingsSection(
            title: l10n.settingsSyncStatusSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingSwitchTile.controlled(
                  key: const Key('calendar-sync-enabled'),
                  title: Text(l10n.calendarSyncEnabled),
                  subtitle: Text(
                    status.enabled
                        ? l10n.calendarSyncPausedHint
                        : l10n.calendarSyncStartHint,
                  ),
                  value: status.enabled,
                  onChanged: canEdit
                      ? (value) => unawaited(setEnabled(value))
                      : null,
                ),
                if (operation.value == _Operation.loading ||
                    operation.value == _Operation.saving ||
                    operation.value == _Operation.permission)
                  LinearProgressIndicator(
                    semanticsLabel: operation.value == _Operation.saving
                        ? l10n.calendarSyncSaving
                        : l10n.reminderPermissionLoading,
                  ),
                if (ready.value || failure != null) ...[
                  const AppDivider(height: 1, indent: 16, endIndent: 16),
                  SettingsStatus(
                    title: summaryTitle,
                    isError: failure != null,
                    details: [
                      if (status.lastSuccess != null) ...[
                        dateTime(status.lastSuccess!),
                        l10n.calendarSyncOccurrences(status.count),
                        if (status.enabled && !pendingChanges.value)
                          status.inserted + status.updated + status.deleted == 0
                              ? l10n.calendarSyncNoChanges
                              : l10n.calendarSyncResult(
                                  status.inserted,
                                  status.updated,
                                  status.deleted,
                                ),
                      ],
                      if (!status.enabled && status.lastSuccess != null)
                        l10n.calendarSyncPausedHint,
                    ],
                    action:
                        status.enabled ||
                            !ready.value ||
                            (failure != null && needsCalendar)
                        ? SettingsActionButton(
                            key: const Key('calendar-sync-now'),
                            busy: syncing,
                            onPressed: working
                                ? null
                                : !ready.value
                                ? () => unawaited(reload())
                                : needsCalendar
                                ? () => unawaited(calendarPermission())
                                : status.enabled
                                ? syncNow
                                : null,
                            icon: needsCalendar
                                ? Icons.lock_open_outlined
                                : Icons.sync,
                            label: syncing
                                ? l10n.calendarSyncBusy
                                : !ready.value
                                ? l10n.retry
                                : needsCalendar
                                ? l10n.calendarSyncGrantCalendar
                                : failure != null
                                ? l10n.retry
                                : l10n.calendarSyncNow,
                          )
                        : null,
                    footer: status.enabled && needsAlarm
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.calendarSyncAlarmHint,
                                style: detailStyle,
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton(
                                  onPressed: working
                                      ? null
                                      : () => unawaited(alarmPermission()),
                                  child: Text(l10n.calendarSyncGrantAlarm),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
          SettingsSection.list(
            title: l10n.settingsSyncSection,
            children: [
              ChevronListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(l10n.calendarSyncTime),
                subtitle: Text(
                  '${l10n.reminderBeijingTime(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context))}\n'
                  '${l10n.calendarSyncSharedTime}',
                ),
                onTap: canEdit ? chooseTime : null,
              ),
              SettingSwitchTile.controlled(
                secondary: const Icon(Icons.event_note_outlined),
                title: Text(l10n.calendarExportIncludeExams),
                value: status.includeExams,
                onChanged: canEdit
                    ? (value) => unawaited(saveOptions(includeExams: value))
                    : null,
              ),
              ChevronListTile(
                key: const Key('calendar-sync-reminder'),
                leading: const Icon(Icons.notifications_none_outlined),
                title: Text(l10n.calendarExportReminder),
                subtitle: Text(reminderText),
                onTap: canEdit ? chooseReminder : null,
              ),
            ],
          ),
          const SettingsDivider(),
          SettingsSection.list(
            title: l10n.settingsPermissionsSection,
            children: [
              SettingsPermissionTile(
                title: l10n.calendarSyncPermission,
                purpose: l10n.calendarSyncCalendarPurpose,
                granted: ready.value ? status.granted : null,
                onTap: canEdit ? calendarPermission : null,
              ),
              SettingsPermissionTile(
                title: l10n.reminderExactPermission,
                purpose: l10n.calendarSyncAlarmPurpose,
                granted: ready.value ? nightlyStatus.exactAllowed : null,
                onTap: canEdit ? alarmPermission : null,
              ),
            ],
          ),
          const SettingsDivider(),
          SettingsSection(
            title: l10n.settingsDataSection,
            child: SettingsActionTile(
              key: const Key('calendar-sync-clear'),
              busy: clearing,
              destructive: true,
              icon: Icons.delete_outline,
              title: clearing
                  ? l10n.calendarSyncClearing
                  : l10n.calendarSyncClear,
              subtitle: l10n.calendarSyncClearSummary,
              onTap: canEdit ? clearAll : null,
            ),
          ),
        ],
      ),
    );
  }
}
