import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
              if (constraints.maxHeight <= 0) return const SizedBox.shrink();
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
                    child: _ContentSizedDraggableSheet(
                      availableHeight: constraints.maxHeight,
                      builder: builder,
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

class _ContentSizedDraggableSheet extends HookWidget {
  const _ContentSizedDraggableSheet({
    required this.availableHeight,
    required this.builder,
  });

  final double availableHeight;
  final Widget Function(ScrollController controller) builder;

  @override
  Widget build(BuildContext context) {
    final contentSize = useState<({double height, double fixedHeight})?>(null);
    final controller = useMemoized(DraggableScrollableController.new);
    useEffect(() => controller.dispose, [controller]);
    final scrollController = useRef<ScrollController?>(null);
    final closing = useRef(false);
    final maxSize = contentSize.value == null
        ? 1.0
        : (contentSize.value!.height / availableHeight).clamp(0.0, 1.0);
    final fixedSize = ((contentSize.value?.fixedHeight ?? 20) / availableHeight)
        .clamp(0.0, maxSize);
    final initialSize = math.max(fixedSize, math.min(maxSize, 0.5));
    final minSize = math.max(fixedSize, initialSize / 2);

    useEffect(() {
      var disposed = false;
      void measure(Duration _) {
        if (disposed) return;
        final scroll = scrollController.value;
        if (controller.isAttached &&
            scroll != null &&
            scroll.positions.length == 1) {
          final position = scroll.position;
          final extent = _scrollContentExtent(position);
          if (extent != null && extent.isFinite) {
            // Preserve the handle and fixed footer, subtracting only unused
            // viewport space. This reads the same lazily laid-out content.
            final fixedHeight = math.max(
              0.0,
              controller.size * availableHeight - position.viewportDimension,
            );
            final height = (fixedHeight + extent).clamp(0.0, availableHeight);
            final previous = contentSize.value;
            if (previous == null ||
                (previous.height - height).abs() > 0.5 ||
                (previous.fixedHeight - fixedHeight).abs() > 0.5) {
              contentSize.value = (height: height, fixedHeight: fixedHeight);
            }
          }
        }
        // Observe frames that are already being rendered; do not request an
        // idle frame. Metrics alone miss short-content-to-short-content edits.
        WidgetsBinding.instance.addPostFrameCallback(measure);
      }

      WidgetsBinding.instance.addPostFrameCallback(measure);
      return () => disposed = true;
    }, [controller, availableHeight]);

    void close() {
      if (closing.value) return;
      closing.value = true;
      Navigator.of(context).pop();
    }

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.shouldCloseOnMinExtent &&
            notification.extent <= notification.minExtent) {
          close();
        }
        return false;
      },
      child: DraggableScrollableSheet(
        controller: controller,
        initialChildSize: initialSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        expand: false,
        builder: (context, scroll) {
          scrollController.value = scroll;
          return Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  if (closing.value || !controller.isAttached) return;
                  if (details.delta.dy > 0 && controller.size <= minSize) {
                    close();
                  } else {
                    controller.jumpTo(
                      (controller.size - details.delta.dy / availableHeight)
                          .clamp(minSize, maxSize),
                    );
                  }
                },
                child: const SheetDragHandle(),
              ),
              Expanded(child: builder(scroll)),
            ],
          );
        },
      ),
    );
  }
}

double? _scrollContentExtent(ScrollPosition position) {
  if (!position.hasContentDimensions || position.axis != Axis.vertical) {
    return null;
  }
  if (position.maxScrollExtent > position.minScrollExtent) {
    return position.viewportDimension +
        position.maxScrollExtent -
        position.minScrollExtent;
  }

  // ScrollMetrics clamps underflow to zero. Read the already laid-out native
  // viewport only in that case, so short lists can report their actual height.
  RenderAbstractViewport? viewport;
  void findViewport(RenderObject object) {
    if (viewport != null) return;
    if (object is RenderAbstractViewport) {
      viewport = object;
    } else {
      object.visitChildren(findViewport);
    }
  }

  final renderObject = position.context.notificationContext?.findRenderObject();
  if (renderObject == null) return null;
  findViewport(renderObject);
  final view = viewport;
  if (view == null) return null;
  double? extent;
  view.visitChildren((child) {
    if (child is RenderSliver) {
      extent = (extent ?? 0) + (child.geometry?.scrollExtent ?? 0);
    } else if (child is RenderBox && child.hasSize) {
      extent = child.size.height;
    }
  });
  return extent;
}
