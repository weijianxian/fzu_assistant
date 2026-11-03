import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:fzu_assistant/common/widget/sheet/sheet_drag_handle.dart';

/// Shared bottom-sheet layout: full-screen scrim, safe content and keyboard space.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (context) => AnimatedPadding(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetDragHandle(),
          Flexible(
            child: AppSingleChildScrollView(child: Builder(builder: builder)),
          ),
        ],
      ),
    ),
  ),
);
