import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/layout/section.dart';

class NavigationPaneDestination {
  const NavigationPaneDestination({
    required this.icon,
    required this.title,
    required this.route,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String route;
  final String? subtitle;
}

class NavigationPaneSection {
  const NavigationPaneSection({required this.destinations, this.title});

  final String? title;
  final List<NavigationPaneDestination> destinations;
}

/// 左侧占 1/3、右侧占 2/3；详情页的后续导航始终留在右栏。
class SplitNavigationPage extends HookWidget {
  const SplitNavigationPage({
    super.key,
    required this.title,
    required this.sections,
    required this.initialRoute,
    required this.onGenerateRoute,
    this.footer,
    this.isActive = true,
  });

  final String title;
  final List<NavigationPaneSection> sections;
  final String initialRoute;
  final RouteFactory onGenerateRoute;
  final Widget? footer;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final selectedRoute = useState(initialRoute);
    final navigatorKey = useMemoized(() => GlobalKey<NavigatorState>(), [
      selectedRoute.value,
    ]);
    final heroController = useMemoized(
      MaterialApp.createMaterialHeroController,
      [selectedRoute.value],
    );
    final scheme = Theme.of(context).colorScheme;

    void selectDestination(String route) {
      if (route == selectedRoute.value) {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      } else {
        selectedRoute.value = route;
      }
    }

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Scaffold(
            backgroundColor: scheme.surfaceContainerLow,
            appBar: AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              backgroundColor: scheme.surfaceContainerLow,
            ),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                for (final section in sections)
                  if (section.title != null)
                    Section(
                      title: section.title!,
                      child: _destinations(
                        section.destinations,
                        selectedRoute.value,
                        selectDestination,
                      ),
                    )
                  else
                    _destinations(
                      section.destinations,
                      selectedRoute.value,
                      selectDestination,
                    ),
                if (footer != null) ...[const Divider(), footer!],
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          flex: 2,
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(size: constraints.biggest),
                child: HeroControllerScope(
                  controller: heroController,
                  child: NavigatorPopHandler<Object?>(
                    enabled: isActive,
                    onPopWithResult: (result) =>
                        navigatorKey.currentState!.pop(result),
                    child: Navigator(
                      key: navigatorKey,
                      initialRoute: selectedRoute.value,
                      onGenerateInitialRoutes: (_, route) => [
                        onGenerateRoute(RouteSettings(name: route))!,
                      ],
                      onGenerateRoute: onGenerateRoute,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _destinations(
    List<NavigationPaneDestination> destinations,
    String selectedRoute,
    ValueChanged<String> onSelected,
  ) => Column(
    children: [
      for (final destination in destinations)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Builder(
            builder: (context) {
              final scheme = Theme.of(context).colorScheme;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                horizontalTitleGap: 12,
                selected: selectedRoute == destination.route,
                selectedTileColor: scheme.secondaryContainer,
                selectedColor: scheme.onSecondaryContainer,
                leading: Icon(destination.icon),
                title: Text(destination.title),
                subtitle: destination.subtitle == null
                    ? null
                    : Text(
                        destination.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => onSelected(destination.route),
              );
            },
          ),
        ),
    ],
  );
}
