import 'package:flutter/material.dart';

/// Shared informational notices, including in the classic list style.
class AppInfoCard extends StatelessWidget {
  const AppInfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Card.filled(
    margin: margin,
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: const Icon(Icons.info_outline),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    ),
  );
}
