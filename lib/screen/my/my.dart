import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/my/profile_page.dart';

class MyPage extends HookWidget {
  const MyPage({super.key, this.isActive = true});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final destinations = [
      NavigationPaneDestination(
        icon: Icons.person_outline,
        title: l10n.profileInfo,
        route: AppRoutes.profile,
      ),
      NavigationPaneDestination(
        icon: Icons.calendar_month_outlined,
        title: l10n.calendar,
        route: AppRoutes.calendar,
      ),
      NavigationPaneDestination(
        icon: Icons.settings_outlined,
        title: l10n.settings,
        route: AppRoutes.settings,
      ),
      NavigationPaneDestination(
        icon: Icons.manage_accounts_outlined,
        title: l10n.accountManagement,
        route: AppRoutes.accountManagement,
      ),
      NavigationPaneDestination(
        icon: Icons.info_outline,
        title: l10n.about,
        route: AppRoutes.about,
      ),
    ];

    if (context.isLandscape) {
      return SplitNavigationPage(
        title: l10n.navMy,
        sections: [NavigationPaneSection(destinations: destinations)],
        initialRoute: AppRoutes.profile,
        onGenerateRoute: AppRouter.onGenerateRoute,
        isActive: isActive,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMy)),
      body: ProfilePage(
        showAppBar: false,
        footer: Column(
          children: [
            const Divider(),
            for (final destination in destinations.skip(1))
              ChevronListTile(
                leading: Icon(destination.icon),
                title: Text(destination.title),
                onTap: () => context.pushNamed(destination.route),
              ),
          ],
        ),
      ),
    );
  }
}
