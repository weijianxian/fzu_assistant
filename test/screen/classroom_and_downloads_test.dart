import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/classroom_usage.dart';
import 'package:fzu_assistant/screen/toolbox/empty_room/classroom_usage_page.dart';
import 'package:fzu_assistant/screen/toolbox/paper/paper_library_page.dart';
import 'package:fzu_assistant/service/api/classroom_usage_service.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/paper_library_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class _Classrooms extends ClassroomUsageService {
  bool fail = false;
  bool failOptions = false;
  int requests = 0;
  final queries = <(String, String, String)>[];
  Completer<List<ClassroomUsage>>? pending;
  @override
  Future<List<ClassroomChoice>> campuses(String date) async {
    if (failOptions) throw const FormatException('invalid options');
    return [
      const ClassroomChoice('01', '旗山校区'),
      const ClassroomChoice('02', '铜盘校区'),
    ];
  }

  @override
  Future<List<ClassroomChoice>> buildings(String date, String campus) async =>
      campus == '01'
      ? [
          const ClassroomChoice('east', '公共教学楼东1'),
          const ClassroomChoice('west', '公共教学楼西1'),
        ]
      : [const ClassroomChoice('main', '铜盘教学楼')];
  @override
  Future<List<ClassroomUsage>> usage(
    String date,
    String campus,
    String building,
  ) async {
    requests++;
    queries.add((date, campus, building));
    if (fail) throw const FormatException('invalid table');
    if (pending != null) return pending!.future;
    return [
      for (var i = 0; i < 60; i++)
        ClassroomUsage(
          name: '东1-${101 + i}',
          capacity: '60',
          type: '多媒体教室',
          occupancies: const [
            ClassroomOccupancy(
              start: 1,
              end: 2,
              event: '高等数学 (1-18)',
              occupant: '计算机班',
            ),
          ],
        ),
    ];
  }
}

class _Library extends PaperLibraryService {
  List<LocalPaper> papers = [
    LocalPaper(
      File('math.pdf'),
      '2026高等数学期末试卷.pdf',
      123456,
      DateTime(2026, 11, 8),
    ),
    LocalPaper(File('physics.pdf'), '2025物理.pdf', 2048, DateTime(2026, 11, 7)),
  ];
  int deletions = 0;
  @override
  Future<List<LocalPaper>> list() async => List.of(papers);
  @override
  Future<void> delete(LocalPaper paper) async {
    papers.remove(paper);
    deletions++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_QA')) {
      final loader = FontLoader('QaFont')
        ..addFont(
          File('C:/Windows/Fonts/msyh.ttc')
              .readAsBytes()
              .then(ByteData.sublistView),
        );
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            'C:/Users/weijx/AppData/Local/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await icons.load();
    }
  });
  final captureKey = GlobalKey();
  Widget app(Widget page, AppSettings settings, double scale) =>
      RepaintBoundary(
        key: captureKey,
        child: AppSettingsProvider(
          settings: settings,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: const bool.fromEnvironment('CAPTURE_QA')
                ? settings.lightTheme.copyWith(
                    textTheme: settings.lightTheme.textTheme.apply(
                      fontFamily: 'QaFont',
                    ),
                  )
                : settings.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: page,
          ),
        ),
      );
  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_QA')) return;
    await tester.runAsync(() async {
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final target = File('build/qa/classroom-downloads/$name.png');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [const Size(320, 740), const Size(1000, 650)]) {
    for (final style in [
      InterfaceStyle.classic,
      InterfaceStyle.cards,
      InterfaceStyle.continuousCards,
    ]) {
      testWidgets('教室占用展开和窄屏排版 $size $style', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = AppSettings()..interfaceStyle.value = style;
        addTearDown(settings.dispose);
        final api = _Classrooms();
        await tester.pumpWidget(
          app(ClassroomUsagePage(service: api), settings, 1.4),
        );
        await tester.pumpAndSettle();
        expect(api.requests, 0);
        expect(find.text('东1-101'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        await screenshot(
          tester,
          'classroom-${size.width.toInt()}-${style.name}-filters',
        );
        await tester.tap(find.widgetWithText(FilledButton, '查询'));
        await tester.pumpAndSettle();
        expect(api.requests, 1);
        expect(find.text('东1-101'), findsOneWidget);
        expect(find.text('东1-160'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        await screenshot(
          tester,
          'classroom-${size.width.toInt()}-${style.name}-results',
        );
        await tester.ensureVisible(find.text('东1-101'));
        await tester.tap(find.text('东1-101'));
        await tester.pumpAndSettle();
        expect(find.text('高等数学 (1-18)'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await screenshot(
          tester,
          'classroom-${size.width.toInt()}-${style.name}',
        );
      });
    }
    testWidgets('本地下载搜索、删除确认与取消 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettings();
      addTearDown(settings.dispose);
      final library = _Library();
      await tester.pumpWidget(
        app(PaperLibraryPage(service: library), settings, 1.4),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '数学');
      await tester.pumpAndSettle();
      expect(find.text('2025物理.pdf'), findsNothing);
      await screenshot(tester, 'downloads-${size.width.toInt()}');
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除文件'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(library.deletions, 0);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除文件'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除文件'));
      await tester.pumpAndSettle();
      expect(library.deletions, 1);
      expect(find.text('2026高等数学期末试卷.pdf'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('教室查询失败可重试', (tester) async {
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final api = _Classrooms()..fail = true;
    await tester.pumpWidget(app(ClassroomUsagePage(service: api), settings, 1));
    await tester.pumpAndSettle();
    expect(api.requests, 0);
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pumpAndSettle();
    expect(find.textContaining('invalid table'), findsOneWidget);
    expect(find.text('东1-101'), findsNothing);
    api.fail = false;
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pumpAndSettle();
    expect(api.requests, 2);
    expect(find.text('东1-101'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('日期校区教学楼改变后仅点击查询才请求占用', (tester) async {
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final api = _Classrooms();
    await tester.pumpWidget(app(ClassroomUsagePage(service: api), settings, 1));
    await tester.pumpAndSettle();
    expect(api.requests, 0);

    await tester.tap(find.text('选择日期'));
    await tester.pumpAndSettle();
    final initial = tester
        .widget<DatePickerDialog>(find.byType(DatePickerDialog))
        .initialDate!;
    final chosen = DateTime(
      initial.year,
      initial.month,
      initial.day == 1 ? 2 : initial.day - 1,
    );
    await tester.tap(find.text('${chosen.day}').last);
    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    expect(api.requests, 0);

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('公共教学楼西1').last);
    await tester.pumpAndSettle();
    expect(api.requests, 0);
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pumpAndSettle();
    final chosenDate = chosen.toIso8601String().split('T').first;
    expect(api.queries, [(chosenDate, '01', 'west')]);
    expect(find.text('东1-101'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('公共教学楼东1').last);
    await tester.pumpAndSettle();
    expect(api.requests, 1);
    expect(find.text('东1-101'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('铜盘校区').last);
    await tester.pumpAndSettle();
    expect(api.requests, 1);
    expect(find.text('东1-101'), findsNothing);
    expect(find.text('铜盘教学楼'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pumpAndSettle();
    expect(api.queries.last, (chosenDate, '02', 'main'));
    expect(api.requests, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('筛选项加载失败重试后仍不自动查询', (tester) async {
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final api = _Classrooms()..failOptions = true;
    await tester.pumpWidget(app(ClassroomUsagePage(service: api), settings, 1));
    await tester.pumpAndSettle();
    final query = find.widgetWithText(FilledButton, '查询');
    expect(tester.widget<FilledButton>(query).onPressed, isNull);
    expect(api.requests, 0);
    api.failOptions = false;
    await tester.tap(find.byTooltip('重试'));
    await tester.pumpAndSettle();
    expect(api.requests, 0);
    expect(tester.widget<FilledButton>(query).onPressed, isNotNull);
    await tester.tap(query);
    await tester.pumpAndSettle();
    expect(api.requests, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('查询中禁用按钮并阻止重复请求，退出后忽略响应', (tester) async {
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final api = _Classrooms()..pending = Completer<List<ClassroomUsage>>();
    await tester.pumpWidget(app(ClassroomUsagePage(service: api), settings, 1));
    await tester.pumpAndSettle();
    final query = find.widgetWithText(FilledButton, '查询');
    final press = tester.widget<FilledButton>(query).onPressed!;
    press();
    press();
    await tester.pump();
    expect(api.requests, 1);
    expect(tester.widget<FilledButton>(query).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    api.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
