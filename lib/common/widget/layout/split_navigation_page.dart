import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/app_section.dart';
import 'package:fzu_assistant/service/app_themes.dart';

class NavigationPaneDestination {
  const NavigationPaneDestination({
    required this.icon,
    required this.title,
    required this.route,
    this.subtitle,
    this.menuTitle,
  });

  final IconData icon;
  final String title;
  final String route;
  final String? subtitle;
  final String? menuTitle;
}

class NavigationPaneSection {
  const NavigationPaneSection({required this.destinations, this.title});

  final String? title;
  final List<NavigationPaneDestination> destinations;
}

typedef NavigationPaneBuilder = Widget Function(
  BuildContext context,
  String selectedRoute,
  ValueChanged<String> onSelected,
);

/// 左侧占 1/3、右侧占 2/3；详情页的后续导航始终留在右栏。
class SplitNavigationPage extends HookWidget {
  const SplitNavigationPage({
    super.key,
    required this.title,
    required this.sections,
    required this.initialRoute,
    required this.onGenerateRoute,
    this.menuBuilder,
    this.navigationBackgroundColor,
    this.footer,
    this.isActive = true,
  });

  final String title;
  final List<NavigationPaneSection> sections;
  final String initialRoute;
  final RouteFactory onGenerateRoute;

  /// Customizes menu content while keeping the shared nested navigator.
  /// A custom menu owns its scroll content; [footer] belongs to the default menu.
  final NavigationPaneBuilder? menuBuilder;

  /// Independent menu surfaces can use the normal page background.
  final Color? navigationBackgroundColor;
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
    final cards = InterfaceTheme.of(context).style.isCard;
    final navigationSurface =
        navigationBackgroundColor ??
        (cards ? scheme.surface : scheme.surfaceContainerLow);
    final rtl = Directionality.of(context) == TextDirection.rtl;

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
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: rtl,
            removeRight: !rtl,
            child: AppScaffold(
              backgroundColor: navigationSurface,
              appBar: AppBar(
                title: Text(title),
                automaticallyImplyLeading: false,
                backgroundColor: navigationSurface,
              ),
              body: Builder(
                builder: (context) =>
                    menuBuilder?.call(
                      context,
                      selectedRoute.value,
                      selectDestination,
                    ) ??
                    AppCustomScrollView(
                      slivers: [
                        for (final section in sections)
                          AppSliverList(
                            title: section.title,
                            itemCount: section.destinations.length,
                            itemBuilder: (context, index) => _destination(
                              context,
                              section.destinations[index],
                              selectedRoute.value,
                              selectDestination,
                            ),
                          ),
                        if (footer != null)
                          SliverToBoxAdapter(
                            child: Column(
                              children: [const AppDivider(), footer!],
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      ],
                    ),
              ),
            ),
          ),
        ),
        const AppVerticalDivider(),
        Expanded(
          flex: 2,
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: !rtl,
            removeRight: rtl,
            // A detail route's BlockSemantics must stay inside this pane,
            // otherwise its nested Navigator hides the sibling menu from AT.
            child: Semantics(
              container: true,
              explicitChildNodes: true,
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
          ),
        ),
      ],
    );
  }

  Widget _destination(
    BuildContext context,
    NavigationPaneDestination destination,
    String selectedRoute,
    ValueChanged<String> onSelected,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
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
  }
}
