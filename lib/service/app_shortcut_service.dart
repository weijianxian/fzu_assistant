import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppShortcutAction { campusCode, schedule }

/// Holds launch intents until the authenticated Home can safely change its tab.
///
/// This service never navigates or creates an academic/SSO session. Home should
/// listen to [pendingAction], consume after login, and handle an already pending
/// action once when it mounts.
class AppShortcutService {
  AppShortcutService();

  static final instance = AppShortcutService();
  static const channel = MethodChannel('com.weijx.fzu_assistant/shortcuts');

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final pendingAction = ValueNotifier<AppShortcutAction?>(null);
  Future<void>? _initializing;

  Future<void> initialize() {
    if (!supported) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'action') _accept(call.arguments);
    });
    try {
      _accept(await channel.invokeMethod<String>('takePendingAction'));
    } on MissingPluginException {
      // Older native hosts and desktop tests may not have this channel.
      _initializing = null;
    } on PlatformException {
      _initializing = null;
    }
  }

  void _accept(Object? value) {
    final action = switch (value) {
      'campusCode' => AppShortcutAction.campusCode,
      'schedule' => AppShortcutAction.schedule,
      _ => null,
    };
    if (action != null) pendingAction.value = action;
  }

  /// Unauthorized consumers leave the action queued for the login flow.
  AppShortcutAction? consumePendingAction({required bool authenticated}) {
    if (!authenticated) return null;
    final action = pendingAction.value;
    pendingAction.value = null;
    return action;
  }

  /// Pass l10n.campusCode when app language changes, including initial startup.
  Future<void> updateLabels({required String campusCode}) async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('setLabels', {'campusCode': campusCode});
    } on MissingPluginException {
      // A missing optional launcher integration must not block the app.
    } on PlatformException {
      // Some launchers can reject dynamic shortcuts.
    }
  }
}
