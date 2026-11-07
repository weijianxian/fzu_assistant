import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/layout/app_section.dart';

/// Consumes system insets for scroll content without shrinking its viewport.
class AppScrollInsets extends StatelessWidget {
  const AppScrollInsets({super.key, required this.builder});

  final Widget Function(BuildContext context, EdgeInsets insets) builder;

  @override
  Widget build(BuildContext context) {
    final insets = EdgeInsets.only(
      bottom: MediaQuery.paddingOf(context).bottom,
    );
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: Builder(builder: (context) => builder(context, insets)),
    );
  }
}

/// A native list whose final content avoids the bottom system bar.
class AppListView extends StatelessWidget {
  AppListView({
    Key? key,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController? controller,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    double? itemExtent,
    Widget? prototypeItem,
    List<Widget> children = const [],
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior,
  }) : this.fromListView(
         ListView(
           scrollDirection: scrollDirection,
           reverse: reverse,
           controller: controller,
           primary: primary,
           physics: physics,
           shrinkWrap: shrinkWrap,
           padding: padding,
           itemExtent: itemExtent,
           prototypeItem: prototypeItem,
           keyboardDismissBehavior: keyboardDismissBehavior,
           children: children,
         ),
         key: key,
       );

  AppListView.builder({
    Key? key,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController? controller,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    double? itemExtent,
    Widget? prototypeItem,
    int? itemCount,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior,
  }) : this.fromListView(
         ListView.builder(
           scrollDirection: scrollDirection,
           reverse: reverse,
           controller: controller,
           primary: primary,
           physics: physics,
           shrinkWrap: shrinkWrap,
           padding: padding,
           itemExtent: itemExtent,
           prototypeItem: prototypeItem,
           itemCount: itemCount,
           itemBuilder: itemBuilder,
           findChildIndexCallback: findChildIndexCallback,
           keyboardDismissBehavior: keyboardDismissBehavior,
         ),
         key: key,
       );

  AppListView.separated({
    Key? key,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController? controller,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    required int itemCount,
    required NullableIndexedWidgetBuilder itemBuilder,
    required IndexedWidgetBuilder separatorBuilder,
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior,
  }) : this.fromListView(
         ListView.separated(
           scrollDirection: scrollDirection,
           reverse: reverse,
           controller: controller,
           primary: primary,
           physics: physics,
           shrinkWrap: shrinkWrap,
           padding: padding,
           itemCount: itemCount,
           itemBuilder: itemBuilder,
           separatorBuilder: separatorBuilder,
           keyboardDismissBehavior: keyboardDismissBehavior,
         ),
         key: key,
       );

  AppListView.grouped({
    Key? key,
    ScrollController? controller,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) : this.builder(
         key: key,
         controller: controller,
         physics: physics,
         padding: padding,
         itemCount: itemCount,
         itemBuilder: (context, index) => AppListItem(
           index: index,
           itemCount: itemCount,
           child: itemBuilder(context, index),
         ),
       );

  const AppListView.fromListView(
    this.nativeListView, {
    super.key,
    this.footer,
    this.controller,
    this.physics,
  });

  final ListView nativeListView;
  final Widget? footer;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  Widget _buildList(BuildContext context, EdgeInsets insets) {
    final view = nativeListView;
    final controller = this.controller ?? view.controller;
    final primary = controller == null ? view.primary : false;
    if (footer != null) {
      return CustomScrollView(
        key: view.key,
        scrollDirection: view.scrollDirection,
        reverse: view.reverse,
        controller: controller,
        primary: primary,
        physics: physics ?? view.physics,
        shrinkWrap: view.shrinkWrap,
        scrollCacheExtent: view.scrollCacheExtent,
        semanticChildCount: view.semanticChildCount == null
            ? null
            : view.semanticChildCount! + 1,
        dragStartBehavior: view.dragStartBehavior,
        keyboardDismissBehavior: view.keyboardDismissBehavior,
        restorationId: view.restorationId,
        clipBehavior: view.clipBehavior,
        hitTestBehavior: view.hitTestBehavior,
        slivers: [
          if (view.reverse && insets.bottom > 0)
            SliverToBoxAdapter(child: SizedBox(height: insets.bottom)),
          ...view.buildSlivers(context),
          SliverToBoxAdapter(child: footer),
          if (!view.reverse && insets.bottom > 0)
            SliverToBoxAdapter(child: SizedBox(height: insets.bottom)),
        ],
      );
    }
    final defaultPadding = EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top,
    );
    return ListView.custom(
      key: view.key,
      scrollDirection: view.scrollDirection,
      reverse: view.reverse,
      controller: controller,
      primary: primary,
      physics: physics ?? view.physics,
      shrinkWrap: view.shrinkWrap,
      padding: (view.padding ?? defaultPadding).add(insets),
      itemExtent: view.itemExtent,
      itemExtentBuilder: view.itemExtentBuilder,
      prototypeItem: view.prototypeItem,
      childrenDelegate: view.childrenDelegate,
      scrollCacheExtent: view.scrollCacheExtent,
      semanticChildCount: view.semanticChildCount,
      dragStartBehavior: view.dragStartBehavior,
      keyboardDismissBehavior: view.keyboardDismissBehavior,
      restorationId: view.restorationId,
      clipBehavior: view.clipBehavior,
      hitTestBehavior: view.hitTestBehavior,
    );
  }

  @override
  Widget build(BuildContext context) =>
      nativeListView.scrollDirection == Axis.vertical
      ? AppScrollInsets(builder: _buildList)
      : nativeListView;
}

/// A sliver viewport that scrolls through the system bar and ends above it.
class AppCustomScrollView extends StatelessWidget {
  const AppCustomScrollView({
    super.key,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.reverse = false,
    this.scrollDirection = Axis.vertical,
    this.slivers = const [],
    this.keyboardDismissBehavior,
  });

  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool reverse;
  final Axis scrollDirection;
  final List<Widget> slivers;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  Widget _buildScrollView(BuildContext context, EdgeInsets insets) =>
      CustomScrollView(
        controller: controller,
        primary: primary,
        physics: physics,
        shrinkWrap: shrinkWrap,
        reverse: reverse,
        scrollDirection: scrollDirection,
        keyboardDismissBehavior: keyboardDismissBehavior,
        slivers: [
          if (reverse && insets.bottom > 0)
            SliverToBoxAdapter(child: SizedBox(height: insets.bottom)),
          ...slivers,
          if (!reverse && insets.bottom > 0)
            SliverToBoxAdapter(child: SizedBox(height: insets.bottom)),
        ],
      );

  @override
  Widget build(BuildContext context) => scrollDirection == Axis.vertical
      ? AppScrollInsets(builder: _buildScrollView)
      : _buildScrollView(context, EdgeInsets.zero);
}

/// A single-child viewport with system space at the end of its scroll content.
class AppSingleChildScrollView extends StatelessWidget {
  const AppSingleChildScrollView({
    super.key,
    this.controller,
    this.primary,
    this.physics,
    this.padding,
    this.child,
    this.reverse = false,
    this.scrollDirection = Axis.vertical,
    this.keyboardDismissBehavior,
  });

  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final bool reverse;
  final Axis scrollDirection;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  Widget _buildScrollView(BuildContext context, EdgeInsets insets) =>
      SingleChildScrollView(
        controller: controller,
        primary: primary,
        physics: physics,
        padding: (padding ?? EdgeInsets.zero).add(insets),
        reverse: reverse,
        scrollDirection: scrollDirection,
        keyboardDismissBehavior: keyboardDismissBehavior,
        child: child,
      );

  @override
  Widget build(BuildContext context) => scrollDirection == Axis.vertical
      ? AppScrollInsets(builder: _buildScrollView)
      : _buildScrollView(context, EdgeInsets.zero);
}
