import 'package:flutter/material.dart';

class SettingSwitchTile extends StatelessWidget {
  final ValueNotifier<bool> notifier;
  final Widget title;
  final Widget? subtitle;
  final Widget? secondary;

  const SettingSwitchTile({
    super.key,
    required this.notifier,
    required this.title,
    this.subtitle,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (_, value, _) => SwitchListTile(
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        value: value,
        onChanged: (v) => notifier.value = v,
      ),
    );
  }
}
