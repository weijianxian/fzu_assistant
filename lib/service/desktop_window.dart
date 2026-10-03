import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 窗口状态与原生操作；其他平台保持原有窗口行为。
class DesktopWindow extends ChangeNotifier with WindowListener {
  DesktopWindow._();

  static final instance = DesktopWindow._();
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static const _windowControl = MethodChannel('window_control');
  bool _initialized = false;
  bool _isFocused = true;
  bool _isMaximized = false;
  bool _isFullScreen = false;

  bool get isFocused => _isFocused;
  bool get isMaximized => _isMaximized;
  bool get isFullScreen => _isFullScreen;

  Future<void> initialize() async {
    if (!isWindows || _initialized) return;
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    // 所有关闭入口（按钮、Alt+F4、系统菜单）共用 WebView2 关窗修复。
    await windowManager.setPreventClose(true);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        minimumSize: Size(480, 360),
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
    );
    _isFocused = await windowManager.isFocused();
    _isMaximized = await windowManager.isMaximized();
    _isFullScreen = await windowManager.isFullScreen();
    _initialized = true;
    notifyListeners();
  }

  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  void onWindowClose() {
    unawaited(_windowControl.invokeMethod<void>('closeWindow'));
  }

  @override
  void onWindowFocus() {
    _isFocused = true;
    notifyListeners();
  }

  @override
  void onWindowBlur() {
    _isFocused = false;
    notifyListeners();
  }

  @override
  void onWindowMaximize() {
    _isMaximized = true;
    notifyListeners();
  }

  @override
  void onWindowUnmaximize() {
    _isMaximized = false;
    notifyListeners();
  }

  @override
  void onWindowEnterFullScreen() {
    _isFullScreen = true;
    notifyListeners();
  }

  @override
  void onWindowLeaveFullScreen() {
    _isFullScreen = false;
    notifyListeners();
  }
}
