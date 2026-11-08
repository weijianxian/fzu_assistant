import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/windows_background_service.dart';
import 'package:window_manager/window_manager.dart';

class FakeWindowsCloseRequest extends Fake implements EventRequest {
  bool cancelled = false;

  @override
  bool cancel() => cancelled = true;
}

class FakeBackgroundWindow extends Fake implements Window {
  final calls = <String>[];
  FutureOr<void> Function(WindowEvent)? listener;
  bool hideFails = false;
  bool showFails = false;

  @override
  bool isFocused = true;
  @override
  bool isMaximized = false;
  @override
  bool isFullScreen = false;
  @override
  bool isMinimized = false;
  @override
  bool isVisible = true;

  @override
  ListenerId addListener(FutureOr<void> Function(WindowEvent) callback) {
    listener = callback;
    return 1;
  }

  @override
  bool removeListener(ListenerId id) {
    listener = null;
    return true;
  }

  FakeWindowsCloseRequest requestClose() {
    final request = FakeWindowsCloseRequest();
    listener?.call(WindowCloseRequestedEvent(windowId: 1, request: request));
    return request;
  }

  @override
  void hide() {
    calls.add('hide');
    if (hideFails) throw StateError('Native hide failed');
    isVisible = false;
  }

  @override
  void show() {
    calls.add('show');
    if (showFails) throw StateError('Native show failed');
    isVisible = true;
  }

  @override
  void focus() {
    calls.add('focus');
    isFocused = true;
  }

  @override
  void restore() {
    calls.add('restore');
    isMinimized = false;
  }
}

class FakeBackgroundTray implements WindowsBackgroundTray {
  final calls = <String>[];
  final events = <String>[];
  bool creationFails = false;
  bool remainUnavailable = false;
  @override
  bool ready = false;
  WindowsBackgroundLabels? labels;
  Future<void> Function()? onRestore, onExit;
  Future<void>? creationWait;

  @override
  Future<void> show({
    required WindowsBackgroundLabels labels,
    required Future<void> Function() onRestore,
    required Future<void> Function() onExit,
  }) async {
    calls.add('show');
    await creationWait;
    if (creationFails) throw StateError('Native tray failed');
    this.labels = labels;
    this.onRestore = onRestore;
    this.onExit = onExit;
    ready = !remainUnavailable;
  }

  @override
  Future<void> destroy() async {
    calls.add('destroy');
    events.add('tray.destroy');
    ready = false;
  }
}
