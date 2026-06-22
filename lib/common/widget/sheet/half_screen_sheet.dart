import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';

Future<T?> showHalfScreenSheet<T>(
  BuildContext context, {
  required Widget Function(ScrollController controller) builder,
}) {
  if (context.isLandscape) {
    return _showSideSheet<T>(context, builder: builder);
  }
  return _showBottomSheet<T>(context, builder: builder);
}

Future<T?> _showBottomSheet<T>(
  BuildContext context, {
  required Widget Function(ScrollController controller) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(child: builder(controller)),
        ],
      ),
    ),
  );
}

Future<T?> _showSideSheet<T>(
  BuildContext context, {
  required Widget Function(ScrollController controller) builder,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final sheetWidth = screenWidth * 0.4 < 360.0 ? 360.0 : screenWidth * 0.4;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          elevation: 8,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: sheetWidth,
            height: double.infinity,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Icon(Icons.chevron_right),
                  ),
                ),
                Expanded(child: builder(ScrollController())),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
  );
}
