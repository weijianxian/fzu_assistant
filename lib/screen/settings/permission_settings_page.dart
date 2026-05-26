import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/notification_service.dart';

class PermissionSettingsPage extends HookWidget {
  const PermissionSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notifGranted = useState<bool?>(null);
    final exactGranted = useState<bool?>(null);

    AndroidFlutterLocalNotificationsPlugin? getAndroid() => NotificationService
        .plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    Future<void> checkAll() async {
      final android = getAndroid();
      if (android == null) return;
      notifGranted.value = await android.requestNotificationsPermission();
      exactGranted.value = await android.canScheduleExactNotifications();
    }

    useEffect(() {
      checkAll();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.permissionManagement),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: checkAll),
        ],
      ),
      body: ListView(
        children: [
          _PermTile(
            icon: Icons.notifications_outlined,
            title: l10n.notificationPermission,
            description: l10n.notificationPermissionDesc,
            granted: notifGranted.value,
            onTap: () async {
              final android = getAndroid();
              if (android == null || notifGranted.value == true) return;
              await android.requestNotificationsPermission();
              notifGranted.value = await android
                  .requestNotificationsPermission();
            },
          ),
          _PermTile(
            icon: Icons.alarm_outlined,
            title: l10n.exactAlarmPermission,
            description: l10n.exactAlarmPermissionDesc,
            granted: exactGranted.value,
            onTap: () async {
              final android = getAndroid();
              if (android == null || exactGranted.value == true) return;
              await android.requestExactAlarmsPermission();
              exactGranted.value = await android
                  .canScheduleExactNotifications();
            },
          ),
        ],
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool? granted;
  final VoidCallback onTap;

  const _PermTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(description),
      trailing: granted == true
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
