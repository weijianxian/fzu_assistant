import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/screen/toolbox/toolbox.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

Widget app(ValueNotifier<InterfaceStyle> style, Widget child) =>
    AnimatedBuilder(
      animation: style,
      builder: (_, _) => MaterialApp(
        theme: buildTheme(
          Colors.deepPurple,
          brightness: Brightness.dark,
          interfaceStyle: style.value,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: child,
      ),
    );

void main() {
  for (final size in [const Size(360, 800), const Size(1000, 600)]) {
    for (final grid in [false, true]) {
      testWidgets(
        '${grid ? 'adaptive grid' : 'grouped list'} stays lazy and scrollable across styles at $size',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
          addTearDown(tester.view.reset);
          final style = ValueNotifier(InterfaceStyle.classic);
          final controller = ScrollController();
          addTearDown(style.dispose);
          addTearDown(controller.dispose);
          final built = <int>{};
          Widget item(BuildContext context, int index) {
            built.add(index);
            return ListTile(
              title: Text('Row $index'),
              subtitle: const Text('Course results'),
            );
          }

          await tester.pumpWidget(
            app(
              style,
              AppScaffold(
                appBar: AppBar(title: const Text('Results')),
                body: ToolPageWrapper(
                  loading: false,
                  emptyText: 'Empty',
                  onRefresh: () async {},
                  scrollController: controller,
                  slivers: grid
                      ? [
                          MasonrySliverGrid.grouped(
                            childCount: 80,
                            itemBuilder: item,
                          ),
                        ]
                      : null,
                  child: grid
                      ? null
                      : AppListView.grouped(itemCount: 80, itemBuilder: item),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(built.length, lessThan(80));
          expect(tester.takeException(), isNull);
          controller.jumpTo(300);
          await tester.pumpAndSettle();
          for (final next in [
            InterfaceStyle.cards,
            InterfaceStyle.classic,
            InterfaceStyle.cards,
          ]) {
            final before = controller.offset;
            style.value = next;
            await tester.pumpAndSettle();
            expect(controller.offset, before);
            expect(
              find.byType(Card),
              next == InterfaceStyle.cards ? findsWidgets : findsNothing,
            );
            expect(find.byType(Divider), findsNothing);
            expect(tester.takeException(), isNull);
          }
          await tester.scrollUntilVisible(
            find.text('Row 79'),
            500,
            maxScrolls: 60,
          );
          await tester.pumpAndSettle();
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(find.text('Row 79').hitTestable(), findsOneWidget);
          expect(
            tester.getRect(find.text('Row 79')).bottom,
            lessThanOrEqualTo(size.height - 34),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('toolbox sections share the switch and keep named navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    final settings = AppSettings()..papersAccess.value = FeatureAccess.allow;
    addTearDown(settings.dispose);
    String? navigated;
    await tester.pumpWidget(
      AppSettingsProvider(
        settings: settings,
        child: AnimatedBuilder(
          animation: settings.interfaceStyle,
          builder: (_, _) => MaterialApp(
            theme: settings.lightTheme,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ToolboxPage(),
            onGenerateRoute: (route) {
              navigated = route.name;
              return MaterialPageRoute<void>(builder: (_) => const Scaffold());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
    settings.interfaceStyle.value = InterfaceStyle.cards;
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsWidgets);
    expect(find.byType(Divider), findsNothing);
    await tester.tap(find.text('成绩查询'));
    await tester.pumpAndSettle();
    expect(navigated, '/marks');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
