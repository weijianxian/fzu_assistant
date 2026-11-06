import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/service/calendar_sync_service.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';

class CalendarSyncSettingsPage extends HookWidget {
  const CalendarSyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = CalendarSyncService.instance;
    final nightly = WidgetSyncService.instance;
    final status = useValueListenable(service.status);
    final nightlyStatus = useValueListenable(nightly.status);
    final minutes = useValueListenable(nightly.minutes);
    final busy = useState(false);
    final loaded = useState(false);
    final error = useState<String?>(null);
    final working = busy.value || nightlyStatus.running;

    Future<void> reload() async {
      try {
        await service.load();
        await nightly.reconcile();
        if (context.mounted) loaded.value = true;
      } catch (failure) {
        if (context.mounted) {
          error.value = l10n.loadingFailed(failure.toString());
        }
      }
    }

    Future<void> run(Future<void> Function() action) async {
      if (working) return;
      busy.value = true;
      error.value = null;
      try {
        await action();
      } catch (failure) {
        if (context.mounted) {
          error.value = l10n.loadingFailed(failure.toString());
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    Future<void> sync() async {
      if (!await service.syncNow() && context.mounted) {
        error.value = l10n.calendarSyncFailed;
      }
    }

    Future<void> clearAll() async {
      final confirmed = await showDialog<bool>(
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.calendarSyncClear),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await run(() async {
        if (!status.granted && !await service.requestPermission()) {
          if (context.mounted) {
            error.value = l10n.calendarSyncPermissionRequired;
          }
          return;
        }
        try {
          await service.clearAll();
        } catch (_) {
          if (context.mounted) error.value = l10n.calendarSyncClearFailed;
          return;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.calendarSyncCleared)));
        }
      });
    }

    useEffect(() {
      unawaited(reload());
      return null;
    }, []);
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) unawaited(reload());
    });
    String beijingTime(DateTime instant) {
      final time = instant.toUtc().add(const Duration(hours: 8));
      return l10n.reminderBeijingTime(
        '${MaterialLocalizations.of(context).formatMediumDate(time)} '
        '${TimeOfDay.fromDateTime(time).format(context)}',
      );
    }

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.calendarSync)),
      body: AppListView(
        children: [
          ListTile(
            title: Text(l10n.calendarSyncDescription),
            subtitle: Text(l10n.calendarSyncScope),
          ),
          if (!loaded.value) const LinearProgressIndicator(),
          SwitchListTile(
            title: Text(l10n.calendarSyncEnabled),
            subtitle: Text(l10n.calendarSyncPausedHint),
            value: status.enabled,
            onChanged: !loaded.value || working
                ? null
                : (enabled) => run(() async {
                    if (enabled &&
                        !status.granted &&
                        !await service.requestPermission()) {
                      if (context.mounted) {
                        error.value = l10n.calendarSyncPermissionRequired;
                      }
                      return;
                    }
                    await service.configure(enabled: enabled);
                    if (enabled) await sync();
                  }),
          ),
          ListTile(
            title: Text(l10n.calendarSyncPermission),
            subtitle: Text(
              !loaded.value
                  ? l10n.reminderPermissionLoading
                  : status.granted
                  ? l10n.reminderPermissionGranted
                  : l10n.reminderPermissionDenied,
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: working
                ? null
                : () => run(() async {
                    if (!await service.requestPermission()) {
                      await AndroidPermissionsService.openSettings(
                        'android.permission.WRITE_CALENDAR',
                      );
                    }
                  }),
          ),
          ListTile(
            title: Text(l10n.reminderExactPermission),
            subtitle: Text(
              !loaded.value
                  ? l10n.reminderPermissionLoading
                  : nightlyStatus.exactAllowed
                  ? l10n.reminderPermissionGranted
                  : l10n.reminderPermissionDenied,
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: working ? null : () => run(nightly.requestExactPermission),
          ),
          ListTile(
            title: Text(l10n.calendarSyncTime),
            subtitle: Text(
              l10n.reminderBeijingTime(
                TimeOfDay(
                  hour: minutes ~/ 60,
                  minute: minutes % 60,
                ).format(context),
              ),
            ),
            trailing: const Icon(Icons.schedule),
            onTap: !loaded.value || working || !status.enabled
                ? null
                : () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: minutes ~/ 60,
                        minute: minutes % 60,
                      ),
                    );
                    if (selected == null || !context.mounted) return;
                    await run(
                      () => nightly.configure(
                        minutes: selected.hour * 60 + selected.minute,
                      ),
                    );
                  },
          ),
          SwitchListTile(
            title: Text(l10n.calendarExportIncludeExams),
            value: status.includeExams,
            onChanged: !loaded.value || working
                ? null
                : (value) => run(() => service.configure(includeExams: value)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<int>(
              key: ValueKey(status.reminder),
              initialValue: status.reminder,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.calendarExportReminder,
              ),
              items: [
                for (final value in [0, 5, 15, 30])
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == 0
                          ? l10n.calendarExportNoReminder
                          : l10n.calendarExportReminderMinutes(value),
                    ),
                  ),
              ],
              onChanged: !loaded.value || working
                  ? null
                  : (value) {
                      if (value != null) {
                        unawaited(
                          run(() => service.configure(reminder: value)),
                        );
                      }
                    },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: !loaded.value || working || !status.enabled
                  ? null
                  : () => run(sync),
              icon: working
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                working ? l10n.calendarSyncBusy : l10n.calendarSyncNow,
              ),
            ),
          ),
          ListTile(
            title: Text(l10n.calendarSyncLastSuccess),
            subtitle: Text(
              status.lastSuccess == null
                  ? l10n.widgetSyncNever
                  : beijingTime(status.lastSuccess!),
            ),
          ),
          if (status.lastSuccess != null)
            ListTile(
              title: Text(l10n.calendarExportEventCount(status.count)),
              subtitle: Text(
                l10n.calendarSyncResult(
                  status.inserted,
                  status.updated,
                  status.deleted,
                ),
              ),
            ),
          if (status.enabled && nightlyStatus.nextAt != null)
            ListTile(
              title: Text(l10n.widgetSyncNext),
              subtitle: Text(beijingTime(nightlyStatus.nextAt!)),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.calendarSyncClearHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: !loaded.value || working ? null : clearAll,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.calendarSyncClear),
            ),
          ),
          if (error.value != null || status.failed)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(error.value ?? l10n.calendarSyncFailed),
            ),
        ],
      ),
    );
  }
}
