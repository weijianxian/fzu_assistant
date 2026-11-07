import 'package:flutter/material.dart';
import 'package:fzu_assistant/service/calendar_sync_service.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';

class SettingsPage extends HookWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final device = useFuture(
      useMemoized(() => CourseReminderService.instance.isXiaomiDevice()),
    );

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: AppListView(
        children: [
          SettingsSection.list(
            title: l10n.settingsAppSection,
            children: [
              ChevronListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(l10n.homeSettings),
                subtitle: Text(l10n.homeSettingsSubtitle),
                onTap: () => context.pushNamed(AppRoutes.homeSettings),
              ),
              ChevronListTile(
                leading: const Icon(Icons.tune),
                title: Text(l10n.generalSettings),
                subtitle: Text(l10n.generalSettingsSubtitle),
                onTap: () => context.pushNamed(AppRoutes.generalSettings),
              ),
              ChevronListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(l10n.themeSettings),
                subtitle: Text(l10n.themeSettingsSubtitle),
                onTap: () => context.pushNamed(AppRoutes.themeSettings),
              ),
              ChevronListTile(
                leading: const Icon(Icons.settings_ethernet),
                title: Text(l10n.advancedSettings),
                subtitle: Text(l10n.advancedSettingsSubtitle),
                onTap: () => context.pushNamed(AppRoutes.advancedSettings),
              ),
              ChevronListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(l10n.thirdPartyServices),
                subtitle: Text(l10n.thirdPartyDescription),
                onTap: () => context.pushNamed(AppRoutes.thirdPartySettings),
              ),
              ChevronListTile(
                leading: const Icon(Icons.sync),
                title: Text(l10n.webdavSync),
                subtitle: Text(l10n.webdavDescription),
                onTap: () => context.pushNamed(AppRoutes.webDavSettings),
              ),
            ],
          ),
          if (CourseReminderService.supported) const SettingsDivider(),
          if (CourseReminderService.supported) ...[
            SettingsSection.list(
              title: l10n.settingsPlatformSection,
              children: [
                ChevronListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: Text(l10n.permissionManagement),
                  subtitle: Text(l10n.permissionManagementSubtitle),
                  onTap: () => context.pushNamed(AppRoutes.androidPermissions),
                ),
                ChevronListTile(
                  leading: const Icon(Icons.sync),
                  title: Text(l10n.scheduleSync),
                  subtitle: Text(l10n.scheduleSyncDescription),
                  onTap: () =>
                      context.pushNamed(AppRoutes.scheduleSyncSettings),
                ),
                if (CalendarSyncService.supported)
                  ChevronListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(l10n.calendarSync),
                    subtitle: Text(l10n.calendarSyncDescription),
                    onTap: () => context.pushNamed(AppRoutes.calendarExport),
                  ),
                ChevronListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(l10n.courseReminderSettings),
                  subtitle: Text(
                    device.data == true
                        ? l10n.reminderXiaomiNotice
                        : l10n.courseReminderSettingsSubtitle,
                  ),
                  onTap: () =>
                      context.pushNamed(AppRoutes.courseReminderSettings),
                ),
                ChevronListTile(
                  leading: const Icon(Icons.widgets_outlined),
                  title: Text(l10n.nextCourseWidgetSettings),
                  subtitle: Text(l10n.nextCourseWidgetDescription),
                  onTap: () =>
                      context.pushNamed(AppRoutes.nextCourseWidgetSettings),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
