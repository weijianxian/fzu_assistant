import 'package:flutter/material.dart';

/// Extends the native banner surface behind system bars and insets its content.
class AppTopBanner extends StatelessWidget {
  const AppTopBanner({super.key, required this.content, required this.actions});

  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final singleRow = actions.length == 1;
    final insets = MediaQuery.paddingOf(context);
    final defaultPadding = singleRow
        ? const EdgeInsetsDirectional.only(start: 16, top: 2)
        : const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 4);
    final padding = (MaterialBannerTheme.of(context).padding ?? defaultPadding)
        .resolve(Directionality.of(context));

    return MaterialBanner(
      padding:
          padding +
          EdgeInsets.only(
            left: insets.left,
            top: insets.top,
            right: insets.right,
          ),
      content: content,
      // Native banners place multiple actions below the padded content row.
      actions: singleRow
          ? actions
          : [
              for (final action in actions)
                Padding(
                  padding: EdgeInsets.only(
                    left: insets.left,
                    right: insets.right,
                  ),
                  child: action,
                ),
            ],
    );
  }
}
