import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/layout/app_top_banner.dart';

/// Keeps page content inside system insets while surfaces remain edge to edge.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.floatingActionButton,
  }) : _isShell = false,
       navigationRail = null,
       topBanner = null;

  /// Navigation chrome and child pages paint their own system-edge surfaces.
  const AppScaffold.shell({
    super.key,
    required Widget this.body,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.navigationRail,
    this.topBanner,
  }) : appBar = null,
       floatingActionButton = null,
       _isShell = true;

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final NavigationRail? navigationRail;
  final AppTopBanner? topBanner;
  final bool _isShell;

  Widget _shellContent(BuildContext context) {
    if (topBanner != null) {
      return Column(
        children: [
          topBanner!,
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: body!,
            ),
          ),
        ],
      );
    }
    return body!;
  }

  Widget _shellBody(BuildContext context) {
    final content = Builder(builder: _shellContent);
    if (navigationRail == null) return content;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: [
        navigationRail!,
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: !rtl,
            removeRight: rtl,
            child: content,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    backgroundColor: backgroundColor,
    bottomNavigationBar: bottomNavigationBar,
    floatingActionButton: floatingActionButton,
    // Evaluate inside Scaffold so its AppBar/bottom-bar/keyboard insets apply.
    body: _isShell
        ? Builder(builder: _shellBody)
        : body == null
        ? null
        : SafeArea(bottom: false, child: body!),
  );
}

/// Static content avoids the gesture area inside its surrounding surface.
class AppSafeContent extends StatelessWidget {
  const AppSafeContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SafeArea(top: false, left: false, right: false, child: child);
}

/// A fixed bottom action surface paints to the edge and protects its controls.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(child: SafeArea(top: false, child: child));
}
