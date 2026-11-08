import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/service/desktop_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart' as tray;

/// 托盘文案由当前应用语言提供，不在原生菜单中固定语言。
class WindowsBackgroundLabels {
  const WindowsBackgroundLabels({
    required this.appName,
    required this.showWindow,
    required this.exit,
  });

  final String appName, showWindow, exit;

  @override
  bool operator ==(Object other) =>
      other is WindowsBackgroundLabels &&
      appName == other.appName &&
      showWindow == other.showWindow &&
      exit == other.exit;

  @override
  int get hashCode => Object.hash(appName, showWindow, exit);
}

/// 业务只依赖成熟托盘库的创建、菜单和可见性；测试可模拟原生失败。
abstract interface class WindowsBackgroundTray {
  bool get ready;

  Future<void> show({
    required WindowsBackgroundLabels labels,
    required Future<void> Function() onRestore,
    required Future<void> Function() onExit,
  });

  Future<void> destroy();
}

/// Windows 进程保持运行；隐藏窗口不会停掉缓存监听或通知计时器。
class WindowsBackgroundService extends ChangeNotifier {
  WindowsBackgroundService._()
    : this._with(
        DesktopWindow.instance,
        _NativeWindowsBackgroundTray(),
        () => supported,
      );

  @visibleForTesting
  factory WindowsBackgroundService.forTesting({
    required DesktopWindow window,
    required WindowsBackgroundTray tray,
    bool isSupported = true,
  }) => WindowsBackgroundService._with(window, tray, () => isSupported);

  WindowsBackgroundService._with(this._window, this._tray, this._supported);

  static final instance = WindowsBackgroundService._();
  static bool get supported => DesktopWindow.isWindows;

  final DesktopWindow _window;
  final WindowsBackgroundTray _tray;
  final bool Function() _supported;
  Future<void>? _initialization;
  Future<void> _pending = Future.value();
  WindowsBackgroundLabels? _labels;
  bool _initialized = false;
  bool _enabled = false;
  bool _hidden = false;
  bool _busy = false;
  bool _failed = false;
  bool _exiting = false;
  bool _disposed = false;

  /// 通知服务通过共享集成层注册清理，不另建通知插件或调度器。
  Future<void> Function()? beforeExit;

  bool get isSupported => _supported();
  bool get initialized => _initialized;
  bool get enabled => _enabled;
  bool get hidden => _hidden;
  bool get busy => _busy;
  bool get failed => _failed;
  bool get trayReady => isSupported && _tray.ready;

  Future<void> initialize() {
    if (!isSupported || _disposed) return Future.value();
    return _initialization ??= _load();
  }

  Future<void> _load() async {
    _window.onCloseRequested = _handleClose;
    try {
      final prefs = await SharedPreferences.getInstance();
      // 缺少偏好的旧安装保留“关闭即退出”，用户明确开启才改变行为。
      _enabled = prefs.getBool(SpKeys.windowsCloseToTray) ?? false;
    } catch (error) {
      _failed = true;
      debugPrint('Could not load Windows background settings: $error');
    }
    _initialized = true;
    _notify();
  }

  void updateLabels(WindowsBackgroundLabels labels) {
    if (!isSupported || _disposed || labels == _labels) return;
    _labels = labels;
    _event(() async {
      await initialize();
      if (_disposed) return;
      await _serialize(() async {
        if (_enabled && !_exiting) await _ensureTray();
      });
    });
  }

  Future<bool> setEnabled(bool value) async {
    if (!isSupported || _disposed) return false;
    await initialize();
    if (_disposed) return false;
    return _serialize(() async {
      _failed = false;
      if (value && !await _ensureTray()) return false;
      try {
        // 撤掉托盘之前先恢复窗口，避免用户关闭设置后找不到应用。
        if (!value && _hidden) await _restore();
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setBool(SpKeys.windowsCloseToTray, value)) {
          throw StateError('Could not save close-to-tray preference');
        }
        _enabled = value;
        if (!value) await _tray.destroy();
        return true;
      } catch (error) {
        _failed = true;
        if (!_enabled) await _destroyTraySafely();
        await _restoreSafely();
        debugPrint('Could not change Windows background settings: $error');
        return false;
      }
    });
  }

  Future<bool> _ensureTray() async {
    final labels = _labels;
    try {
      if (labels == null) {
        throw StateError('Tray labels are not ready');
      }
      await _tray.show(
        labels: labels,
        onRestore: restoreWindow,
        onExit: exitApplication,
      );
      if (!_tray.ready) throw StateError('Windows tray is not visible');
      _failed = false;
      return true;
    } catch (error) {
      _failed = true;
      await _destroyTraySafely();
      await _restoreSafely();
      debugPrint('Could not create Windows tray: $error');
      return false;
    }
  }

  Future<void> _handleClose() => _serialize(() async {
    if (_exiting) return;
    if (_enabled && await _ensureTray()) {
      try {
        await _window.hide();
        _hidden = true;
        return;
      } catch (error) {
        _failed = true;
        await _restoreSafely();
        debugPrint('Could not hide Windows window: $error');
      }
    }
    // 未开启或托盘失败时，关闭仍可退出，绝不留下无法找回的后台进程。
    await _exit();
  });

  /// 托盘和 toast 点击共用；最小化、隐藏或未开启驻留时均可恢复。
  Future<void> restoreWindow() async {
    if (!isSupported || _disposed) return;
    await _serialize(_restore);
  }

  Future<void> _restore() async {
    await _window.show();
    _hidden = false;
  }

  Future<void> _restoreSafely() async {
    try {
      await _restore();
    } catch (error) {
      debugPrint('Could not restore Windows window: $error');
    }
  }

  /// 明确退出先取消未来通知，再移除托盘并调用原有 WebView2 退出修复。
  Future<void> exitApplication() async {
    if (!isSupported || _disposed) return;
    await _serialize(_exit);
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    try {
      try {
        await beforeExit?.call();
      } catch (error) {
        // 即使通知清理失败，明确退出仍应释放进程；进程结束也会停止计时器。
        debugPrint('Could not finish Windows notification cleanup: $error');
      }
      await _destroyTraySafely();
      await _window.exitApplication();
    } catch (error) {
      _exiting = false;
      _failed = true;
      await _restoreSafely();
      rethrow;
    }
  }

  Future<void> _destroyTraySafely() async {
    try {
      await _tray.destroy();
    } catch (error) {
      debugPrint('Could not destroy Windows tray: $error');
    }
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      _busy = true;
      _notify();
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        _busy = false;
        _notify();
      }
    });
    return result.future;
  }

  void _event(Future<void> Function() action) {
    unawaited(
      action().catchError((Object error, StackTrace stack) {
        debugPrint('Windows background operation failed: $error');
      }),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (isSupported) {
      if (_window.onCloseRequested == _handleClose) {
        _window.onCloseRequested = null;
      }
      // 等待可能在途的托盘创建，避免销毁后又留下晚完成的原生图标。
      _event(() => _pending.then((_) => _destroyTraySafely()));
    }
    super.dispose();
  }
}

class _NativeWindowsBackgroundTray implements WindowsBackgroundTray {
  tray.TrayIcon? _icon;
  tray.Image? _image;
  tray.Menu? _menu;
  tray.MenuItem? _showItem, _exitItem;

  @override
  bool get ready {
    try {
      return _icon?.isVisible() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> show({
    required WindowsBackgroundLabels labels,
    required Future<void> Function() onRestore,
    required Future<void> Function() onExit,
  }) async {
    final existing = _icon;
    if (existing != null) {
      existing.setTooltip(labels.appName);
      _showItem!.label = labels.showWindow;
      _exitItem!.label = labels.exit;
      if (!existing.setVisible(true)) {
        throw StateError('Windows tray is unavailable');
      }
      return;
    }

    try {
      if (!tray.TrayManager.instance.isSupported()) {
        throw StateError('Windows tray is not supported');
      }
      final bytes = await rootBundle.load('assets/icon/icon_windows.png');
      final image = _image = tray.Image.fromBase64(
        base64Encode(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        ),
      );
      final icon = _icon = tray.TrayIcon.createWithIdentifier(
        'com.weijx.fzu_assistant.background',
      );
      final menu = _menu = tray.Menu.create();
      final showItem = _showItem = tray.MenuItem.createWithLabelAndType(
        labels.showWindow,
        tray.MenuItemType.normal,
      );
      final exitItem = _exitItem = tray.MenuItem.createWithLabelAndType(
        labels.exit,
        tray.MenuItemType.normal,
      );
      if (image == null ||
          icon == null ||
          menu == null ||
          showItem == null ||
          exitItem == null) {
        throw StateError('Could not create Windows tray resources');
      }
      icon.icon = image;
      icon.setTooltip(labels.appName);
      menu.addItem(showItem);
      menu.addSeparator();
      menu.addItem(exitItem);
      menu.addListener((event) {
        if (event is tray.MenuItemClickedEvent) {
          if (event.itemId == showItem.id) return _event(onRestore);
          if (event.itemId == exitItem.id) return _event(onExit);
        }
      });
      icon.addListener((event) {
        if (event is tray.TrayIconClickedEvent ||
            event is tray.TrayIconDoubleClickedEvent) {
          return _event(onRestore);
        }
      });
      icon.setContextMenu(menu);
      icon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
      if (menu.itemCount != 3 || !icon.setVisible(true) || !ready) {
        throw StateError('Could not show Windows tray');
      }
    } catch (_) {
      await destroy();
      rethrow;
    }
  }

  Future<void> _event(Future<void> Function() callback) async {
    try {
      await callback();
    } catch (error) {
      debugPrint('Windows tray action failed: $error');
    }
  }

  @override
  Future<void> destroy() async {
    _icon?.setVisible(false);
    _icon?.setContextMenu(null);
    _icon?.dispose();
    _icon = null;
    _menu?.dispose();
    _menu = null;
    _showItem?.dispose();
    _showItem = null;
    _exitItem?.dispose();
    _exitItem = null;
    _image?.dispose();
    _image = null;
  }
}
