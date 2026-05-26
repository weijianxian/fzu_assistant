import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/settings/permission_settings_page.dart';
import 'package:fzu_assistant/service/notification_service.dart';

class NotificationDebugPage extends HookWidget {
  const NotificationDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final alarmStatus = useState<String?>(null);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Debug')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Permission Management'),
            subtitle: const Text(
              'Check notification & exact alarm permissions',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(const PermissionSettingsPage()),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.access_time, color: Colors.orange),
            title: const Text('AlarmManager'),
            subtitle: Text(alarmStatus.value ?? 'Fire in 5 seconds'),
            trailing: FilledButton.tonal(
              onPressed: () async {
                final when = DateTime.now().add(const Duration(seconds: 5));
                final ok = await NotificationService.scheduleViaAlarmManager(
                  id: 1001,
                  when: when,
                );
                alarmStatus.value = ok
                    ? 'Scheduled → ${when.hour}:${when.minute.toString().padLeft(2, '0')}'
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
                await NotificationService.showNow(
                  id: 9999,
                  title: 'Test Notification',
                  body: 'If you see this, notifications are working',
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
