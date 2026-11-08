import 'package:flutter/material.dart';

/// A native radio row aligned with the app's 24 dp leading icons.
class SettingsRadioTile<T> extends StatelessWidget {
  const SettingsRadioTile({
    super.key,
    required this.value,
    required this.title,
    this.subtitle,
    this.enabled,
  });

  final T value;
  final Widget title;
  final Widget? subtitle;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final density =
        RadioTheme.of(context).visualDensity ?? Theme.of(context).visualDensity;
    // RadioListTile keeps a native 40 dp target around its 20 dp mark.
    // Split the extra width equally before and after the control so its center
    // and the title both line up with a normal Material 3 ListTile icon.
    final controlInset =
        (kMinInteractiveDimension - 8 + density.baseSizeAdjustment.dx - 24) / 2;
    return RadioListTile<T>(
      value: value,
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsetsDirectional.only(
        start: 16 - controlInset,
        end: 24,
      ),
      horizontalTitleGap: 16 - controlInset,
    );
  }
}
