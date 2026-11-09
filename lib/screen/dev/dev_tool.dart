import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/service/course_live_update_service.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/windows_course_notifications.dart';
import 'package:fzu_assistant/common/widgets.dart';

import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/my/about/widgets/update_dialog.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/update_service.dart';

const _tools = [
  (Icons.storage, 'SharedPreferences', AppRoutes.devSharedPrefs),
  (Icons.lock, 'SecureStorage', AppRoutes.devSecureStorage),
];

const _liveUpdatePreviews = [
  (
    CourseLiveUpdatePreview.inProgress,
    Icons.school_outlined,
    'Class in progress',
    'Preview a full morning with course blocks and a break',
  ),
  (
    CourseLiveUpdatePreview.ended,
    Icons.task_alt,
    'Class ended',
    'Replace the Live Update with a completed-class notification',
  ),
  (
    CourseLiveUpdatePreview.nextClass,
    Icons.upcoming_outlined,
    'Next class',
    'Preview a five-minute countdown with the next classroom',
  ),
];

class DevToolPage extends HookWidget {
  const DevToolPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationBusy = useState(false);
    final promotion = useAsyncData(CourseLiveUpdateService.promotionEnabled);
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed &&
          CourseLiveUpdateService.supported) {
        unawaited(promotion.refresh());
      }
    });

    Future<void> notificationAction(Future<String?> Function() action) async {
      if (notificationBusy.value) return;
      notificationBusy.value = true;
      try {
        final message = await action();
        if (!context.mounted || message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Notification test failed: $error')),
          );
      } finally {
        if (context.mounted) notificationBusy.value = false;
      }
    }

    return AppScaffold(
      appBar: AppBar(title: Text('Dev Tools')),
      body: AppListView(
        children: [
          if (CourseReminderService.androidSupported)
            AppSection.list(
              title: 'Notifications',
              children: [
                ListTile(
                  leading: const Icon(Icons.notification_add_outlined),
                  title: const Text('Notify in one minute'),
                  subtitle: const Text(
                    'Schedule an exact alarm to test background or lock-screen delivery.',
                  ),
                  onTap: notificationBusy.value
                      ? null
                      : () => notificationAction(() async {
                          await CourseReminderService.instance
                              .testNotification();
                          return 'Notification scheduled in one minute';
                        }),
                ),
                for (final preview in _liveUpdatePreviews)
                  ListTile(
                    leading: Icon(preview.$2),
                    title: Text(preview.$3),
                    subtitle: Text(preview.$4),
                    onTap: notificationBusy.value
                        ? null
                        : () => notificationAction(() async {
                            final promoted =
                                await CourseLiveUpdateService.showPreview(
                                  preview.$1,
                                );
                            await promotion.refresh();
                            if (preview.$1 == CourseLiveUpdatePreview.ended) {
                              return 'Class-ended notification sent';
                            }
                            return promoted
                                ? 'Live Update requested'
                                : 'Preview sent as a standard notification; Live Updates are unavailable or disabled';
                          }),
                  ),
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('Test all styles in 2 minutes'),
                  subtitle: const Text(
                    'In progress → next class → in progress → morning finished',
                  ),
                  onTap: notificationBusy.value
                      ? null
                      : () => notificationAction(() async {
                          await CourseLiveUpdateService.startPreviewSequence();
                          await promotion.refresh();
                          return 'Preview started: now, 30s, 60s and 110s';
                        }),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: const Text('Clear course preview'),
                  subtitle: const Text(
                    'Stop the test sequence and remove its notification',
                  ),
                  onTap: notificationBusy.value
                      ? null
                      : () => notificationAction(() async {
                          await CourseLiveUpdateService.clearPreview();
                          return 'Course preview cleared';
                        }),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Live Update settings'),
                  subtitle: Text(
                    promotion.loading
                        ? 'Checking availability'
                        : promotion.error != null
                        ? 'Could not check availability'
                        : promotion.data == true
                        ? 'Allowed by Android'
                        : 'Unavailable or disabled; previews use standard notifications',
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: notificationBusy.value
                      ? null
                      : () => notificationAction(() async {
                          await CourseLiveUpdateService.openSettings();
                          return null;
                        }),
                ),
              ],
            ),
          if (WindowsCourseNotifications.supported)
            AppSection.list(
              title: 'Windows Notifications',
              children: [
                ListTile(
                  leading: const Icon(Icons.notification_add_outlined),
                  title: const Text('Send a toast now'),
                  subtitle: const Text(
                    'Click the notification to restore the existing window',
                  ),
                  onTap: notificationBusy.value
                      ? null
                      : () => notificationAction(() async {
                          await WindowsCourseNotifications.instance
                              .testNotification();
                          return 'Windows toast sent';
                        }),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Notify in one minute'),
                  subtitle: const Text(
                    'Keep the app running or close to tray to test background delivery',
                  ),
                  onTap: notificationBusy.value
                      ? null
                      : () => notificationAction(() async {
                          await WindowsCourseNotifications.instance
                              .testNotification(
                                delay: const Duration(minutes: 1),
                              );
                          return 'Windows toast scheduled in one minute';
                        }),
                ),
                for (final preview in _liveUpdatePreviews)
                  ListTile(
                    leading: Icon(preview.$2),
                    title: Text(preview.$3),
                    subtitle: Text(switch (preview.$1) {
                      CourseLiveUpdatePreview.inProgress =>
                        'Preview a Windows course progress toast',
                      CourseLiveUpdatePreview.nextClass =>
                        'Preview the next course and classroom',
                      CourseLiveUpdatePreview.ended =>
                        'Preview a finished morning notification',
                    }),
                    onTap: notificationBusy.value
                        ? null
                        : () => notificationAction(() async {
                            await WindowsCourseNotifications.instance
                                .showPreview(preview.$1);
                            return 'Windows course toast sent';
                          }),
                  ),
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('Test all styles in 2 minutes'),
                  subtitle: const Text(
                    'In progress → next class → in progress → morning finished',
                  ),
                  onTap: notificationBusy.value
                      ? null
                      : () => notificationAction(() async {
                          await WindowsCourseNotifications.instance
                              .startPreviewSequence();
                          return 'Windows preview started: now, 30s, 60s and 110s';
                        }),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: const Text('Clear course preview'),
                  subtitle: const Text(
                    'Stop testing and restore the current course notification',
                  ),
                  onTap: notificationBusy.value
                      ? null
                      : () => notificationAction(() async {
                          await WindowsCourseNotifications.instance
                              .clearPreview();
                          return 'Windows preview cleared';
                        }),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Windows notification settings'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => notificationAction(() async {
                    await WindowsCourseNotifications.instance.openSettings();
                    return null;
                  }),
                ),
              ],
            ),
          if (CourseReminderService.supported) const AppDivider(),
          AppSection.list(
            title: 'Learning Center',
            children: [
              ChevronListTile(
                leading: const Icon(Icons.science_outlined),
                title: Text('Learning Center API Debug'),
                onTap: () => context.pushNamed(AppRoutes.devLearningCenter),
              ),
            ],
          ),
          const AppDivider(),
          AppSection.list(
            title: 'Storage',
            children: [
              ..._tools.map(
                (tool) => ChevronListTile(
                  leading: Icon(tool.$1),
                  title: Text(tool.$2),
                  onTap: () => context.pushNamed(tool.$3),
                ),
              ),
            ],
          ),
          const AppDivider(),
          AppSection.list(
            title: 'Session',
            children: [
              ListTile(
                leading: const Icon(Icons.cookie_outlined),
                title: const Text('Expire Cookies'),
                subtitle: const Text(
                  'Clear academic session cookies to test automatic re-login and request retry',
                ),
                onTap: () async {
                  try {
                    await ApiClient.instance.expireCookiesForDebug();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cookies have been expired'),
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to expire cookies: $error'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Re-login'),
                subtitle: const Text(
                  'Sign in again with the credentials stored on this device',
                ),
                onTap: () async {
                  final success = await ApiClient.instance.refreshSession();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'Re-login succeeded' : 'Re-login failed',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const AppDivider(),
          AppSection.list(
            title: 'Interface & Updates',
            children: [
              ListTile(
                leading: const Icon(Icons.drag_handle),
                title: const Text('Native BottomSheet'),
                onTap: () => showHalfScreenSheet(
                  context,
                  builder: (controller) => AppListView.grouped(
                    controller: controller,
                    itemCount: 20,
                    itemBuilder: (context, index) =>
                        ListTile(title: Text('Item ${index + 1}')),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.system_update),
                title: const Text('Force Update Dialog'),
                subtitle: const Text('Fetch latest release and show installer'),
                onTap: () async {
                  final release = await UpdateService().fetchLatestRelease();
                  if (!context.mounted) return;

                  if (release == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to fetch latest release'),
                      ),
                    );
                    return;
                  }

                  showUpdateSheet(
                    context,
                    release: release,
                    onSkip: () {},
                    onSkipForever: () {},
                  );
                },
              ),
            ],
          ),
          const AppDivider(),
          AppSection.list(
            title: 'WebView',
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('WebView (with Cookie)'),
                onTap: () {
                  final id = ApiClient.instance.userId;
                  if (id == null) return;
                  context.pushNamed(
                    AppRoutes.webview,
                    arguments: WebViewArgs(
                      url:
                          'https://jwcjwxt2.fzu.edu.cn:81/jcxx/xsxx/StudentInformation.aspx?id=$id',
                      injectCookies: true,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.css),
                title: const Text('Test CSS/JS Injection'),
                onTap: () => context.pushNamed(
                  AppRoutes.webview,
                  arguments: const WebViewArgs(
                    url: 'https://example.com/',
                    injectCookies: false,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('WebView (no Cookie)'),
                onTap: () {
                  final id = ApiClient.instance.userId;
                  if (id == null) return;
                  context.pushNamed(
                    AppRoutes.webview,
                    arguments: WebViewArgs(
                      url:
                          'https://jwcjwxt2.fzu.edu.cn:81/jcxx/xsxx/StudentInformation.aspx?id=$id',
                      injectCookies: false,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
