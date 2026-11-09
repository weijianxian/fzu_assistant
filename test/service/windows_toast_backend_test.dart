import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Intentionally verify the installed federated plugin's actual XML serializer,
// which is not re-exported by the facade. No extra production dependency.
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_windows/src/details/notification_to_xml.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/course_live_update.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/service/windows_course_notifications.dart';
import 'package:fzu_assistant/service/windows_toast_backend.dart';

class _WindowsPlugin extends FlutterLocalNotificationsPlatform
    implements FlutterLocalNotificationsWindows {
  WindowsInitializationSettings? settings;
  DidReceiveNotificationResponseCallback? activate;
  String? xml, payload;
  Map<String, String>? initialBindings, updatedBindings;
  int? shownId, updatedId;
  int clears = 0;
  int shows = 0;
  bool initializeResult = true;
  NotificationUpdateResult updateResult = NotificationUpdateResult.success;

  @override
  Future<bool> initialize({
    required WindowsInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    this.settings = settings;
    activate = onDidReceiveNotificationResponse;
    return initializeResult;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  }) async {
    shows++;
    shownId = id;
    this.payload = payload;
    xml = notificationToXml(
      title: title,
      body: body,
      payload: payload,
      notificationDetails: notificationDetails,
    );
    initialBindings = {
      ...?notificationDetails?.bindings,
      for (final progress
          in notificationDetails?.progressBars ?? <WindowsProgressBar>[])
        ...progress.data,
    };
  }

  @override
  Future<NotificationUpdateResult> updateBindings({
    required int id,
    required Map<String, String> bindings,
  }) async {
    updatedId = id;
    updatedBindings = bindings;
    return updateResult;
  }

  @override
  Future<void> periodicallyShow({
    required int id,
    String? title,
    String? body,
    String? payload,
    required RepeatInterval repeatInterval,
    WindowsNotificationDetails? notificationDetails,
  }) async => throw UnsupportedError('No periodic Windows notifications');

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    String? payload,
    required dynamic scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
    WindowsNotificationDetails? notificationDetails,
  }) async =>
      throw UnsupportedError('Plans remain in the resident app process');

  @override
  Future<void> cancelAll() async => clears++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _WindowsPlugin plugin;
  late PluginWindowsToastBackend backend;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    plugin = _WindowsPlugin();
    FlutterLocalNotificationsPlatform.instance = plugin;
    backend = PluginWindowsToastBackend(
      appName: 'FZU Notification Contract Test',
      appUserModelId: 'com.weijx.fzu_assistant.tests',
      activationGuid: '8f881256-c8ce-4bbc-b4a2-be058e30d45d',
      iconPath: r'C:\test data\icon_windows.png',
    );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'native initialization failure is reported without clearing toasts',
    () async {
      plugin.initializeResult = false;
      await expectLater(
        backend.initialize(() async {}),
        throwsA(isA<StateError>()),
      );
      expect(plugin.clears, 0);
      expect(plugin.shows, 0);
    },
  );

  test('injected identity and image path reach Windows initializer and click callback', () async {
    var restored = 0;
    await backend.initialize(() async => restored++);
    expect(plugin.settings!.appName, 'FZU Notification Contract Test');
    expect(plugin.settings!.appUserModelId, 'com.weijx.fzu_assistant.tests');
    expect(plugin.settings!.guid, '8f881256-c8ce-4bbc-b4a2-be058e30d45d');
    expect(plugin.settings!.iconPath, endsWith('icon_windows.png'));
    expect(plugin.clears, 1);
    plugin.activate!(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: 'schedule',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(restored, 1);
  });

  test('actual plugin serializer binds body, progress value and countdown to matching data keys', () async {
    await backend.initialize(() async {});
    const toast = WindowsCourseToast(
      id: 5310,
      title: 'Class in progress',
      body: 'Mathematics & Physics <A>\n08:20–09:55 (UTC+8)',
      progress: 0.25,
      progressLabel: '30:00',
      progressStatus: 'Class in progress',
    );
    await backend.show(toast);
    expect(plugin.xml, contains('template="ToastGeneric"'));
    expect(plugin.xml, contains('<text>{course-body}</text>'));
    expect(plugin.xml, contains('launch="schedule"'));
    expect(plugin.xml, contains('value="{course-progressValue}"'));
    expect(
      plugin.xml,
      contains('valueStringOverride="{course-progressString}"'),
    );
    expect(plugin.initialBindings, {
      'course-body': toast.body,
      'course-progressValue': '0.25',
      'course-progressString': '30:00',
    });
    expect(plugin.shownId, 5310);
    expect(plugin.payload, 'schedule');
    await backend.update(
      const WindowsCourseToast(
        id: 5310,
        title: 'Class in progress',
        body: 'Mathematics & Physics <A>\n08:20–09:55 (UTC+8)',
        progress: 0.5,
        progressLabel: '20:00',
      ),
    );
    expect(plugin.updatedId, 5310);
    expect(plugin.updatedBindings!['course-progressValue'], '0.5');
    expect(plugin.updatedBindings!['course-progressString'], '20:00');
    expect(plugin.updatedBindings!['course-body'], toast.body);
    expect(backend.lastUpdateResult, NotificationUpdateResult.success);
    expect(plugin.clears, 1); // Updating data must not remove/recreate toasts.
  });

  test('next-class countdown and session progress update without an Android chronometer', () async {
    final now = DateTime.utc(2026, 11, 9);
    final frame = CourseLiveUpdateFrame(CourseLiveUpdatePreview.nextClass, [
      NextCourseWidgetEntry(
        name: 'Next',
        location: 'A',
        start: now.add(const Duration(minutes: 5)),
        end: now.add(const Duration(minutes: 50)),
        startClass: 1,
        endClass: 2,
        week: 1,
      ),
    ]);
    await backend.initialize(() async {});
    final first = WindowsCourseNotifications.courseToast(frame, now: now);
    final later = WindowsCourseNotifications.courseToast(
      frame,
      now: now.add(const Duration(minutes: 1)),
    );
    await backend.show(first);
    await backend.update(later);
    expect(plugin.xml, contains('<progress'));
    expect(plugin.initialBindings!['course-progressValue'], '0.0');
    expect(plugin.initialBindings!['course-body'], contains('Starts in 05:00'));
    expect(plugin.updatedBindings!['course-progressValue'], '0.0');
    expect(plugin.updatedBindings!['course-body'], contains('Starts in 04:00'));
    expect(plugin.xml, isNot(contains('promoted')));
    expect(plugin.xml, isNot(contains('chronometer')));
  });
  test(
    'native error is observable while notFound keeps dismissal respected',
    () async {
      await backend.initialize(() async {});
      const toast = WindowsCourseToast(
        id: 5310,
        title: 'In progress',
        body: 'A',
        progress: 0.25,
      );
      await backend.show(toast);
      plugin.updateResult = NotificationUpdateResult.error;
      await expectLater(backend.update(toast), throwsStateError);
      expect(backend.lastUpdateResult, NotificationUpdateResult.error);
      plugin.updateResult = NotificationUpdateResult.notFound;
      await backend.update(toast);
      expect(backend.lastUpdateResult, NotificationUpdateResult.notFound);
      expect(plugin.shows, 1);
      expect(plugin.clears, 1);
    },
  );
}
