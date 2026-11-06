import 'dart:async';

import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';

class AndroidPermissionsPage extends HookWidget {
  const AndroidPermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = useAsyncData(AndroidPermissionsService.load);
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) unawaited(query.refresh());
    });
    Future<void> open([String? name]) async {
      try {
        await AndroidPermissionsService.openSettings(name);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.permissionSettingsFailed)),
          );
        }
      }
    }

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.permissionManagement),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: query.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: query.refresh,
        child: AppListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ListTile(
              title: Text(l10n.appPermissionSettings),
              subtitle: Text(l10n.permissionManagementDescription),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => open(),
            ),
            if (query.loading) const LinearProgressIndicator(),
            if (query.error != null)
              ListTile(
                title: Text(l10n.permissionLoadFailed),
                trailing: TextButton(
                  onPressed: query.refresh,
                  child: Text(l10n.retry),
                ),
              ),
            for (final permission in query.data ?? <AndroidAppPermission>[])
              ListTile(
                leading: Icon(
                  permission.granted ? Icons.check_circle_outline : Icons.block,
                  color: permission.granted
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(switch (permission.name) {
                  'android.permission.POST_NOTIFICATIONS' =>
                    l10n.permissionNameNotifications,
                  'android.permission.SCHEDULE_EXACT_ALARM' =>
                    l10n.permissionNameAlarms,
                  'android.permission.CAMERA' => l10n.permissionNameCamera,
                  'android.permission.READ_CALENDAR' =>
                    l10n.calendarSyncReadPermission,
                  'android.permission.WRITE_CALENDAR' =>
                    l10n.calendarSyncWritePermission,
                  'android.permission.REQUEST_INSTALL_PACKAGES' =>
                    l10n.permissionNameInstall,
                  'android.permission.INTERNET' => l10n.permissionNameInternet,
                  'android.permission.WAKE_LOCK' => l10n.permissionNameWake,
                  'android.permission.RECEIVE_BOOT_COMPLETED' =>
                    l10n.permissionNameBoot,
                  _ => l10n.permissionManagement,
                }),
                subtitle: Text(
                  '${switch (permission.name) {
                    'android.permission.POST_NOTIFICATIONS' => l10n.permissionPurposeNotifications,
                    'android.permission.SCHEDULE_EXACT_ALARM' => l10n.permissionPurposeAlarms,
                    'android.permission.CAMERA' => l10n.permissionPurposeCamera,
                    'android.permission.READ_CALENDAR' => l10n.calendarSyncReadPurpose,
                    'android.permission.WRITE_CALENDAR' => l10n.calendarSyncWritePurpose,
                    'android.permission.REQUEST_INSTALL_PACKAGES' => l10n.permissionPurposeInstall,
                    'android.permission.INTERNET' => l10n.permissionPurposeInternet,
                    'android.permission.WAKE_LOCK' => l10n.permissionPurposeWake,
                    'android.permission.RECEIVE_BOOT_COMPLETED' => l10n.permissionPurposeBoot,
                    _ => l10n.permissionManagementDescription,
                  }}\n${permission.granted ? l10n.permissionAllowed : l10n.permissionNotAllowed}',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => open(permission.name),
              ),
          ],
        ),
      ),
    );
  }
}
