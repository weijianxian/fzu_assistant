import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';

Future<T?> showHalfScreenSheet<T>(
  BuildContext context, {
  required Widget Function(ScrollController controller) builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black54,
  transitionDuration: const Duration(milliseconds: 250),
  pageBuilder: (context, animation, secondaryAnimation) =>
      _AdaptiveHalfScreenSheet(builder: builder),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position:
            Tween<Offset>(
              begin: context.isLandscape
                  ? const Offset(1, 0)
                  : const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
);

class _AdaptiveHalfScreenSheet extends HookWidget {
  const _AdaptiveHalfScreenSheet({required this.builder});
  final Widget Function(ScrollController controller) builder;

  @override
  Widget build(BuildContext context) {
    final sideController = useScrollController();
    final landscape = context.isLandscape;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: !landscape,
        left: false,
        right: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (landscape) {
              final width = (constraints.maxWidth * 0.4).clamp(
                constraints.maxWidth < 360 ? constraints.maxWidth : 360.0,
                constraints.maxWidth,
              );
              return Align(
                alignment: Alignment.centerRight,
                child: Material(
                  elevation: 8,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: width,
                    height: double.infinity,
                    child: SafeArea(
                      left: false,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 16,
                              ),
                              child: Icon(Icons.chevron_right),
                            ),
                          ),
                          Expanded(child: builder(sideController)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                elevation: 8,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  child: NotificationListener<DraggableScrollableNotification>(
                    onNotification: (notification) {
                      if (notification.shouldCloseOnMinExtent &&
                          notification.extent <= notification.minExtent) {
                        Navigator.of(context).pop();
                      }
                      return false;
                    },
                    child: DraggableScrollableSheet(
                      initialChildSize: 0.5,
                      maxChildSize: 1,
                      expand: false,
                      builder: (context, controller) => Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(child: builder(controller)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
