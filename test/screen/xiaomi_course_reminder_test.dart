import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/dev/dev_tool.dart';
import 'package:fzu_assistant/screen/settings/course_reminder_settings_page.dart';
import 'package:fzu_assistant/screen/settings/settings_page.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(AppSettings settings, Widget child) => AppSettingsProvider(
  settings: settings,
  child: MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

Future<void> _settleHost(WidgetTester tester) async {
  // Platform replies may complete outside the test's fake clock.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

Future<void> _tapHost(WidgetTester tester, Finder target) async {
  // Keep the scheduler's shared initialization and queue in the real zone,
  // rather than attaching them to an individual test's fake clock.
  await tester.runAsync(() async {
    await tester.tap(target);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await _settleHost(tester);
}

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final methods = <String>[];
  final alarmMethods = <String>[];
  late Completer<Map<String, String>> device;
  setUp(() {
    methods.clear();
    alarmMethods.clear();
    CourseReminderService.instance.error.value = false;
    device = Completer<Map<String, String>>();
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(CourseReminderService.channel, (
      call,
    ) async {
      methods.add(call.method);
      if (call.method == 'deviceInfo') return device.future;
      if (call.method == 'permissions') {
        return {'notifications': true, 'exact': true};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
      call,
    ) async {
      alarmMethods.add(call.method);
      return true;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => true,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(CourseReminderService.channel, null);
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      null,
    );
  });

  testWidgets(
    'pending brand detection does not block permissions and Xiaomi only shows an advisory',
    (tester) async {
      _size(tester);
      final settings = AppSettings();
      await settings.load();
      settings.courseReminderEnabled.value = true;
      await tester.pumpWidget(
        _app(settings, const CourseReminderSettingsPage()),
      );
      await _settleHost(tester);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNotNull,
      );
      expect(methods, contains('permissions'));
      expect(settings.courseReminderEnabled.value, isTrue);
      device.complete({'manufacturer': 'Xiaomi', 'brand': 'POCO'});
      await _settleHost(tester);
      expect(find.text('系统限制提醒'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('系统限制提醒'), matching: find.byType(Card)),
        findsOneWidget,
      );
      expect(
        find.text('由于 MIUI / HyperOS 限制了应用在后台推送本地通知，该功能不可用，您可尝试在 root 后解锁此限制。'),
        findsOneWidget,
      );
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.onChanged, isNotNull);
      expect(toggle.value, isTrue);
      expect(settings.courseReminderEnabled.value, isTrue);
      expect(find.byIcon(Icons.open_in_new), findsNWidgets(3));
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, '提醒时间')).onTap,
        isNotNull,
      );
      await _tapHost(tester, find.widgetWithText(ListTile, '通知权限'));
      expect(methods, contains('requestNotifications'));
      expect(settings.courseReminderEnabled.value, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'other Android devices retain permission and enabled reminder controls',
    (tester) async {
      _size(tester);
      final settings = AppSettings();
      await settings.load();
      device.complete({'manufacturer': 'Google', 'brand': 'google'});
      await tester.pumpWidget(
        _app(settings, const CourseReminderSettingsPage()),
      );
      await _settleHost(tester);
      expect(find.text('系统限制提醒'), findsNothing);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNotNull,
      );
      expect(methods, contains('permissions'));
      expect(find.byIcon(Icons.open_in_new), findsNWidgets(3));
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'main settings describes reminder features without a device advisory',
    (tester) async {
      _size(tester);
      final settings = AppSettings();
      await settings.load();
      device.complete({'manufacturer': 'Xiaomi', 'brand': 'redmi'});
      await tester.pumpWidget(_app(settings, const SettingsPage()));
      await _settleHost(tester);
      await tester.scrollUntilVisible(find.text('每天晚上提醒明天最早的课程'), 250);
      expect(find.text('每天晚上提醒明天最早的课程'), findsOneWidget);
      expect(find.text('系统限制提醒'), findsNothing);
      expect(methods, isNot(contains('deviceInfo')));
      expect(find.text('早课提醒'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'failed brand detection does not block permission or reminder controls',
    (tester) async {
      _size(tester);
      messenger.setMockMethodCallHandler(CourseReminderService.channel, (
        call,
      ) async {
        methods.add(call.method);
        if (call.method == 'deviceInfo') {
          throw PlatformException(code: 'device_info_failed');
        }
        if (call.method == 'permissions') {
          return {'notifications': true, 'exact': true};
        }
        return null;
      });
      final settings = AppSettings();
      await settings.load();
      await tester.pumpWidget(
        _app(settings, const CourseReminderSettingsPage()),
      );
      await _settleHost(tester);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNotNull,
      );
      expect(find.text('系统限制提醒'), findsNothing);
      expect(methods, contains('permissions'));
      expect(find.text('重试'), findsNothing);
      await _tapHost(tester, find.widgetWithText(ListTile, '通知权限'));
      expect(methods, contains('requestNotifications'));
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'developer test uses the plugin without brand detection or restrictions',
    (tester) async {
      _size(tester);
      final settings = AppSettings();
      await settings.load();
      await tester.pumpWidget(_app(settings, const DevToolPage()));
      final test = find.widgetWithText(ListTile, 'Notify in one minute');
      expect(tester.widget<ListTile>(test).onTap, isNotNull);
      await _settleHost(tester);
      expect(tester.widget<ListTile>(test).onTap, isNotNull);
      expect(
        find.text(
          'Schedule an exact alarm to test background or lock-screen delivery.',
        ),
        findsOneWidget,
      );
      expect(methods, isNot(contains('permissions')));
      expect(methods, isNot(contains('deviceInfo')));
      await _tapHost(tester, test);
      expect(methods, contains('permissions'));
      expect(methods, isNot(contains('deviceInfo')));
      expect(alarmMethods, contains('Alarm.oneShotAt'));
      expect(find.text('Notification scheduled in one minute'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
