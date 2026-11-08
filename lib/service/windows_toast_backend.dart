import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The Windows-only boundary. No Android plugin or MethodChannel is used here.
abstract interface class WindowsToastBackend {
  Future<void> initialize(Future<void> Function() onActivate);
  Future<void> show(WindowsCourseToast toast);
  Future<void> update(WindowsCourseToast toast);
  Future<void> clear();
}

class WindowsCourseToast {
  const WindowsCourseToast({
    required this.id,
    required this.title,
    required this.body,
    this.progress,
    this.progressLabel,
    this.progressStatus,
  });

  final int id;
  final String title, body;
  final double? progress;
  final String? progressLabel, progressStatus;

  Map<String, String> get bindings => {
    'course-body': body,
    if (progress != null) ...{
      'course-progressValue': progress!.clamp(0, 1).toString(),
      'course-progressString': progressLabel ?? '',
    },
  };

  WindowsNotificationDetails get details => WindowsNotificationDetails(
    bindings: bindings,
    duration: WindowsNotificationDuration.long,
    progressBars: [
      if (progress != null)
        WindowsProgressBar(
          id: 'course',
          status: progressStatus ?? title,
          value: progress!.clamp(0, 1),
          label: progressLabel,
        ),
    ],
  );
}

/// The bundled Windows plugin registers a stable AUMID and COM activator for
/// both the Inno installer and portable build. It is initialized exactly once.
class PluginWindowsToastBackend implements WindowsToastBackend {
  PluginWindowsToastBackend({
    this.appName = '福大助手',
    this.appUserModelId = 'com.weijx.fzu_assistant',
    this.activationGuid = 'e48172c8-3c24-4c88-8d66-a307940798fb',
    this.iconPath,
  });

  final String appName, appUserModelId, activationGuid;
  final String? iconPath;
  FlutterLocalNotificationsPlugin? _plugin;
  NotificationUpdateResult? _lastUpdateResult;

  /// Actual native Update() result. notFound can mean user dismissal.
  NotificationUpdateResult? get lastUpdateResult => _lastUpdateResult;

  static String? bundledIconPath() {
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final png = File.fromUri(
      executableDirectory.uri.resolve(
        'data/flutter_assets/assets/icon/icon_windows.png',
      ),
    );
    return png.existsSync() ? png.path : null;
  }

  @override
  Future<void> initialize(Future<void> Function() onActivate) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final windows = plugin
        .resolvePlatformSpecificImplementation<
          FlutterLocalNotificationsWindows
        >();
    if (windows == null) {
      throw StateError('Windows notification plugin is unavailable');
    }
    final initialized = await plugin.initialize(
      settings: InitializationSettings(
        windows: WindowsInitializationSettings(
          appName: appName,
          appUserModelId: appUserModelId,
          guid: activationGuid,
          iconPath: iconPath ?? bundledIconPath(),
        ),
      ),
      onDidReceiveNotificationResponse: (_) async {
        await onActivate();
      },
    );
    if (initialized != true) {
      throw StateError('Cannot initialize Windows notifications');
    }
    _plugin = plugin;
    // Crash/relaunch must not retain a former account's course toast.
    await clear();
  }

  @override
  Future<void> show(WindowsCourseToast toast) => _plugin!.show(
    id: toast.id,
    title: toast.title,
    body: '{course-body}',
    payload: 'schedule',
    notificationDetails: NotificationDetails(windows: toast.details),
  );

  @override
  Future<void> update(WindowsCourseToast toast) async {
    final windows = _plugin!
        .resolvePlatformSpecificImplementation<
          FlutterLocalNotificationsWindows
        >()!;
    // Data-only updates do not create another banner, replay the sound or
    // resurrect a toast the user dismissed. The next course stage alerts again.
    final result = await windows.updateBindings(
      id: toast.id,
      bindings: toast.bindings,
    );
    _lastUpdateResult = result;
    if (result == NotificationUpdateResult.error) {
      throw StateError('Windows could not update the course notification');
    }
  }

  @override
  Future<void> clear() async {
    // v4 cannot remove shown toasts by ID without MSIX identity. cancelAll uses
    // ToastNotificationManager.History.Clear(AUMID) for unpackaged apps too.
    // This service owns ALL notifications under this application identity.
    await _plugin?.cancelAll();
  }
}
