import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/constants/breakpoints.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

/// Toolbox entries always have their own surface, including in classic style.
/// Other pages keep the app-wide connected group preference.
class ToolboxMenu extends StatelessWidget {
  const ToolboxMenu({
    super.key,
    required this.sections,
    required this.onSelected,
    this.selectedRoute,
  });

  final List<NavigationPaneSection> sections;
  final ValueChanged<String> onSelected;
  final String? selectedRoute;

  @override
  Widget build(BuildContext context) => AppCustomScrollView(
    slivers: [
      for (final section in sections)
        if (section.destinations.isNotEmpty)
          SliverMainAxisGroup(
            slivers: [
              if (section.title != null)
                SliverToBoxAdapter(child: SectionHeader(title: section.title!)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 8.0;
                    // Larger text gets fewer, wider columns.
                    final fontSize =
                        Theme.of(context).textTheme.labelMedium?.fontSize ?? 12;
                    final scale = math.max(
                      1.0,
                      MediaQuery.textScalerOf(context).scale(fontSize) / 12,
                    );
                    final minWidth = kToolboxCardMinWidth * scale;
                    final columns = math.max(
                      1,
                      ((constraints.crossAxisExtent + gap) / (minWidth + gap))
                          .floor(),
                    );
                    final items = section.destinations;
                    final rows = (items.length / columns).ceil();
                    return SliverList.builder(
                      itemCount: rows,
                      itemBuilder: (context, row) {
                        final start = row * columns;
                        final end = math.min(start + columns, items.length);
                        // Intrinsic rows share their bottom edge without fixing
                        // a height or truncating enlarged / translated titles.
                        // Empty cells keep the final row and every section on
                        // the same columns instead of stretching its cards.
                        return Padding(
                          padding: const EdgeInsets.only(bottom: gap),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (
                                  var index = start;
                                  index < start + columns;
                                  index++
                                ) ...[
                                  if (index > start) const SizedBox(width: gap),
                                  Expanded(
                                    child: index < end
                                        ? ToolboxFeatureCard(
                                            destination: items[index],
                                            selected:
                                                items[index].route ==
                                                selectedRoute,
                                            onTap: () =>
                                                onSelected(items[index].route),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ],
  );
}

/// Native Material interaction with a layout that can measure wrapped titles.
class ToolboxFeatureCard extends StatelessWidget {
  const ToolboxFeatureCard({
    super.key,
    required this.destination,
    required this.onTap,
    this.selected = false,
  });

  final NavigationPaneDestination destination;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ThemeVisuals.of(context).cardRadius),
    );
    final selectedSurface = theme.colorScheme.secondaryContainer.withValues(
      alpha: CardTheme.of(context).color?.a ?? 1,
    );
    final foreground = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;
    final secondaryForeground = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final menuTitle = destination.menuTitle ?? destination.title;
    return Card.filled(
      key: ValueKey('toolbox-card-${destination.route}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: shape,
      color: selected ? selectedSurface : null,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      destination.icon,
                      size: 24,
                      color: secondaryForeground,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      menuTitle,
                      textAlign: TextAlign.center,
                      semanticsLabel: destination.subtitle == null
                          ? destination.title
                          : '${destination.title}\n${destination.subtitle}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
