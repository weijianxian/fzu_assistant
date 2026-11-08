import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/android_permissions_service.dart';
import 'package:fzu_assistant/service/course_live_update_service.dart';
import 'package:fzu_assistant/service/course_live_updates_controller.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class CourseLiveUpdatesSettingsPage extends HookWidget {
  const CourseLiveUpdatesSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = AppSettingsProvider.of(context);
    final enabled = useValueListenable(settings.courseLiveUpdatesEnabled);
    final failed = useValueListenable(CourseLiveUpdatesController.error);
    final permissions = useState<Map<String, bool>?>(null);
    final promoted = useState<bool?>(null);
    final busy = useState(false);
    final operationFailed = useState(false);

    Future<void> reload() async {
      final status = await CourseReminderService.instance.permissions();
      final promotion = await CourseLiveUpdateService.promotionEnabled();
      if (!context.mounted) return;
      permissions.value = status;
      promoted.value = promotion;
    }

    Future<void> run(Future<void> Function() action) async {
      if (busy.value) return;
      busy.value = true;
      try {
        await action();
        if (context.mounted) operationFailed.value = false;
      } catch (_) {
        if (context.mounted) operationFailed.value = true;
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    useEffect(() {
      unawaited(run(reload));
      return null;
    }, []);
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) {
        unawaited(
          run(() async {
            await reload();
            await CourseLiveUpdatesController.synchronize();
          }),
        );
      }
    });
    final ready =
        permissions.value?['notifications'] == true &&
        permissions.value?['exact'] == true;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.courseLiveUpdates)),
      body: AppListView(
        children: [
          AppInfoCard(
            title: Text(l10n.courseLiveUpdatesDescription),
            subtitle: Text(l10n.courseLiveUpdatesRule),
          ),
          SettingsSection.list(
            children: [
              SettingSwitchTile.controlled(
                title: Text(l10n.courseLiveUpdatesEnabled),
                subtitle: Text(l10n.courseLiveUpdatesSubtitle),
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
                        await settings.setCourseLiveUpdatesEnabled(value);
                        await CourseLiveUpdatesController.synchronize();
                      }),
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
                        await AndroidPermissionsService.openSettings(
                          'android.permission.POST_NOTIFICATIONS',
                        );
                        await reload();
                      }),
              ),
              SettingsPermissionTile(
                title: l10n.reminderExactPermission,
                granted: permissions.value?['exact'],
                onTap: busy.value
                    ? null
                    : () => run(
                        () => CourseReminderService.instance.requestPermission(
                          'requestExact',
                        ),
                      ),
              ),
              SettingsPermissionTile(
                title: l10n.permissionNameLiveUpdates,
                granted: promoted.value,
                onTap: busy.value
                    ? null
                    : () => run(CourseLiveUpdateService.openSettings),
              ),
            ],
          ),
          if (failed || operationFailed.value)
            ListTile(
              title: Text(l10n.courseLiveUpdatesFailed),
              trailing: TextButton(
                onPressed: busy.value
                    ? null
                    : () => run(() async {
                        await reload();
                        await CourseLiveUpdatesController.synchronize();
                      }),
                child: Text(l10n.retry),
              ),
            ),
        ],
      ),
    );
  }
}
