import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';
import 'package:fzu_assistant/common/widget/sheet/sheet_drag_handle.dart';

Future<T?> showHalfScreenSheet<T>(
  BuildContext context, {
  required Widget Function(ScrollController controller) builder,
  Color? backgroundColor,
}) => showGeneralDialog<T>(
  context: context,
  useRootNavigator: true,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black54,
  transitionDuration: const Duration(milliseconds: 250),
  pageBuilder: (context, animation, secondaryAnimation) =>
      _AdaptiveHalfScreenSheet(
        builder: builder,
        backgroundColor: backgroundColor,
      ),
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
  const _AdaptiveHalfScreenSheet({required this.builder, this.backgroundColor});
  final Widget Function(ScrollController controller) builder;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final sideController = useScrollController();
    final landscape = context.isLandscape;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: SafeArea(
          top: !landscape,
          left: false,
          right: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (landscape) {
                final width = constraints.maxWidth * 2 / 3;
                return Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: backgroundColor,
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
                      child: MediaQuery.removePadding(
                        context: context,
                        removeLeft: true,
                        child: SafeArea(
                          left: false,
                          bottom: false,
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: MaterialLocalizations.of(context)
                                    .closeButtonTooltip,
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.chevron_right),
                              ),
                              Expanded(child: builder(sideController)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: backgroundColor,
                  elevation: 8,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child:
                        NotificationListener<DraggableScrollableNotification>(
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
                                const SheetDragHandle(),
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
      ),
    );
  }
}
