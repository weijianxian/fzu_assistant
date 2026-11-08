import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/settings/calendar_export_page.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lectures_fixture.dart';
import '../fixtures/reminder_channel.dart';
import '../model/calendar_export_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_QA')) {
      final loader = FontLoader('QaFont')
        ..addFont(
          File('C:/Windows/Fonts/msyh.ttc')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  final api = ApiClient.instance;
  late HttpClientAdapter previousAdapter;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mockReminderChannel();
    previousAdapter = api.dio.httpClientAdapter;
    api.dio.httpClientAdapter = LecturesFixtureAdapter();
    await api.login('20230001', 'test-only', '1234');
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      SpKeys.cacheSchoolCalendar,
      jsonEncode({
        'currentTerm': fixture.term.term,
        'terms': [fixture.term.toJson()],
      }),
    );
    await sp.setString(
      SpKeys.cacheCoursesMap,
      jsonEncode({
        fixture.term.term: {
          'courses': [
            fixture.sample(rawExamTime: '2026年11月13日14:00-16:00旗山').toJson(),
          ],
        },
      }),
    );
  });
  tearDown(() async {
    await api.clearSession();
    api.dio.httpClientAdapter = previousAdapter;
    debugDefaultTargetPlatformOverride = null;
  });

  for (final language in ['zh', 'en']) {
    testWidgets('窄屏 $language 日历预览、包含考试和提醒选项可用', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(320, 920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettings()
        ..selectedSemesterKey.value = fixture.term.term;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        AppSettingsProvider(
          settings: settings,
          child: MaterialApp(
            theme: const bool.fromEnvironment('CAPTURE_QA')
                ? ThemeData(fontFamily: 'QaFont')
                : null,
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: boundaryKey,
              child: const CalendarExportPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CalendarExportPage)),
      )!;
      expect(find.text(l10n.calendarExportEventCount(3)), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text(l10n.calendarExportEventCount(2)), findsOneWidget);
      expect(find.text(l10n.calendarExportReminderMinutes(15)), findsOneWidget);
      final reminder = find.widgetWithText(
        ListTile,
        l10n.calendarExportReminder,
      );
      await tester.scrollUntilVisible(
        reminder.hitTestable(),
        150,
        scrollable: find.descendant(
          of: find.byType(CalendarExportPage),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(reminder.hitTestable(), findsOneWidget);
      await tester.tap(reminder);
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      final thirtyMinutes = find.widgetWithText(
        RadioListTile<int>,
        l10n.calendarExportReminderMinutes(30),
      );
      await tester.scrollUntilVisible(
        thirtyMinutes.hitTestable(),
        120,
        scrollable: find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(thirtyMinutes.hitTestable(), findsOneWidget);
      await tester.tap(thirtyMinutes);
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(find.text(l10n.calendarExportReminderMinutes(30)), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_QA')) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/calendar-export-$language.png')
              .writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
