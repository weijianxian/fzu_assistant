import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/job_fair.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/job_fair/job_fair_page.dart';
import 'package:fzu_assistant/service/api/job_fair_service.dart';

JobFairMonthData _events(JobFairMonth month, {String? title}) =>
    JobFairMonthData(
      month: month,
      events: [
        JobFair(
          id: 'event-${month.apiValue}',
          title: title ?? '活动 ${month.apiValue}',
          place: '旗山校区',
          startsAt: DateTime.utc(month.year, month.month, 6, 6, 30),
          type: JobFairType.careerTalk,
        ),
      ],
    );

class _Service extends JobFairService {
  final requests = <JobFairMonth>[];
  final replies = <Future<JobFairMonthData> Function(JobFairMonth)>[];

  @override
  Future<JobFairMonthData> getMonth(JobFairMonth month) {
    requests.add(month);
    return replies.isEmpty
        ? Future.value(_events(month))
        : replies.removeAt(0)(month);
  }
}

DateTime _now() => DateTime.utc(2026, 11, 5, 2);

Widget _app(
  JobFairService service, {
  Locale locale = const Locale('zh'),
  WidgetBuilder? details,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routes: {
    AppRoutes.webview: details ?? (_) => const Scaffold(body: Text('details')),
  },
  home: JobFairPage(service: service, now: _now),
);

void main() {
  late _Service service;
  setUp(() => service = _Service());
  tearDown(() => service.close());

  testWidgets(
    'shows Beijing event time and opens details with no cookie injection',
    (tester) async {
      WebViewArgs? arguments;
      await tester.pumpWidget(
        _app(
          service,
          details: (context) {
            arguments =
                ModalRoute.of(context)!.settings.arguments! as WebViewArgs;
            return const Scaffold(body: Text('details'));
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('招聘会／宣讲会'), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
      expect(find.text('未开始'), findsOneWidget);
      expect(find.text('宣讲会 · 旗山校区'), findsOneWidget);
      await tester.tap(find.text('活动 2026/11'));
      await tester.pumpAndSettle();
      expect(arguments, isNotNull);
      expect(arguments!.injectCookies, isFalse);
      expect(arguments!.injectSsoCookies, isFalse);
      final uri = Uri.parse(arguments!.url);
      expect(JobFair.isOfficialDetailUri(uri), isTrue);
      expect(uri.queryParameters['id'], 'event-2026/11');
    },
  );

  testWidgets('refresh keeps existing events while loading and after failure', (
    tester,
  ) async {
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final pending = Completer<JobFairMonthData>();
    service.replies.add((_) => pending.future);
    await tester.tap(find.byTooltip('刷新'));
    await tester.pump();
    expect(find.text('活动 2026/11'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.completeError(const JobFairException(JobFairFailure.network));
    await tester.pumpAndSettle();
    expect(find.text('活动 2026/11'), findsOneWidget);
    expect(find.text('刷新失败，仍显示上次加载的活动。'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('刷新失败，仍显示上次加载的活动。'), findsNothing);
    expect(service.requests, hasLength(3));
  });

  testWidgets(
    'first-load errors offer retry without pretending the month is empty',
    (tester) async {
      service.replies.add(
        (_) => Future.error(const JobFairException(JobFairFailure.response)),
      );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      expect(find.text('招聘活动加载失败，请重试。'), findsOneWidget);
      expect(find.text('本月暂无招聘会或宣讲会'), findsNothing);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('活动 2026/11'), findsOneWidget);
    },
  );

  testWidgets('only the latest requested month can replace the list', (
    tester,
  ) async {
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final december = Completer<JobFairMonthData>();
    final january = Completer<JobFairMonthData>();
    service.replies.addAll([(_) => december.future, (_) => january.future]);
    await tester.tap(find.byTooltip('下个月'));
    await tester.pump();
    await tester.tap(find.byTooltip('下个月'));
    await tester.pump();
    january.complete(_events(JobFairMonth(2027, 1)));
    await tester.pumpAndSettle();
    december.complete(_events(JobFairMonth(2026, 12)));
    await tester.pumpAndSettle();
    expect(find.text('活动 2027/01'), findsOneWidget);
    expect(find.text('活动 2026/12'), findsNothing);
    await tester.tap(find.byTooltip('回到本月'));
    await tester.pumpAndSettle();
    expect(find.text('活动 2026/11'), findsOneWidget);
    expect(service.requests.last, JobFairMonth(2026, 11));
  });

  testWidgets('failed month navigation labels the retained month explicitly', (
    tester,
  ) async {
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    service.replies.add(
      (_) => Future.error(const JobFairException(JobFairFailure.network)),
    );
    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();
    expect(find.text('活动 2026/11'), findsOneWidget);
    expect(find.text('月份加载失败，仍显示上次成功加载的月份。'), findsOneWidget);
    expect(find.text('2026年11月'), findsOneWidget);
    expect(find.text('2026年12月'), findsOneWidget);
  });

  testWidgets(
    'month picker and empty state work in English on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      service.replies.add(
        (month) => Future.value(JobFairMonthData(month: month, events: [])),
      );
      await tester.pumpWidget(_app(service, locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(
        find.text('No job fairs or career talks this month'),
        findsOneWidget,
      );
      await tester.tap(find.text('November 2026'));
      await tester.pumpAndSettle();
      expect(find.text('Select month'), findsOneWidget);
      await tester.tap(find.text('Dec'));
      await tester.pumpAndSettle();
      expect(service.requests.last, JobFairMonth(2026, 12));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late responses after leaving the page do not update disposed hooks',
    (tester) async {
      final pending = Completer<JobFairMonthData>();
      service.replies.add((_) => pending.future);
      await tester.pumpWidget(_app(service));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete(_events(JobFairMonth(2026, 11)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
