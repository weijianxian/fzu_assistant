import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widget/layout/app_theme_background.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/toolbox.dart';
import 'package:fzu_assistant/screen/toolbox/widgets/toolbox_menu.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

Widget _app(
  AppSettings settings, {
  Widget child = const ToolboxPage(),
  GlobalKey<NavigatorState>? navigatorKey,
  RouteFactory? onGenerateRoute,
  Locale locale = const Locale('zh'),
  double textScale = 1,
  ThemeData? theme,
}) => AppSettingsProvider(
  settings: settings,
  child: MaterialApp(
    navigatorKey: navigatorKey,
    theme: theme ?? settings.lightTheme,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    onGenerateRoute: onGenerateRoute,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: RepaintBoundary(
        key: const ValueKey('toolbox-capture'),
        child: AppThemeBackground(child: child!),
      ),
    ),
    home: child,
  ),
);

Future<void> _capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('TOOLBOX_CAPTURE_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('toolbox-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/toolbox-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _reveal(WidgetTester tester, String label) async {
  final scrollable = find
      .descendant(
        of: find.byType(ToolboxMenu),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.text(label),
    180,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const font = String.fromEnvironment('TOOLBOX_CAPTURE_FONT');
    if (font.isEmpty) return;
    await (FontLoader('Roboto')..addFont(
          File(font).readAsBytes().then((bytes) => bytes.buffer.asByteData()),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('each toolbox card opens its original full-page route', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
    final settings = AppSettings()..papersAccess.value = FeatureAccess.allow;
    addTearDown(settings.dispose);
    final root = GlobalKey<NavigatorState>();
    String? opened;
    await tester.pumpWidget(
      _app(
        settings,
        navigatorKey: root,
        onGenerateRoute: (route) {
          opened = route.name;
          return MaterialPageRoute<void>(
            settings: route,
            builder: (_) => const Scaffold(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(ToolboxPage)))!;
    final destinations = [
      (l10n.academicChanges, AppRoutes.academicChanges),
      (l10n.gpaInfo, AppRoutes.gpa),
      (l10n.marksQuery, AppRoutes.marks),
      (l10n.creditStats, AppRoutes.credit),
      (l10n.cultivatePlan, AppRoutes.cultivatePlan),
      (l10n.unifiedExam, AppRoutes.unifiedExam),
      (l10n.examRoom, AppRoutes.examRoom),
      (l10n.pastPapers, AppRoutes.papers),
      (l10n.emptyClassroom, AppRoutes.emptyRoom),
      (l10n.classroomUsage, AppRoutes.classroomUsage),
      (l10n.learningCenter, AppRoutes.learningCenter),
      (l10n.officeNotice, AppRoutes.notice),
      (l10n.jobFairTitle, AppRoutes.jobFair),
      (l10n.jiaxiLectures, AppRoutes.lectures),
      (l10n.evaluation, AppRoutes.evaluation),
      (l10n.academicShortcuts, AppRoutes.academicShortcuts),
      (l10n.campusServices, AppRoutes.campusServices),
      (l10n.utilityPayment, AppRoutes.utilityPayment),
    ];
    for (final (formalTitle, route) in destinations) {
      final label = switch (route) {
        AppRoutes.emptyRoom => '空教室',
        AppRoutes.jobFair => '招聘会',
        AppRoutes.classroomUsage => '教室占用',
        AppRoutes.academicShortcuts => '教务入口',
        _ => formalTitle,
      };
      await _reveal(tester, label);
      final tile = find.widgetWithText(ToolboxFeatureCard, label);
      final semanticsNode = tester.getSemantics(find.text(label));
      expect(semanticsNode.label, startsWith(formalTitle));
      expect(
        semanticsNode,
        isSemantics(
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      final card = find.descendant(of: tile, matching: find.byType(Card));
      expect(card, findsOneWidget);
      // The corner area is actionable too, not only the label / icon.
      await tester.tapAt(
        tester.getRect(card).bottomRight - const Offset(16, 16),
      );
      await tester.pumpAndSettle();
      expect(opened, route);
      expect(root.currentState!.canPop(), isTrue);
      root.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text(l10n.downloadLibrary), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('English toolbox localizes all four short menu titles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
    final settings = AppSettings();
    addTearDown(settings.dispose);
    await tester.pumpWidget(_app(settings, locale: const Locale('en')));
    await tester.pumpAndSettle();

    for (final (route, englishTitle, chineseTitle) in [
      (AppRoutes.emptyRoom, 'Empty rooms', '空教室'),
      (AppRoutes.classroomUsage, 'Room usage', '教室占用'),
      (AppRoutes.jobFair, 'Job fairs', '招聘会'),
      (AppRoutes.academicShortcuts, 'Academics', '教务入口'),
    ]) {
      await _reveal(tester, englishTitle);
      final card = find.byKey(ValueKey('toolbox-card-$route'));
      expect(
        find.descendant(of: card, matching: find.text(englishTitle)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(chineseTitle)),
        findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('paper hide and consent state update the toolbox immediately', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);
    final settings = AppSettings();
    addTearDown(settings.dispose);
    await tester.pumpWidget(_app(settings));
    await tester.pumpAndSettle();
    await _reveal(tester, '历年卷');
    final l10n = AppLocalizations.of(tester.element(find.byType(ToolboxPage)))!;
    expect(
      tester.getSemantics(find.text('历年卷')).label,
      contains(l10n.thirdPartyDisabled),
    );
    settings.papersAccess.value = FeatureAccess.hide;
    await tester.pumpAndSettle();
    expect(find.text('历年卷'), findsNothing);
    settings.papersAccess.value = FeatureAccess.allow;
    await tester.pumpAndSettle();
    await _reveal(tester, '历年卷');
    final label = tester.getSemantics(find.text('历年卷')).label;
    expect(label, contains(l10n.pastPapersDescription));
    expect(label, isNot(contains(l10n.thirdPartyDisabled)));
    await tester.pumpWidget(const SizedBox());
  });

  if (const String.fromEnvironment('TOOLBOX_CAPTURE_DIR').isNotEmpty) {
    testWidgets('captures toolbox screens for visual review', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final (name, size, locale, scale, dark) in [
        ('phone-light', const Size(400, 860), const Locale('zh'), 1.0, false),
        ('phone-dark', const Size(400, 860), const Locale('zh'), 1.0, true),
        ('phone-large', const Size(360, 800), const Locale('en'), 2.0, false),
        ('wide-light', const Size(1200, 800), const Locale('zh'), 1.0, false),
        ('wide-dark', const Size(1200, 800), const Locale('en'), 1.4, true),
      ]) {
        tester.view.physicalSize = size;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        final settings = AppSettings()
          ..papersAccess.value = FeatureAccess.allow;
        await tester.pumpWidget(
          _app(
            settings,
            locale: locale,
            textScale: scale,
            theme: dark ? settings.darkTheme : settings.lightTheme,
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, name);
        if (name == 'phone-light') {
          await _reveal(tester, '学习中心');
          await _capture(tester, 'phone-campus');
        }
        if (name == 'phone-large' || name == 'wide-dark') {
          final menuScroll = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ToolboxMenu),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          // Settle lazy row extents before capturing the end of the menu.
          for (var pass = 0; pass < 3; pass++) {
            menuScroll.position.jumpTo(menuScroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
          }
          await _capture(tester, '$name-campus');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        settings.dispose();
      }
    });
  }
}
