import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_permission.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/settings/permission_settings_page.dart';
import 'package:fzu_assistant/service/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationDebugPage extends HookWidget {
  const NotificationDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final alarmStatus = useState<String?>(null);
    final notifPerm = usePermission(Permission.notification);
    final exactPerm = usePermission(Permission.scheduleExactAlarm);

    void showPermDenied() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permission not granted'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => context.push(const PermissionSettingsPage()),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Debug')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Permission Status'),
            subtitle: Text(
              (notifPerm.value?.isGranted ?? false) &&
                      (exactPerm.value?.isGranted ?? false)
                  ? 'All permissions granted'
                  : 'Missing permissions — tap to check',
            ),
            trailing:
                (notifPerm.value?.isGranted ?? false) &&
                    (exactPerm.value?.isGranted ?? false)
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.chevron_right),
            onTap: () => context.push(const PermissionSettingsPage()),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.access_time, color: Colors.orange),
            title: const Text('AlarmManager'),
            subtitle: Text(alarmStatus.value ?? 'Fire in 5 seconds'),
            trailing: FilledButton.tonal(
              onPressed: () async {
                if (!(exactPerm.value?.isGranted ?? false)) {
                  showPermDenied();
                  return;
                }
                final when = DateTime.now().add(const Duration(seconds: 5));
                final ok = await NotificationService.scheduleViaAlarmManager(
                  id: 1001,
                  when: when,
                );
                alarmStatus.value = ok
                    ? 'A notification should appear at ${when.toLocal()}'
                    : 'Failed';
              },
              child: const Text('Schedule'),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Send test notification'),
            trailing: FilledButton(
              onPressed: () async {
                if (!(notifPerm.value?.isGranted ?? false)) {
                  showPermDenied();
                  return;
                }
                await NotificationService.showNow(
                  id: 9999,
                  title: 'Test Notification',
                  body: 'This is a test notification.',
                );
              },
              child: const Text('Send'),
            ),
          ),
        ],
      ),
    );
  }
}
