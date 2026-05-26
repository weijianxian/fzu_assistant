import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_permission.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionSettingsPage extends HookWidget {
  const PermissionSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notifPerm = usePermission(Permission.notification);
    final exactPerm = usePermission(Permission.scheduleExactAlarm);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.permissionManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await refreshPermissionFromStatus(
                notifPerm,
                Permission.notification,
              );
              await refreshPermissionFromStatus(
                exactPerm,
                Permission.scheduleExactAlarm,
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _PermTile(
            icon: Icons.notifications_outlined,
            title: l10n.notificationPermission,
            description: l10n.notificationPermissionDesc,
            granted: notifPerm.value?.isGranted ?? false,
            onTap: () => requestPermission(notifPerm, Permission.notification),
          ),
          _PermTile(
            icon: Icons.alarm_outlined,
            title: l10n.exactAlarmPermission,
            description: l10n.exactAlarmPermissionDesc,
            granted: exactPerm.value?.isGranted ?? false,
            onTap: () =>
                requestPermission(exactPerm, Permission.scheduleExactAlarm),
          ),
        ],
      ),
    );
  }
}

/// 刷新权限状态（不弹系统弹窗）
Future<void> refreshPermissionFromStatus(
  ValueNotifier<PermissionStatus?> state,
  Permission permission,
) async {
  state.value = await permission.status;
}

class _PermTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool granted;
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
      trailing: granted
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
