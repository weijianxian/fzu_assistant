import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/windows_course_notifications.dart';

/// Windows uses standard toasts while the existing application stays running.
/// It does not expose Android permission, alarm or promoted-ongoing controls.
class WindowsNotificationsSettingsPage extends HookWidget {
  const WindowsNotificationsSettingsPage({
    super.key,
    this.notifications,
    this.liveUpdates = false,
  });

  final WindowsCourseNotifications? notifications;
  final bool liveUpdates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = AppSettingsProvider.of(context);
    final notifications =
        this.notifications ?? WindowsCourseNotifications.instance;
    final enabled = useValueListenable(
      liveUpdates
          ? settings.courseLiveUpdatesEnabled
          : settings.courseReminderEnabled,
    );
    final minutes = useValueListenable(settings.courseReminderMinutes);
    final error = useValueListenable(notifications.error);
    final next = useValueListenable(notifications.nextReminder);
    final busy = useState(false);
    final actionFailed = useState(false);
    Future<void> run(Future<void> Function() action) async {
      if (busy.value) return;
      busy.value = true;
      actionFailed.value = false;
      try {
        await action();
      } catch (_) {
        if (context.mounted) actionFailed.value = true;
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    useEffect(() {
      unawaited(notifications.synchronize(settings));
      return null;
    }, [settings]);

    final nextBeijing = next?.toUtc().add(const Duration(hours: 8));
    final nextText = nextBeijing == null
        ? null
        : '${nextBeijing.year}-${nextBeijing.month.toString().padLeft(2, '0')}-'
              '${nextBeijing.day.toString().padLeft(2, '0')} '
              '${nextBeijing.hour.toString().padLeft(2, '0')}:'
              '${nextBeijing.minute.toString().padLeft(2, '0')} (UTC+8)';

    return AppScaffold(
      appBar: AppBar(
        title: Text(
          liveUpdates ? l10n.courseLiveUpdates : l10n.courseReminderSettings,
        ),
      ),
      body: AppListView(
        children: [
          AppInfoCard(
            title: Text(l10n.windowsNotificationsHelp),
            subtitle: Text(l10n.windowsNotificationsSystemHint),
          ),
          SettingsSection.list(
            title: liveUpdates ? null : l10n.settingsReminderSection,
            children: [
              if (!liveUpdates) ...[
                SettingSwitchTile.controlled(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: Text(l10n.courseReminderTitle),
                  subtitle: Text(l10n.courseReminderDescription),
                  value: enabled,
                  onChanged: busy.value
                      ? null
                      : (value) => run(() async {
                          settings.courseReminderEnabled.value = value;
                          await notifications.synchronize(settings);
                        }),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(l10n.reminderTime),
                  subtitle: Text(
                    l10n.reminderBeijingTime(
                      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
                      '${(minutes % 60).toString().padLeft(2, '0')}',
                    ),
                  ),
                  onTap: busy.value
                      ? null
                      : () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: minutes ~/ 60,
                              minute: minutes % 60,
                            ),
                          );
                          if (time == null || !context.mounted) return;
                          await run(() async {
                            settings.courseReminderMinutes.value =
                                time.hour * 60 + time.minute;
                            await notifications.synchronize(settings);
                          });
                        },
                ),
                if (nextText != null)
                  ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(l10n.windowsNotificationsNext),
                    subtitle: Text(nextText),
                  ),
              ] else
                SettingSwitchTile.controlled(
                  secondary: const Icon(Icons.school_outlined),
                  title: Text(l10n.windowsCourseStages),
                  subtitle: Text(l10n.windowsCourseStagesDescription),
                  value: enabled,
                  onChanged: busy.value
                      ? null
                      : (value) => run(() async {
                          await settings.setCourseLiveUpdatesEnabled(value);
                          await notifications.synchronize(settings);
                        }),
                ),
            ],
          ),
          const SettingsDivider(),
          SettingsSection.list(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(l10n.windowsNotificationsSystemSettings),
                trailing: const Icon(Icons.open_in_new),
                onTap: busy.value
                    ? null
                    : () => run(notifications.openSettings),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.windowsNotificationsRefresh),
                onTap: busy.value
                    ? null
                    : () => run(() => notifications.synchronize(settings)),
              ),
            ],
          ),
          if (error || actionFailed.value)
            ListTile(
              title: Text(
                liveUpdates
                    ? l10n.courseLiveUpdatesFailed
                    : l10n.reminderFailed,
              ),
              trailing: TextButton(
                onPressed: busy.value
                    ? null
                    : () => run(() => notifications.synchronize(settings)),
                child: Text(l10n.retry),
              ),
            ),
        ],
      ),
    );
  }
}
