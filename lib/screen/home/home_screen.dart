import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/my/my.dart';
import 'package:fzu_assistant/screen/schedule/schedule.dart';
import 'package:fzu_assistant/screen/toolbox/toolbox.dart';
import 'package:fzu_assistant/screen/campus_code/campus_code_page.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/app_top_banner.dart';

class HomeScreen extends HookWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPage = useState(0);
    final jumpToWeekTrigger = useState(0);
    final l10n = AppLocalizations.of(context)!;
    final settings = AppSettingsProvider.of(context);
    final api = ApiClient.instance;
    final cachedSession = useValueListenable(api.usingCachedSession);
    final reconnecting = useState(false);
    useEffect(() {
      if (!CourseReminderService.supported) return null;
      final inputs = <Listenable>[
        CacheHelper.changes,
        settings.courseReminderEnabled,
        settings.courseReminderMinutes,
        settings.autoAdjustCourse,
        settings.west2AdjustmentsAccess,
        settings.hiddenCourseSessions,
        settings.localeKey,
      ];
      void sync() => unawaited(CourseReminderService.instance.sync(settings));
      for (final input in inputs) {
        input.addListener(sync);
      }
      sync();
      return () {
        for (final input in inputs) {
          input.removeListener(sync);
        }
      };
    }, [settings]);
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) {
        unawaited(CourseReminderService.instance.sync(settings));
      }
    });

    final pages = [
      SchedulePage(jumpToWeekTrigger: jumpToWeekTrigger),
      ToolboxPage(isActive: currentPage.value == 1),
      CampusCodePage(isActive: currentPage.value == 2),
      MyPage(isActive: currentPage.value == 3),
    ];

    void onTabTapped(int index) {
      if (index == currentPage.value && index == 0) {
        jumpToWeekTrigger.value++;
      } else {
        currentPage.value = index;
      }
    }

    final homeLabel = l10n.navSchedule;
    return AppScaffold.shell(
      navigationRail: context.isLandscape
          ? NavigationRail(
              scrollable: true,
              groupAlignment: 0,
              selectedIndex: currentPage.value,
              onDestinationSelected: onTabTapped,
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.home),
                  label: Text(homeLabel),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.build),
                  label: Text(l10n.navToolbox),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.qr_code),
                  label: Text(l10n.campusCode),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.person),
                  label: Text(l10n.navMy),
                ),
              ],
            )
          : null,
      topBanner: cachedSession
          ? AppTopBanner(
              content: Text(l10n.academicCachedSession),
              actions: [
                TextButton(
                  onPressed: reconnecting.value
                      ? null
                      : () async {
                          reconnecting.value = true;
                          final ok = await api.refreshSession();
                          if (!context.mounted) return;
                          reconnecting.value = false;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.academicCachedSession),
                              ),
                            );
                          }
                        },
                  child: Text(l10n.retry),
                ),
              ],
            )
          : null,
      body: IndexedStack(index: currentPage.value, children: pages),
      bottomNavigationBar: context.isLandscape
          ? null
          : NavigationBar(
              selectedIndex: currentPage.value,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: homeLabel,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.build_outlined),
                  selectedIcon: const Icon(Icons.build),
                  label: l10n.navToolbox,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.qr_code),
                  selectedIcon: const Icon(Icons.qr_code_2),
                  label: l10n.campusCode,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: l10n.navMy,
                ),
              ],
              onDestinationSelected: onTabTapped,
            ),
    );
  }
}
