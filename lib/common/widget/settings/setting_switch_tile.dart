import 'package:flutter/material.dart';

class SettingSwitchTile extends StatelessWidget {
  final ValueNotifier<bool>? notifier;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final Widget? secondary;

  const SettingSwitchTile({
    super.key,
    required ValueNotifier<bool> this.notifier,
    required this.title,
    this.subtitle,
    this.secondary,
  }) : value = null,
       onChanged = null;

  const SettingSwitchTile.controlled({
    super.key,
    required bool this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.secondary,
  }) : notifier = null;

  @override
  Widget build(BuildContext context) {
    Widget tile(bool selected, ValueChanged<bool>? change) => SwitchListTile(
      title: title,
      subtitle: subtitle,
      secondary: secondary,
      value: selected,
      onChanged: change,
    );
    if (notifier == null) return tile(value!, onChanged);
    return ValueListenableBuilder<bool>(
      valueListenable: notifier!,
      builder: (_, selected, _) =>
          tile(selected, (value) => notifier!.value = value),
    );
  }
}
