import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/layout/section.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

/// A content surface that follows the app's list/card preference.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!InterfaceTheme.of(context).style.isCard) {
      return Padding(padding: margin, child: child);
    }
    final visuals = ThemeVisuals.of(context);
    return Card.filled(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(visuals.cardRadius),
      ),
      child: child,
    );
  }
}

/// Shared section headings and connected groups, including compound content.
class AppSection extends StatelessWidget {
  const AppSection({super.key, this.title, required Widget this.child})
    : children = null;

  const AppSection.list({
    super.key,
    this.title,
    required List<Widget> this.children,
  }) : child = null;

  final String? title;
  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    if (children?.isEmpty == true) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) SectionHeader(title: title!),
        if (child != null)
          AppSurface(
            margin: InterfaceTheme.of(context).style.isCard
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                : EdgeInsets.zero,
            child: child!,
          )
        else
          for (var index = 0; index < children!.length; index++)
            AppListItem(
              index: index,
              itemCount: children!.length,
              child: children![index],
            ),
      ],
    );
  }
}

/// One lazy-list row; first and last rows own the outer group corners.
/// Classic rows stay flat without item dividers.
class AppListItem extends StatelessWidget {
  const AppListItem({
    super.key,
    required this.index,
    required this.itemCount,
    required this.child,
  }) : assert(index >= 0 && index < itemCount);

  final int index;
  final int itemCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = InterfaceTheme.of(context).style;
    if (!style.isCard) return child;
    final continuous = style == InterfaceStyle.continuousCards;
    final radius = ThemeVisuals.of(context).cardRadius;
    final innerRadius = continuous ? 0.0 : radius.clamp(0.0, 4.0);
    return AppSurface(
      margin: EdgeInsets.fromLTRB(
        16,
        index == 0 ? 8 : 0,
        16,
        index == itemCount - 1 ? 8 : (continuous ? 0 : 4),
      ),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(index == 0 ? radius : innerRadius),
        bottom: Radius.circular(index == itemCount - 1 ? radius : innerRadius),
      ),
      child: child,
    );
  }
}

/// Lazy counterpart to [AppSection.list], preserving native scrolling.
class AppSliverList extends StatelessWidget {
  const AppSliverList({
    super.key,
    this.title,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String? title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      if (title != null && itemCount > 0)
        SliverToBoxAdapter(child: SectionHeader(title: title!)),
      SliverList.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) => AppListItem(
          index: index,
          itemCount: itemCount,
          child: itemBuilder(context, index),
        ),
      ),
    ],
  );
}

/// A surface for native sliver content such as a seat grid.
class AppSliverSurface extends StatelessWidget {
  const AppSliverSurface({super.key, required this.sliver});

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    if (!InterfaceTheme.of(context).style.isCard) {
      return sliver;
    }
    final visuals = ThemeVisuals.of(context);
    final surface =
        CardTheme.of(context).color ??
        Theme.of(context).colorScheme.surfaceContainerLow;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(visuals.cardRadius),
        ),
        sliver: SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          sliver: sliver,
        ),
      ),
    );
  }
}

/// Separates logical sections with space in cards and a line in classic style.
class AppDivider extends StatelessWidget {
  const AppDivider({
    super.key,
    this.height,
    this.indent,
    this.endIndent,
    this.spacing = 8,
  });

  final double? height;
  final double? indent;
  final double? endIndent;
  final double spacing;

  @override
  Widget build(BuildContext context) => InterfaceTheme.of(context).style.isCard
      ? SizedBox(height: spacing)
      : Divider(height: height, indent: indent, endIndent: endIndent);
}

class AppVerticalDivider extends StatelessWidget {
  const AppVerticalDivider({super.key, this.width = 1, this.spacing = 8});

  final double width;
  final double spacing;

  @override
  Widget build(BuildContext context) => InterfaceTheme.of(context).style.isCard
      ? SizedBox(width: spacing)
      : VerticalDivider(width: width);
}
