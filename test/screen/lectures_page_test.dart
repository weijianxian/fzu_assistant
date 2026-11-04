import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/academic/lectures_page.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lectures_fixture.dart';
import '../fixtures/reminder_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient.instance;
  late HttpClientAdapter previousAdapter;
  late LecturesFixtureAdapter adapter;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    mockReminderChannel();
    previousAdapter = api.dio.httpClientAdapter;
    adapter = LecturesFixtureAdapter();
    api.dio.httpClientAdapter = adapter;
    await api.login('20230001', 'fixture-password', '1234');
    adapter.requests.clear();
  });

  tearDown(() async {
    await api.clearSession();
    api.dio.httpClientAdapter = previousAdapter;
  });

  Widget app({
    String locale = 'zh',
    double textScale = 1,
    void Function(WebViewArgs args)? onOpenOfficial,
  }) => MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const LecturesPage(),
    onGenerateRoute: (settings) {
      expect(settings.name, AppRoutes.webview);
      onOpenOfficial?.call(settings.arguments as WebViewArgs);
      return MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('official-page-fixture')),
      );
    },
  );

  for (final locale in ['zh', 'en']) {
    testWidgets('renders all lecture fields and Beijing time ($locale)', (
      tester,
    ) async {
      await tester.pumpWidget(app(locale: locale));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LecturesPage)),
      )!;
      expect(find.byType(AppScaffold), findsOneWidget);
      expect(find.byType(ToolPageWrapper), findsOneWidget);
      expect(find.byType(AppListView), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      for (final text in [
        l10n.jiaxiLectures,
        l10n.lectureCategory,
        l10n.lectureIssueNumber,
        l10n.lectureSpeaker,
        l10n.lectureDateTime,
        l10n.lectureLocation,
        l10n.lectureAttendance,
        '人工智能与校园生活',
        '科技',
        '36',
        '李老师',
        '2026-11-05 19:30',
        '旗山校区图书馆报告厅',
        '已听取',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('official link preserves academic cookie/session injection', (
    tester,
  ) async {
    WebViewArgs? opened;
    await tester.pumpWidget(app(onOpenOfficial: (args) => opened = args));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LecturesPage)),
    )!;
    await tester.tap(find.text(l10n.lecturesOpenOfficial));
    await tester.pumpAndSettle();
    expect(opened, isNotNull);
    expect(opened!.url, AcademicService.lecturesUrl);
    expect(opened!.title, l10n.jiaxiLectures);
    expect(opened!.injectCookies, isTrue);
    expect(opened!.injectSsoCookies, isFalse);
    expect(find.text('official-page-fixture'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refresh keeps previous registrations visible until replacement',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LecturesPage)),
      )!;
      final pending = Completer<ResponseBody>();
      adapter.nextLectureResponse = pending.future;
      await tester.tap(find.byTooltip(l10n.refresh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('人工智能与校园生活'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.complete(
        adapter.htmlResponse(
          LecturesFixtureAdapter.registeredHtml.replaceAll(
            '人工智能与校园生活',
            '更新后的讲座',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('人工智能与校园生活'), findsNothing);
      expect(find.text('更新后的讲座'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed refresh retains old data with a visible retry', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LecturesPage)),
    )!;
    adapter.failLectureRequests = true;
    await tester.tap(find.byTooltip(l10n.refresh));
    await tester.pumpAndSettle();
    expect(find.text('人工智能与校园生活'), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
    expect(find.text(l10n.lecturesEmpty), findsNothing);
    adapter.failLectureRequests = false;
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();
    expect(find.text(l10n.retry), findsNothing);
    expect(find.text('人工智能与校园生活'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty records still expose the official registration action', (
    tester,
  ) async {
    adapter.lecturesHtml =
        '<table id="ContentPlaceHolder1_DataList_xxk"></table>';
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LecturesPage)),
    )!;
    expect(find.text(l10n.lecturesEmpty), findsOneWidget);
    expect(find.text(l10n.lecturesOpenOfficial), findsOneWidget);
    expect(find.byType(Table), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'initial error remains distinct from an empty registration list',
    (tester) async {
      adapter.lecturesHtml = '<p>服务暂时不可用</p>';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LecturesPage)),
      )!;
      expect(find.textContaining('未找到已报名讲座表格'), findsOneWidget);
      expect(find.text(l10n.lecturesEmpty), findsNothing);
      expect(find.text(l10n.lecturesOpenOfficial), findsOneWidget);
      adapter.lecturesHtml = LecturesFixtureAdapter.registeredHtml;
      await tester.tap(find.byTooltip(l10n.refresh));
      await tester.pumpAndSettle();
      expect(find.text('人工智能与校园生活'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown dates retain the original text and all other fields', (
    tester,
  ) async {
    adapter.lecturesHtml = LecturesFixtureAdapter.registeredHtml.replaceAll(
      '2026-11-05&nbsp;&nbsp;19：30',
      '待定',
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('待定'), findsOneWidget);
    expect(find.text('人工智能与校园生活'), findsOneWidget);
    expect(find.textContaining('1970'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English metadata fits a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(locale: 'en', textScale: 1.5));
    await tester.pumpAndSettle();
    expect(find.text('人工智能与校园生活'), findsOneWidget);
    expect(find.text('2026-11-05 19:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
