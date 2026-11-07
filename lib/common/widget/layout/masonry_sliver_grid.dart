import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:fzu_assistant/common/widget/layout/app_section.dart';
import 'package:fzu_assistant/constants/breakpoints.dart';

class MasonrySliverGrid extends StatelessWidget {
  final int childCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final bool _grouped;

  const MasonrySliverGrid({
    super.key,
    required this.childCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  }) : _grouped = false;

  /// Connected rows on phones, independent surfaces in a wide masonry grid.
  const MasonrySliverGrid.grouped({
    super.key,
    required this.childCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  }) : _grouped = true;

  @override
  Widget build(BuildContext context) {
    if (_grouped) {
      return SliverLayoutBuilder(
        builder: (context, constraints) =>
            constraints.crossAxisExtent <= kToolTileMaxWidth
            ? AppSliverList(itemCount: childCount, itemBuilder: itemBuilder)
            : _grid(
                (context, index) =>
                    AppSurface(child: itemBuilder(context, index)),
              ),
      );
    }
    return _grid(itemBuilder);
  }

  Widget _grid(IndexedWidgetBuilder builder) => SliverPadding(
    padding: padding,
    sliver: SliverMasonryGrid.extent(
      maxCrossAxisExtent: kToolTileMaxWidth,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childCount: childCount,
      itemBuilder: builder,
    ),
  );
}
