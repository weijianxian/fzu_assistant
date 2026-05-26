import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_permission.dart';
import 'package:fzu_assistant/constants/time_slots.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/settings/permission_settings_page.dart';
import 'package:fzu_assistant/service/early_class_reminder_service.dart';
import 'package:permission_handler/permission_handler.dart';

class EarlyClassReminderSettingsPage extends HookWidget {
  const EarlyClassReminderSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = useState(EarlyClassReminderService.isEnabled);
    final minutes = useState(EarlyClassReminderService.minutesBefore);
    final skipWeekend = useState(EarlyClassReminderService.skipWeekend);
    final notifPerm = usePermission(Permission.notification);
    final exactPerm = usePermission(Permission.scheduleExactAlarm);

    final now = DateTime.now();
    final weekdays = [
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
      l10n.sunday,
    ];
    final scheme = Theme.of(context).colorScheme;

    Future<bool> ensurePermissions() async {
      var notifOk = notifPerm.value?.isGranted ?? false;
      var exactOk = exactPerm.value?.isGranted ?? false;

      if (!notifOk) {
        final s = await requestPermission(notifPerm, Permission.notification);
        notifOk = s.isGranted;
      }
      if (!exactOk) {
        final s = await requestPermission(
          exactPerm,
          Permission.scheduleExactAlarm,
        );
        exactOk = s.isGranted;
      }

      if (!notifOk || !exactOk) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.permissionManagementSubtitle),
              action: SnackBarAction(
                label: l10n.settings,
                onPressed: () => context.push(const PermissionSettingsPage()),
              ),
            ),
          );
        }
        return false;
      }
      return true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.earlyClassReminder)),
      body: ListView(
        children: [
          // 权限状态提示
          if (!(notifPerm.value?.isGranted ?? false) ||
              !(exactPerm.value?.isGranted ?? false))
            ListTile(
              leading: Icon(Icons.warning_amber, color: scheme.error),
              title: Text(l10n.permissionManagement),
              subtitle: Text(l10n.permissionManagementSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(const PermissionSettingsPage()),
            ),
          SwitchListTile(
            title: Text(l10n.earlyClassReminderEnable),
            subtitle: Text(l10n.earlyClassReminderEnableDesc),
            value: enabled.value,
            onChanged: (v) async {
              if (v) {
                final ok = await ensurePermissions();
                if (!ok) return;
              }
              await EarlyClassReminderService.setEnabled(v);
              enabled.value = v;
            },
          ),
          ListTile(
            title: Text(l10n.earlyClassReminderMinutes(minutes.value)),
            subtitle: Slider(
              min: 0,
              max: 20,
              divisions: 20,
              value: minutes.value.toDouble(),
              label: '${minutes.value}',
              onChanged: enabled.value
                  ? (v) {
                      minutes.value = v.round();
                      EarlyClassReminderService.setMinutesBefore(v.round());
                    }
                  : null,
            ),
          ),
          SwitchListTile(
            title: Text(l10n.earlyClassReminderSkipWeekend),
            subtitle: Text(l10n.earlyClassReminderSkipWeekendDesc),
            value: skipWeekend.value,
            onChanged: enabled.value
                ? (v) async {
                    await EarlyClassReminderService.setSkipWeekend(v);
                    skipWeekend.value = v;
                  }
                : null,
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.earlyClassReminderScheduled),
            trailing: FilledButton.tonal(
              onPressed: () async {
                await EarlyClassReminderService.scheduleForWeek();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.earlyClassReminderRescheduled)),
                  );
                }
              },
              child: Text(l10n.earlyClassReminderReschedule),
            ),
          ),
          for (var i = 0; i < 7; i++)
            _AlarmTile(
              weekday: i + 1,
              label: weekdays[i],
              now: now,
              isToday: i + 1 == now.weekday,
              color: scheme.primary,
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.earlyClassReminderAlarmInfo(
                minutes.value,
                timeSlots.last.$2,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmTile extends StatelessWidget {
  final int weekday;
  final String label;
  final DateTime now;
  final bool isToday;
  final Color color;

  const _AlarmTile({
    required this.weekday,
    required this.label,
    required this.now,
    required this.isToday,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final daysToAdd = weekday - now.weekday;
    final date = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysToAdd <= 0 ? daysToAdd + 7 : daysToAdd));

    return ListTile(
      leading: Icon(
        isToday ? Icons.today : Icons.calendar_today,
        color: isToday ? color : null,
      ),
      title: Text('$label (${date.month}/${date.day})'),
      subtitle: Text('ID: ${3000 + weekday}'),
      dense: true,
    );
  }
}
