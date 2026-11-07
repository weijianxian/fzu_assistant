import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:fzu_assistant/common/widget/sheet/half_screen_sheet.dart';

/// Scrollable content in the shared portrait sheet / landscape side panel.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
}) => showHalfScreenSheet<T>(
  context,
  backgroundColor: backgroundColor,
  builder: (controller) => AppSingleChildScrollView(
    controller: controller,
    child: Builder(builder: builder),
  ),
);
