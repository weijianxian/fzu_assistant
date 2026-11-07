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
    for (final layout in ['grouped list', 'sliver list', 'adaptive grid']) {
      testWidgets('$layout stays lazy and scrollable across styles at $size', (
        tester,
      ) async {
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
                slivers: layout != 'grouped list'
                    ? [
                        if (layout == 'adaptive grid')
                          MasonrySliverGrid.grouped(
                            childCount: 80,
                            itemBuilder: item,
                          )
                        else
                          AppSliverList(itemCount: 80, itemBuilder: item),
                      ]
                    : null,
                child: layout == 'grouped list'
                    ? AppListView.grouped(itemCount: 80, itemBuilder: item)
                    : null,
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
          InterfaceStyle.continuousCards,
          InterfaceStyle.classic,
          InterfaceStyle.cards,
        ]) {
          final before = controller.offset;
          built.clear();
          style.value = next;
          await tester.pumpAndSettle();
          expect(controller.offset, before);
          expect(built.length, lessThan(80));
          expect(find.byType(Card), next.isCard ? findsWidgets : findsNothing);
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
      });
    }
  }

  for (final style in InterfaceStyle.values) {
    testWidgets('$style keeps group gaps and corners in every list', (
      tester,
    ) async {
      final notifier = ValueNotifier(style);
      addTearDown(notifier.dispose);
      final rows = List.generate(
        3,
        (index) => SizedBox(
          key: ValueKey('row-$index'),
          height: 48,
          child: Text('Row $index'),
        ),
      );
      for (final content in [
        AppSection.list(children: rows),
        AppListView.grouped(
          itemCount: rows.length,
          itemBuilder: (_, index) => rows[index],
        ),
        AppCustomScrollView(
          slivers: [
            AppSliverList(
              itemCount: rows.length,
              itemBuilder: (_, index) => rows[index],
            ),
          ],
        ),
      ]) {
        await tester.pumpWidget(app(notifier, Scaffold(body: content)));
        await tester.pumpAndSettle();
        final bounds = [
          for (var index = 0; index < rows.length; index++)
            tester.getRect(find.byKey(ValueKey('row-$index'))),
        ];
        final gap = style == InterfaceStyle.cards ? 4.0 : 0.0;
        expect(bounds[1].top - bounds[0].bottom, gap);
        expect(bounds[2].top - bounds[1].bottom, gap);
        expect(bounds[0].left, style.isCard ? 16 : 0);
        expect(find.byType(Divider), findsNothing);
        expect(find.byType(VerticalDivider), findsNothing);
        if (style.isCard) {
          final cards = tester.widgetList<Card>(find.byType(Card)).toList();
          expect(cards, hasLength(3));
          final radii = [
            for (final card in cards)
              (card.shape! as RoundedRectangleBorder).borderRadius.resolve(
                TextDirection.ltr,
              ),
          ];
          final inner = style == InterfaceStyle.cards
              ? const Radius.circular(4)
              : Radius.zero;
          expect(radii, [
            BorderRadius.vertical(
              top: const Radius.circular(24),
              bottom: inner,
            ),
            BorderRadius.all(inner),
            BorderRadius.vertical(
              top: inner,
              bottom: const Radius.circular(24),
            ),
          ]);
        } else {
          expect(find.byType(Card), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
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
    expect(settings.interfaceStyle.value, InterfaceStyle.cards);
    expect(find.byType(Card), findsWidgets);
    settings.interfaceStyle.value = InterfaceStyle.classic;
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
