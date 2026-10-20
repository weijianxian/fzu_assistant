import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/learning_center.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/screen/dev/learning_center_debug_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_center_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_scanner_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_seats_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_available_seats_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_seat_times_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_appointments_page.dart';
import 'package:fzu_assistant/screen/toolbox/toolbox.dart';
import 'package:fzu_assistant/service/api/learning_center_service.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int statusCode = 200;
  int seatStatus = 0;
  List<Map<String, dynamic>>? seatRows;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    final result = <String, dynamic>{'code': '0', 'dataList': []};
    if (path.endsWith('/queryStationStatusByTime')) {
      result['dataList'] =
          seatRows ??
          [
            {
              'id': 1247,
              'spaceName': '796-1',
              'floor': 5,
              'spaceStatus': seatStatus,
            },
          ];
    }
    if (path.endsWith('/querySpaceAppointTime')) {
      result['data'] = {
        'timeDiamondList': [
          {'timeText': '08:00', 'occupy': 0},
          {'timeText': '08:30', 'occupy': 1},
        ],
      };
    }
    if (path.endsWith('/queryMyAppoint')) {
      result['dataList'] = [
        {
          'id': 123,
          'spaceName': '796-1',
          'floor': 5,
          'date': learningDate(
            learningBeijingTime(DateTime.now()).add(const Duration(days: 1)),
          ),
          'beginTime': '08:00',
          'endTime': '10:00',
          'auditStatus': 2,
          'sign': false,
        },
      ];
    }
    return ResponseBody.fromString(
      jsonEncode(result),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget _app(Widget home, {Locale locale = const Locale('zh')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  onGenerateRoute: AppRouter.onGenerateRoute,
  home: home,
);

void main() {
  late _Adapter adapter;
  late HttpClientAdapter original;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AuthStorage().saveCredentials('academic', 'password');
    await SsoService.instance.saveStudyToken('fake-token');
    original = LearningCenterService.instance.dio.httpClientAdapter;
    adapter = _Adapter();
    LearningCenterService.instance.dio.httpClientAdapter = adapter;
  });
  tearDown(() {
    LearningCenterService.instance.dio.httpClientAdapter = original;
  });

  testWidgets(
    'seat areas keep scroll extent stable and support area navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      adapter.seatRows = [
        for (var number = 1; number <= 919; number++)
          {
            'id': number,
            'spaceName': '$number',
            'floor': 5,
            'spaceStatus': number % 2,
          },
      ];
      await tester.pumpWidget(
        _app(
          LearningAvailableSeatsPage(
            date: learningDate(
              learningBeijingTime(DateTime.now()).add(const Duration(days: 1)),
            ),
            begin: '08:00',
            end: '10:00',
            floor: '5',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      final position = scrollView.controller!.position;
      final originalExtent = position.maxScrollExtent;
      expect(originalExtent, greaterThan(1000));
      for (final fraction in [0.1, 0.5, 0.9]) {
        position.jumpTo(originalExtent * fraction);
        await tester.pumpAndSettle();
        expect(position.maxScrollExtent, closeTo(originalExtent, 0.1));
      }
      final lastArea = find.widgetWithText(TextButton, 'M');
      await tester.ensureVisible(lastArea);
      await tester.tap(lastArea);
      await tester.pumpAndSettle();
      expect(find.text('919').hitTestable(), findsOneWidget);
      final firstArea = find.widgetWithText(TextButton, 'J');
      await tester.ensureVisible(firstArea);
      await tester.tap(firstArea);
      await tester.pumpAndSettle();
      expect(find.text('1').hitTestable(), findsOneWidget);
      expect(position.maxScrollExtent, closeTo(originalExtent, 0.1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsupported scanner opens and closes without calling native camera',
    (tester) async {
      await tester.pumpWidget(
        _app(const LearningScannerPage(appointmentId: '123')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('此平台暂不支持相机扫码'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets('signed-out learning center opens SSO login and can return', (
    tester,
  ) async {
    await SsoService.instance.clearStudyToken();
    await tester.pumpWidget(_app(const LearningCenterPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '统一身份认证登录'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('academic'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LearningCenterPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(400, 800), const Size(1200, 800)]) {
    testWidgets('toolbox opens learning center at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        AppSettingsProvider(
          settings: settings,
          child: _app(const ToolboxPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('学习中心'));
      await tester.tap(find.text('学习中心'));
      await tester.pumpAndSettle();
      expect(find.byType(LearningCenterPage), findsOneWidget);
      expect(find.text('预约座位'), findsOneWidget);
      await tester.tap(find.text('我的预约'));
      await tester.pumpAndSettle();
      expect(find.byType(LearningAppointmentsPage), findsOneWidget);
      expect(find.text('5 层 797 #123'), findsOneWidget);
      final date = learningDate(
        learningBeijingTime(DateTime.now()).add(const Duration(days: 1)),
      );
      expect(find.text('$date 08:00–10:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'reservation sends no mutation until confirmation and uses server seat ID',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const LearningSeatsPage()));
      await tester.pumpAndSettle();
      final tomorrow = learningDate(
        learningBeijingTime(DateTime.now()).add(const Duration(days: 1)),
      );
      await tester.tap(find.byTooltip(tomorrow));
      await tester.pumpAndSettle();
      await tester.tap(find.text('08:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10:00'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('查询'));
      await tester.tap(find.text('查询'));
      await tester.pumpAndSettle();
      expect(find.byType(LearningAvailableSeatsPage), findsOneWidget);
      expect(find.byTooltip(tomorrow), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(LearningAvailableSeatsPage), findsNothing);
      expect(find.text('797'), findsNothing);
      expect(find.textContaining('开始时间: 08:00 · 结束时间: 10:00'), findsOneWidget);
      await tester.ensureVisible(find.text('查询'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查询'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('797'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('797'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        adapter.requests.where((r) => r.uri.path.endsWith('/addSpaceAppoint')),
        isEmpty,
      );
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      final request = adapter.requests.singleWhere(
        (r) => r.uri.path.endsWith('/addSpaceAppoint'),
      );
      expect((request.data as Map)['spaceId'], '1247');
      expect((request.data as Map)['date'], tomorrow);
      expect((request.data as Map)['beginTime'], '08:00');
      expect((request.data as Map)['endTime'], '10:00');
      expect(find.byType(LearningAvailableSeatsPage), findsNothing);
      expect(find.byType(LearningSeatsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('seat list retries a failed query on its own page', (
    tester,
  ) async {
    adapter.statusCode = 503;
    final date = learningDate(
      learningBeijingTime(DateTime.now()).add(const Duration(days: 1)),
    );
    await tester.pumpWidget(
      _app(
        LearningAvailableSeatsPage(
          date: date,
          begin: '08:00',
          end: '10:00',
          floor: '4',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('797'), findsNothing);
    adapter.statusCode = 200;
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(find.text('797'), findsOneWidget);
    expect(
      adapter.requests.where(
        (r) => r.uri.path.endsWith('/queryStationStatusByTime'),
      ),
      hasLength(2),
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(400, 800), const Size(1200, 800)]) {
    testWidgets(
      'time cards select a range, limit duration and reset at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(const LearningSeatsPage()));
        await tester.pumpAndSettle();
        final tomorrow = learningDate(
          learningBeijingTime(DateTime.now()).add(const Duration(days: 1)),
        );
        await tester.tap(find.byTooltip(tomorrow));
        await tester.pumpAndSettle();
        InkWell card(String time) => tester.widget<InkWell>(
          find
              .ancestor(of: find.text(time), matching: find.byType(InkWell))
              .first,
        );
        await tester.tap(find.text('08:00'));
        await tester.pumpAndSettle();
        expect(card('12:00').onTap, isNotNull);
        expect(card('12:30').onTap, isNull);
        await tester.tap(find.text('09:00'));
        await tester.pumpAndSettle();
        final middle = tester.widget<Semantics>(
          find
              .ancestor(
                of: find.text('08:30'),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics && widget.properties.selected != null,
                ),
              )
              .first,
        );
        expect(middle.properties.selected, isTrue);
        await tester.ensureVisible(find.text('查询'));
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '查询'))
              .onPressed,
          isNotNull,
        );
        await tester.ensureVisible(find.text('08:00'));
        await tester.tap(find.text('08:00'));
        await tester.pumpAndSettle();
        expect(card('12:30').onTap, isNotNull);
        await tester.ensureVisible(find.text('查询'));
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '查询'))
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final size in [const Size(400, 800), const Size(1200, 1600)]) {
    testWidgets('debug buttons send raw parameters without dialogs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(const LearningCenterDebugPage(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      final tokenField = tester
          .widgetList<TextField>(find.byType(TextField))
          .first;
      expect(tokenField.obscureText, isTrue);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.textContaining('调试操作调用真实Learning center接口'), findsNothing);
      await tester.tap(find.byTooltip('Show token'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<TextField>(find.byType(TextField)).first.obscureText,
        isFalse,
      );
      await tester.tap(find.byTooltip('Hide token'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<TextField>(find.byType(TextField)).first.obscureText,
        isTrue,
      );
      await tester.tap(find.text('Appointments'));
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.textContaining('"id": 123'), findsOneWidget);
      final idField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Appointment ID',
      );
      await tester.ensureVisible(idField);
      await tester.enterText(idField, '');
      adapter.statusCode = 401;
      await tester.ensureVisible(find.text('Direct check-in (debug)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Direct check-in (debug)'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final signIn = adapter.requests.singleWhere(
        (r) => r.uri.path.endsWith('/signIn'),
      );
      expect(signIn.data, {'id': ''});
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.textContaining('"statusCode": 401'), findsOneWidget);
      expect(await SsoService.instance.loadStudyToken(), 'fake-token');
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      final dateField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Date',
      );
      await tester.ensureVisible(dateField);
      await tester.enterText(dateField, 'bad-date');
      await tester.ensureVisible(find.text('Reserve seat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reserve seat'));
      await tester.pumpAndSettle();
      final reserve = adapter.requests.singleWhere(
        (r) => r.uri.path.endsWith('/addSpaceAppoint'),
      );
      expect(reserve.data, {
        'spaceId': '',
        'date': 'bad-date',
        'beginTime': '08:00',
        'endTime': '10:00',
      });
      expect(reserve.headers['token'], '');
      expect(
        adapter.requests.any(
          (r) => r.uri.path.endsWith('/queryStationStatusByTime'),
        ),
        isFalse,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(400, 800), const Size(1200, 800)]) {
    testWidgets('occupied seat opens time cards without an overlay at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      adapter.seatStatus = 1;
      final date = learningDate(
        learningBeijingTime(DateTime.now()).add(const Duration(days: 1)),
      );
      await tester.pumpWidget(
        _app(
          LearningAvailableSeatsPage(
            date: date,
            begin: '08:00',
            end: '10:00',
            floor: '5',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('797'));
      await tester.pumpAndSettle();
      expect(find.byType(LearningSeatTimesPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('08:30'), findsOneWidget);
      expect(find.text('空闲'), findsOneWidget);
      expect(find.text('已占用'), findsOneWidget);
      final request = adapter.requests.singleWhere(
        (r) => r.uri.path.endsWith('/querySpaceAppointTime'),
      );
      expect(request.data, {'spaceId': '1247', 'date': date});
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(LearningSeatTimesPage), findsNothing);
      expect(find.text('797'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('English learning center has localized entries', (tester) async {
    await tester.pumpWidget(
      _app(const LearningCenterPage(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Learning center'), findsOneWidget);
    expect(find.text('Reserve a seat'), findsOneWidget);
    expect(find.text('My reservations'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
