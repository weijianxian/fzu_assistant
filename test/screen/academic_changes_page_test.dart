import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/academic_change_notice.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/academic_change.dart';
import 'package:fzu_assistant/screen/toolbox/academic_changes/academic_changes_page.dart';
import 'package:fzu_assistant/service/academic_changes_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lectures_fixture.dart';
import '../fixtures/reminder_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient.instance;
  final service = AcademicChangesService.instance;
  late HttpClientAdapter previousAdapter;
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mockReminderChannel();
    await service.clear();
    previousAdapter = api.dio.httpClientAdapter;
    api.dio.httpClientAdapter = LecturesFixtureAdapter();
    await api.login('20230001', 'test-only', '1234');
    final at = DateTime.utc(2026, 11, 6, 4);
    await (await SharedPreferences.getInstance()).setString(
      serviceStorageKey,
      jsonEncode({
        'account': '20230001',
        'history': [
          AcademicChange(
            id: '1',
            type: AcademicChangeType.gradeChanged,
            course: '高等数学',
            term: '202601',
            before: '85',
            after: '92',
            detectedAt: at,
          ).toJson(),
          AcademicChange(
            id: '2',
            type: AcademicChangeType.examChanged,
            course: '大学英语',
            term: '202601',
            before: '2026年11月6日14:00-16:00旗山东3-106',
            after: '2026年11月6日15:00-17:00铜盘科报厅B',
            detectedAt: at,
          ).toJson(),
        ],
      }),
    );
  });
  tearDown(() async {
    await api.clearSession();
    api.dio.httpClientAdapter = previousAdapter;
  });

  for (final language in ['zh', 'en']) {
    for (final size in [const Size(320, 920), const Size(920, 380)]) {
      testWidgets('$language $size 动态内容可读且已读操作持久化', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: const bool.fromEnvironment('CAPTURE_QA')
                ? ThemeData(fontFamily: 'QaFont')
                : null,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: boundaryKey,
              child: const AcademicChangesPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AcademicChangesPage)),
        )!;
        expect(find.text('高等数学'), findsOneWidget);
        expect(
          find.textContaining(l10n.academicYearTerm('2026', '2027', '1')),
          findsWidgets,
        );
        expect(service.value.where((e) => !e.read), hasLength(2));
        if (const bool.fromEnvironment('CAPTURE_QA')) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              'build/academic-changes-$language-${size.width.toInt()}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byTooltip(l10n.academicChangesMarkRead));
        await tester.pumpAndSettle();
        expect(service.value.every((e) => e.read), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('缓存页面恢复保存的未读提示，只统计对应类型且已读后消失', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              AcademicChangeNotice(exams: false),
              AcademicChangeNotice(exams: true),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AcademicChangeNotice).first),
    )!;
    expect(find.text(l10n.academicChangeCount(1)), findsNWidgets(2));
    final readOne = service.markRead(id: '1');
    await tester.pumpAndSettle();
    await readOne;
    expect(find.text(l10n.academicChangeCount(1)), findsOneWidget);
    final readAll = service.markRead();
    await tester.pumpAndSettle();
    await readAll;
    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

const serviceStorageKey = AcademicChangesService.storageKey;
