import 'package:flutter/material.dart';

/// Native disclosure behavior with the app's borderless expanded/collapsed style.
///
/// Surfaces and grouping belong to AppSection/SettingsSection; this component
/// preserves Material's spacing, semantics, animation and PageStorage behavior.
class AppExpansionTile extends StatelessWidget {
  const AppExpansionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.children = const [],
    this.onExpansionChanged,
    this.initiallyExpanded = false,
    this.maintainState = false,
    this.tilePadding,
    this.childrenPadding,
  });

  final Widget title;
  final Widget? subtitle, leading, trailing;
  final List<Widget> children;
  final ValueChanged<bool>? onExpansionChanged;
  final bool initiallyExpanded, maintainState;
  final EdgeInsetsGeometry? tilePadding, childrenPadding;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: title,
    subtitle: subtitle,
    leading: leading,
    trailing: trailing,
    onExpansionChanged: onExpansionChanged,
    initiallyExpanded: initiallyExpanded,
    maintainState: maintainState,
    tilePadding: tilePadding,
    childrenPadding: childrenPadding,
    shape: const Border(),
    collapsedShape: const Border(),
    children: children,
  );
}
