import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/widgets/toolbox_menu.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

Widget _app(
  AppSettings settings, {
  required Widget child,
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
      child: child!,
    ),
    home: child,
  ),
);

void main() {
  testWidgets(
    'cards center icons above wrapped titles and keep columns across rows and groups',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = AppSettings();
      addTearDown(settings.dispose);
      const sections = [
        NavigationPaneSection(
          title: 'Campus',
          destinations: [
            NavigationPaneDestination(
              icon: Icons.notifications_outlined,
              title: 'Academic changes and examination arrangements',
              subtitle: 'New grades and changes to exam schedules',
              route: AppRoutes.academicChanges,
            ),
            NavigationPaneDestination(
              icon: Icons.school_outlined,
              title: 'GPA',
              subtitle: 'Check academic progress',
              route: AppRoutes.gpa,
            ),
            NavigationPaneDestination(
              icon: Icons.folder_copy_outlined,
              title: 'Past papers',
              route: AppRoutes.papers,
            ),
            NavigationPaneDestination(
              icon: Icons.class_outlined,
              title: 'Classrooms',
              route: AppRoutes.emptyRoom,
            ),
            NavigationPaneDestination(
              icon: Icons.room_outlined,
              title: 'Exams',
              route: AppRoutes.examRoom,
            ),
            NavigationPaneDestination(
              icon: Icons.assignment_outlined,
              title: 'Grades',
              route: AppRoutes.marks,
            ),
            NavigationPaneDestination(
              icon: Icons.pie_chart_outline,
              title: 'Credits',
              route: AppRoutes.credit,
            ),
          ],
        ),
        NavigationPaneSection(
          title: 'Other',
          destinations: [
            NavigationPaneDestination(
              icon: Icons.water_drop_outlined,
              title: 'Utilities',
              route: AppRoutes.utilityPayment,
            ),
          ],
        ),
      ];
      for (final (width, scale) in [
        (360.0, 1.0),
        (390.0, 1.0),
        (430.0, 1.0),
        (1000.0, 1.0),
        (360.0, 2.0),
      ]) {
        tester.view.physicalSize = Size(width, 1000);
        final theme = buildTheme(
          Colors.blue,
          brightness: Brightness.dark,
          interfaceStyle: InterfaceStyle.classic,
          visuals: const ThemeVisuals(
            backgroundImage: 'wallpaper',
            surfaceOpacity: 0.42,
            cardRadius: 20,
          ),
        );
        await tester.pumpWidget(
          _app(
            settings,
            locale: const Locale('en'),
            textScale: scale,
            theme: theme,
            child: AppScaffold(
              body: ToolboxMenu(sections: sections, onSelected: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byKey(
          const ValueKey('toolbox-card-${AppRoutes.academicChanges}'),
        );
        final second = find.byKey(
          const ValueKey('toolbox-card-${AppRoutes.gpa}'),
        );
        expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
        expect(tester.getBottomLeft(first).dy, tester.getBottomLeft(second).dy);
        final firstRect = tester.getRect(first);
        for (final route in [AppRoutes.credit, AppRoutes.utilityPayment]) {
          final rect = tester.getRect(
            find.byKey(ValueKey('toolbox-card-$route')),
          );
          expect(rect.width, closeTo(firstRect.width, 0.01));
        }
        if (width == 390 || width == 430) {
          final fifth = find.byKey(
            const ValueKey('toolbox-card-${AppRoutes.examRoom}'),
          );
          final sixth = find.byKey(
            const ValueKey('toolbox-card-${AppRoutes.marks}'),
          );
          expect(tester.getTopLeft(fifth).dy, firstRect.top);
          expect(tester.getTopLeft(sixth).dy, greaterThan(firstRect.bottom));
        }
        if (scale > 1) {
          final third = find.byKey(
            const ValueKey('toolbox-card-${AppRoutes.papers}'),
          );
          expect(tester.getTopLeft(third).dy, greaterThan(firstRect.bottom));
        }
        for (final route in [AppRoutes.academicChanges, AppRoutes.gpa]) {
          final card = find.byKey(ValueKey('toolbox-card-$route'));
          final icon = tester.getRect(
            find.descendant(of: card, matching: find.byType(Icon)),
          );
          final label = tester.getRect(
            find.descendant(of: card, matching: find.byType(Text)),
          );
          final center = tester.getRect(card).center.dx;
          expect(icon.bottom, lessThan(label.top));
          expect(icon.center.dx, closeTo(center, 0.01));
          expect(label.center.dx, closeTo(center, 0.01));
        }
        final title = find.text(sections.first.destinations.first.title);
        final text = tester.renderObject<RenderParagraph>(
          find.descendant(of: title, matching: find.byType(RichText)),
        );
        final cardRect = tester.getRect(first);
        final textRect = tester.getRect(title);
        expect(text.didExceedMaxLines, isFalse);
        expect(cardRect.contains(textRect.topLeft), isTrue);
        expect(cardRect.contains(textRect.bottomRight), isTrue);
        final material = tester.widget<Material>(
          find.descendant(of: first, matching: find.byType(Material)).first,
        );
        expect(material.color, theme.cardTheme.color);
        expect(material.color!.a, closeTo(0.42, 0.01));
        expect(
          (material.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(20),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final customMenu in [false, true]) {
    testWidgets(
      'split navigation preserves detail and selection with custom menu $customMenu',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 720);
        addTearDown(tester.view.reset);
        final settings = AppSettings();
        addTearDown(settings.dispose);
        final root = GlobalKey<NavigatorState>();
        final opened = <String?>[];
        const sections = [
          NavigationPaneSection(
            title: 'Academic',
            destinations: [
              NavigationPaneDestination(
                icon: Icons.school_outlined,
                title: 'GPA',
                route: AppRoutes.gpa,
              ),
              NavigationPaneDestination(
                icon: Icons.assignment_outlined,
                title: 'Grades',
                route: AppRoutes.marks,
              ),
            ],
          ),
        ];
        await tester.pumpWidget(
          _app(
            settings,
            navigatorKey: root,
            child: SplitNavigationPage(
              title: 'Tools',
              initialRoute: AppRoutes.gpa,
              sections: sections,
              menuBuilder: customMenu
                  ? (context, selectedRoute, onSelected) => ToolboxMenu(
                      sections: sections,
                      selectedRoute: selectedRoute,
                      onSelected: onSelected,
                    )
                  : null,
              onGenerateRoute: (route) {
                opened.add(route.name);
                return MaterialPageRoute<void>(
                  settings: route,
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/detail'),
                      child: Text('Open ${route.name} detail'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(ToolboxMenu),
          customMenu ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.text('Grades'));
        await tester.pumpAndSettle();
        expect(opened.last, AppRoutes.marks);
        expect(root.currentState!.canPop(), isFalse);
        expect(find.text('Open ${AppRoutes.marks} detail'), findsOneWidget);
        await tester.tap(find.text('Open ${AppRoutes.marks} detail'));
        await tester.pumpAndSettle();
        expect(opened.last, '/detail');
        expect(find.text('Open /detail detail'), findsOneWidget);
        await tester.tap(find.text('Grades'));
        await tester.pumpAndSettle();
        expect(find.text('Open ${AppRoutes.marks} detail'), findsOneWidget);
        expect(
          tester.getSemantics(find.text('Grades')),
          isSemantics(
            label: 'Grades',
            isButton: true,
            isFocusable: true,
            hasFocusAction: true,
            hasTapAction: true,
            isSelected: true,
          ),
        );
        expect(
          tester.getSemantics(find.text('Open ${AppRoutes.marks} detail')),
          isSemantics(isButton: true, hasTapAction: true),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
