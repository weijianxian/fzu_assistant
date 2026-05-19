import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:fzu_assistant/constants/breakpoints.dart';

class MasonrySliverGrid extends StatelessWidget {
  final int childCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  const MasonrySliverGrid({
    super.key,
    required this.childCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverMasonryGrid.extent(
        maxCrossAxisExtent: kTileMinWidth,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childCount: childCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}
