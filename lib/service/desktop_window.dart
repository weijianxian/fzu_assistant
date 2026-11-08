import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 窗口状态与原生操作；其他平台保持原有窗口行为。
class DesktopWindow extends ChangeNotifier {
  DesktopWindow._();

  @visibleForTesting
  DesktopWindow.forTesting(Window window) {
    _attach(window);
  }

  static final instance = DesktopWindow._();
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static const _windowControl = MethodChannel('window_control');
  Window? _window;
  ListenerId? _listenerId;
  bool _isFocused = true;
  bool _isMaximized = false;
  bool _isFullScreen = false;

  /// 后台服务接管普通关闭；明确退出始终直接调用 [exitApplication]。
  Future<void> Function()? onCloseRequested;

  bool get isFocused => _isFocused;
  bool get isMaximized => _isMaximized;
  bool get isFullScreen => _isFullScreen;
  Window get nativeWindow => _window!;

  Future<void> initialize() async {
    if (!isWindows || _window != null) return;
    final window = WindowManager.instance.getCurrent();
    if (window == null) throw StateError('Windows window is unavailable');
    _attach(window);
    window.minimumSize = const Size(480, 360).toNative();
    window.titleBarStyle = TitleBarStyle.hidden;
    window.isWindowControlButtonsVisible = false;
  }

  void _attach(Window window) {
    _window = window;
    _listenerId = window.addListener(_onWindowEvent);
    _refreshState();
  }

  void _refreshState() {
    _isFocused = nativeWindow.isFocused;
    _isMaximized = nativeWindow.isMaximized;
    _isFullScreen = nativeWindow.isFullScreen;
    notifyListeners();
  }

  Future<void> show() async {
    if (nativeWindow.isMinimized) nativeWindow.restore();
    nativeWindow.show();
    nativeWindow.focus();
  }

  Future<void> hide() async {
    nativeWindow.hide();
    if (nativeWindow.isVisible) {
      throw StateError('Windows window could not be hidden');
    }
  }

  /// 直接复用 WebView2 的进程退出修复，跳过普通关闭到托盘逻辑。
  Future<void> exitApplication() =>
      _windowControl.invokeMethod<void>('closeWindow');

  void toggleMaximize() {
    if (nativeWindow.isMaximized) {
      nativeWindow.unmaximize();
    } else {
      nativeWindow.maximize();
    }
  }

  void _onWindowEvent(WindowEvent event) {
    switch (event) {
      case WindowCloseRequestedEvent():
        // 所有关闭入口（按钮、Alt+F4、系统菜单）共用 WebView2 关窗修复。
        event.request.cancel();
        unawaited(_requestClose());
      case WindowFocusedEvent() ||
          WindowBlurredEvent() ||
          WindowMaximizedEvent() ||
          WindowRestoredEvent() ||
          WindowEnteredFullScreenEvent() ||
          WindowExitedFullScreenEvent():
        _refreshState();
      default:
        break;
    }
  }

  Future<void> _requestClose() async {
    try {
      await (onCloseRequested ?? exitApplication)();
    } catch (error) {
      debugPrint('Could not close Windows window: $error');
      try {
        await show();
      } catch (restoreError) {
        debugPrint('Could not restore Windows window: $restoreError');
      }
    }
  }

  @override
  void dispose() {
    final listenerId = _listenerId;
    if (listenerId != null) _window?.removeListener(listenerId);
    super.dispose();
  }
}
