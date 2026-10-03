import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/desktop_window.dart';
import 'package:window_manager/window_manager.dart';

/// 放在 Navigator 外层，页面和弹窗都位于标题栏下方。
class DesktopWindowFrame extends StatelessWidget {
  const DesktopWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!DesktopWindow.isWindows) return child;

    final window = DesktopWindow.instance;
    // 标题栏位于 Navigator 之外，需要单独的 Overlay 承载窗口按钮提示。
    return Overlay.wrap(
      child: ListenableBuilder(
        listenable: window,
        builder: (context, _) {
          if (window.isFullScreen) return child;
          return DragToResizeArea(
            // 隐藏系统标题栏后补上顶部缩放区，侧边和底部仍由 Windows 处理。
            enableResizeEdges: window.isMaximized
                ? const []
                : const [
                    ResizeEdge.topLeft,
                    ResizeEdge.top,
                    ResizeEdge.topRight,
                  ],
            child: Column(
              children: [
                _TitleBar(window: window),
                Expanded(
                  // 路由过渡的位移和阴影不能绘制到标题栏区域。
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(size: constraints.biggest),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.window});

  final DesktopWindow window;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final foreground = window.isFocused
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    final height = math.max(
      40.0,
      MediaQuery.textScalerOf(context).scale(13) * 1.4 + 16,
    );

    return Material(
      color: window.isFocused ? scheme.surfaceContainerLow : scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onSecondaryTap: windowManager.popUpWindowMenu,
                  child: DragToMoveArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: Image.asset(
                              'assets/icon/icon.png',
                              width: 22,
                              height: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _WindowButton(
                tooltip: l10n.windowMinimize,
                icon: Icons.remove,
                height: height,
                foreground: foreground,
                onPressed: windowManager.minimize,
              ),
              _WindowButton(
                tooltip: window.isMaximized
                    ? l10n.windowRestore
                    : l10n.windowMaximize,
                icon: window.isMaximized
                    ? Icons.filter_none
                    : Icons.crop_square,
                height: height,
                foreground: foreground,
                onPressed: window.toggleMaximize,
              ),
              _WindowButton(
                tooltip: l10n.windowClose,
                icon: Icons.close,
                height: height,
                foreground: foreground,
                isClose: true,
                onPressed: windowManager.close,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.height,
    required this.foreground,
    required this.onPressed,
    this.isClose = false,
  });

  final String tooltip;
  final IconData icon;
  final double height;
  final Color foreground;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 46,
      height: height,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            final active =
                states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed);
            return isClose && active ? Colors.white : foreground;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final active =
                states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed);
            if (!active) return Colors.transparent;
            return isClose
                ? const Color(0xFFE81123)
                : scheme.onSurface.withValues(alpha: 0.08);
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }
}
