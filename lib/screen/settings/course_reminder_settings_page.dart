import 'dart:async';

import 'package:fzu_assistant/common/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class CourseReminderSettingsPage extends HookWidget {
  const CourseReminderSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = AppSettingsProvider.of(context);
    final reminder = CourseReminderService.instance;
    final permissions = useState<Map<String, bool>?>(null);
    final failed = useState(false);
    final busy = useState(false);
    final isXiaomi = useState<bool?>(null);
    final enabled = useValueListenable(settings.courseReminderEnabled);
    final minutes = useValueListenable(settings.courseReminderMinutes);
    final syncError = useValueListenable(reminder.error);

    Future<void> reload() async {
      if (!CourseReminderService.supported) return;
      try {
        final result = await reminder.permissions();
        if (context.mounted) {
          permissions.value = result;
          failed.value = false;
        }
      } catch (_) {
        if (context.mounted) failed.value = true;
      }
    }

    Future<void> loadDeviceHint() async {
      if (!CourseReminderService.supported) return;
      try {
        final xiaomi = await reminder.isXiaomiDevice();
        if (context.mounted) isXiaomi.value = xiaomi;
      } catch (_) {
        // Device information only controls the advisory, never the feature.
      }
    }

    Future<void> run(Future<void> Function() action) async {
      busy.value = true;
      try {
        await action();
      } catch (_) {
        if (context.mounted) failed.value = true;
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    useEffect(() {
      unawaited(reload());
      unawaited(loadDeviceHint());
      return null;
    }, []);
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) {
        unawaited(reload());
        unawaited(loadDeviceHint());
      }
    });
    final ready =
        permissions.value?['notifications'] == true &&
        permissions.value?['exact'] == true;

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.courseReminderSettings)),
      body: AppListView(
        children: [
          if (isXiaomi.value == true)
            AppInfoCard(
              title: Text(l10n.reminderXiaomiNotice),
              subtitle: Text(l10n.reminderXiaomiDescription),
            ),
          SettingsSection.list(
            title: l10n.settingsReminderSection,
            children: [
              SettingSwitchTile.controlled(
                title: Text(l10n.courseReminderTitle),
                subtitle: Text(l10n.courseReminderDescription),
                value: enabled,
                onChanged: busy.value
                    ? null
                    : (value) => run(() async {
                        if (value && !ready) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.reminderPermissionsRequired),
                            ),
                          );
                          return;
                        }
                        settings.courseReminderEnabled.value = value;
                        await reminder.sync(settings);
                      }),
              ),
              ListTile(
                title: Text(l10n.reminderTime),
                subtitle: Text(
                  l10n.reminderBeijingTime(
                    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
                  ),
                ),
                trailing: const Icon(Icons.schedule),
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
                          await reminder.sync(settings);
                        });
                      },
              ),
            ],
          ),
          const SettingsDivider(),
          SettingsSection.list(
            title: l10n.settingsPermissionsSection,
            children: [
              SettingsPermissionTile(
                title: l10n.reminderNotificationPermission,
                granted: permissions.value?['notifications'],
                onTap: busy.value
                    ? null
                    : () => run(() async {
                        await reminder.requestPermission(
                          'requestNotifications',
                        );
                        await reload();
                        await reminder.sync(settings);
                      }),
              ),
              SettingsPermissionTile(
                title: l10n.reminderExactPermission,
                granted: permissions.value?['exact'],
                onTap: busy.value
                    ? null
                    : () =>
                          run(() => reminder.requestPermission('requestExact')),
              ),
              ListTile(
                title: Text(l10n.reminderNotificationStyle),
                subtitle: Text(l10n.reminderNotificationStyleDescription),
                trailing: const Icon(Icons.open_in_new),
                onTap: busy.value
                    ? null
                    : () => run(
                        () => reminder.requestPermission(
                          'openNotificationChannel',
                        ),
                      ),
              ),
            ],
          ),
          if (failed.value || syncError)
            ListTile(
              title: Text(l10n.reminderFailed),
              trailing: TextButton(
                onPressed: () => run(() async {
                  await reload();
                  await reminder.sync(settings);
                }),
                child: Text(l10n.retry),
              ),
            ),
        ],
      ),
    );
  }
}
