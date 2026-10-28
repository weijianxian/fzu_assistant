import 'dart:async';

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
      return null;
    }, []);
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) unawaited(reload());
    });
    final ready =
        permissions.value?['notifications'] == true &&
        permissions.value?['exact'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.courseReminderSettings)),
      body: ListView(
        children: [
          SwitchListTile(
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
          ListTile(
            title: Text(l10n.reminderNotificationPermission),
            subtitle: Text(
              permissions.value == null
                  ? l10n.reminderPermissionLoading
                  : permissions.value!['notifications'] == true
                  ? l10n.reminderPermissionGranted
                  : l10n.reminderPermissionDenied,
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: busy.value
                ? null
                : () => run(() async {
                    await reminder.requestPermission('requestNotifications');
                    await reload();
                    await reminder.sync(settings);
                  }),
          ),
          ListTile(
            title: Text(l10n.reminderExactPermission),
            subtitle: Text(
              permissions.value == null
                  ? l10n.reminderPermissionLoading
                  : permissions.value!['exact'] == true
                  ? l10n.reminderPermissionGranted
                  : l10n.reminderPermissionDenied,
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: busy.value
                ? null
                : () => run(() => reminder.requestPermission('requestExact')),
          ),
          ListTile(
            title: Text(l10n.reminderNotificationStyle),
            subtitle: Text(l10n.reminderNotificationStyleDescription),
            trailing: const Icon(Icons.open_in_new),
            onTap: busy.value
                ? null
                : () => run(
                    () => reminder.requestPermission('openNotificationChannel'),
                  ),
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
