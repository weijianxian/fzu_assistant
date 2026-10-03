import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/my/profile_page.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/api/api_client.dart';

class MyPage extends HookWidget {
  const MyPage({super.key, this.isActive = true});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = useMemoized(() => AuthStorage());

    Future<void> handleLogout() async {
      try {
        // 清理任务彼此独立，失败也不阻断回到登录页。
        await Future.wait([
          auth.clearCredentials(),
          ApiClient.instance.clearSession(),
        ]);
      } catch (_) {}
      if (context.mounted) {
        // 使用左栏的上下文，退出整个应用会话，而非右栏的详情导航。
        context.pushReplacementNamed(AppRoutes.login);
      }
    }

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
        icon: Icons.info_outline,
        title: l10n.about,
        route: AppRoutes.about,
      ),
      NavigationPaneDestination(
        icon: Icons.developer_board_outlined,
        title: l10n.devTools,
        route: AppRoutes.dev,
      ),
    ];
    final logout = ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
      onTap: handleLogout,
    );

    if (context.isLandscape) {
      return SplitNavigationPage(
        title: l10n.navMy,
        sections: [NavigationPaneSection(destinations: destinations)],
        initialRoute: AppRoutes.profile,
        onGenerateRoute: AppRouter.onGenerateRoute,
        isActive: isActive,
        footer: logout,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMy),
        actions: [
          IconButton(
            icon: const Icon(Icons.developer_board),
            tooltip: l10n.devTools,
            onPressed: () => context.pushNamed(AppRoutes.dev),
          ),
        ],
      ),
      body: ProfilePage(
        showAppBar: false,
        footer: Column(
          children: [
            const Divider(),
            for (final destination in destinations.skip(1).take(3))
              ChevronListTile(
                leading: Icon(destination.icon),
                title: Text(destination.title),
                onTap: () => context.pushNamed(destination.route),
              ),
            logout,
          ],
        ),
      ),
    );
  }
}
