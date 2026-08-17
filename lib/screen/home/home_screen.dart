import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/home/home_timeline_page.dart';
import 'package:fzu_assistant/screen/my/my.dart';
import 'package:fzu_assistant/screen/schedule/schedule.dart';
import 'package:fzu_assistant/screen/toolbox/toolbox.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class HomeScreen extends HookWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPage = useState(0);
    final jumpToWeekTrigger = useState(0);
    final refreshTimelineTrigger = useState(0);
    final l10n = AppLocalizations.of(context)!;
    final settings = AppSettingsProvider.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: settings.homeStyleKey,
      builder: (_, homeStyle, _) {
        final isTimeline = homeStyle == AppSettings.timelineHomeStyle;
        final pages = [
          if (isTimeline)
            TimelineHomePage(refreshTrigger: refreshTimelineTrigger)
          else
            SchedulePage(jumpToWeekTrigger: jumpToWeekTrigger),
          const ToolboxPage(),
          const MyPage(),
        ];

        void onTabTapped(int index) {
          if (index == currentPage.value && index == 0) {
            if (isTimeline) {
              refreshTimelineTrigger.value++;
            } else {
              jumpToWeekTrigger.value++;
            }
          } else {
            currentPage.value = index;
          }
        }

        final homeLabel = isTimeline ? l10n.navHome : l10n.navSchedule;
        return Scaffold(
          body: Row(
            children: [
              if (context.isLandscape)
                NavigationRail(
                  leading: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Hero(
                      tag: 'app-icon',
                      child: Image.asset(
                        'assets/icon/icon.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),
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
                      icon: const Icon(Icons.person),
                      label: Text(l10n.navMy),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(index: currentPage.value, children: pages),
              ),
            ],
          ),
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
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(Icons.person),
                      label: l10n.navMy,
                    ),
                  ],
                  onDestinationSelected: onTabTapped,
                ),
        );
      },
    );
  }
}
