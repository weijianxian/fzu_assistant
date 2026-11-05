import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/screen/settings/next_course_widget_settings_page.dart';
import 'package:fzu_assistant/service/next_course_widget_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';

class _LocalWidgetService extends NextCourseWidgetService {
  _LocalWidgetService(this.events);
  final List<String> events;

  @override
  Future<void> sync(AppSettings settings) async {
    events.add('snapshot');
  }
}

class _SyncService extends WidgetSyncService {
  _SyncService(this.events);
  final List<String> events;
  var refreshSucceeds = true;
  var loads = 0;
  var reconciles = 0;
  var permissionRequests = 0;

  @override
  Future<void> load() async {
    loads++;
  }

  @override
  Future<void> reconcile() async {
    reconciles++;
  }

  @override
  Future<void> configure({bool? enabled, int? minutes}) async {
    if (enabled != null) this.enabled.value = enabled;
    if (minutes != null) this.minutes.value = minutes;
  }

  @override
  Future<bool> refreshNow() async {
    events.add('network');
    status.value = WidgetSyncStatus(
      exactAllowed: status.value.exactAllowed,
      failed: !refreshSucceeds,
      lastSuccess: status.value.lastSuccess,
      nextAt: status.value.nextAt,
    );
    return refreshSucceeds;
  }

  @override
  Future<void> requestExactPermission() async {
    permissionRequests++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppSettings settings;
  late _LocalWidgetService widgets;
  late _SyncService sync;
  late List<String> events;
  late List<MethodCall> calls;

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      // A taller preview can recycle the size chips above it. Start at the top
      // before searching forward for an item that is no longer mounted.
      position.jumpTo(position.minScrollExtent);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
    } else {
      await tester.ensureVisible(target);
    }
    await tester.pumpAndSettle();
  }

  setUp(() {
    settings = AppSettings();
    events = [];
    calls = [];
    widgets = _LocalWidgetService(events);
    sync = _SyncService(events);
    messenger.setMockMethodCallHandler(NextCourseWidgetService.channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'requestPin';
    });
  });

  tearDown(() {
    settings.dispose();
    widgets.error.dispose();
    widgets.snapshot.dispose();
    sync.enabled.dispose();
    sync.minutes.dispose();
    sync.status.dispose();
    messenger.setMockMethodCallHandler(NextCourseWidgetService.channel, null);
  });

  NextCourseWidgetEntry seedPreview(String language, {DateTime? start}) {
    final now = DateTime.now().toUtc();
    final beijing = now.add(NextCourseWidgetSnapshot.beijingOffset);
    final monday = DateTime.utc(beijing.year, beijing.month, beijing.day)
        .subtract(Duration(days: beijing.weekday - 1))
        .subtract(NextCourseWidgetSnapshot.beijingOffset);
    final course = NextCourseWidgetEntry(
      name: language == 'zh'
          ? '高等数学与线性代数综合课程'
          : 'Advanced calculus and linear algebra',
      location: language == 'zh'
          ? '旗山校区东三号教学楼 301 教室'
          : 'Qishan campus, East building 3, room 301',
      start: start ?? now.subtract(const Duration(minutes: 5)),
      end: now.add(const Duration(hours: 1)),
      startClass: 1,
      endClass: 2,
      week: 10,
    );
    widgets.snapshot.value = NextCourseWidgetSnapshot(
      generatedAt: now,
      days: [
        for (var day = 0; day < 7; day++)
          NextCourseWidgetDay(
            start: monday.add(Duration(days: day)),
            known: true,
            week: 10,
            courses: day == beijing.weekday - 1 ? [course] : const [],
          ),
      ],
    );
    return course;
  }

  Future<AppLocalizations> open(
    WidgetTester tester, {
    String language = 'zh',
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: brightness,
            ),
            useMaterial3: true,
          ),
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              alwaysUse24HourFormat: true,
            ),
            child: child!,
          ),
          home: NextCourseWidgetSettingsPage(
            widgetService: widgets,
            syncService: sync,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(NextCourseWidgetSettingsPage)),
    )!;
  }

  testWidgets('square is selected and pinned by default', (tester) async {
    final l10n = await open(tester);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('widget-variant-square')),
          )
          .selected,
      isTrue,
    );
    expect(find.byKey(const ValueKey('widget-preview-square')), findsOneWidget);
    expect(find.byKey(const ValueKey('widget-variant-standard')), findsNothing);
    expect(find.text('1×2'), findsNothing);
    expect(find.text('4×3'), findsNothing);
    final add = find.text(l10n.widgetAddVariant(l10n.widgetVariantSquare));
    await reveal(tester, add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(calls.single.arguments, {'variant': 'square'});
    expect(events, ['snapshot']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('all three sizes pin from local data without network refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final l10n = await open(tester);
    final labels = [
      l10n.widgetVariantCompact,
      l10n.widgetVariantSquare,
      l10n.widgetVariantTimetable,
    ];
    for (var i = 0; i < NextCourseWidgetVariant.values.length; i++) {
      final variant = NextCourseWidgetVariant.values[i];
      final choice = find.byKey(ValueKey('widget-variant-${variant.name}'));
      await reveal(tester, choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('widget-preview-${variant.name}')),
        findsOneWidget,
      );
      final add = find.text(l10n.widgetAddVariant(labels[i]));
      await reveal(tester, add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(calls.last.arguments, {'variant': variant.name});
      expect(tester.takeException(), isNull);
    }
    expect(calls.every((call) => call.method == 'requestPin'), isTrue);
    expect(events, ['snapshot', 'snapshot', 'snapshot']);
    expect(sync.loads, 1);
    expect(sync.reconciles, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('compact shows the course beside Beijing time and date at 2 by 1', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now().toUtc();
    final course = seedPreview(
      'en',
      // Cross a UTC date boundary so using UTC or the device date would fail.
      start: DateTime.utc(now.year, now.month, now.day - 1, 23, 55),
    );
    final l10n = await open(tester, language: 'en');
    expect(l10n.widgetVariantCompact, '2×1');
    final chip = find.byKey(const ValueKey('widget-variant-compact'));
    await reveal(tester, chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final preview = find.byKey(const ValueKey('widget-preview-compact'));
    await reveal(tester, preview);
    final size = tester.getSize(preview);
    expect(size.width / size.height, closeTo(2, .001));
    final status = find.descendant(
      of: preview,
      matching: find.text(l10n.widgetInProgress),
    );
    final start = course.start.add(NextCourseWidgetSnapshot.beijingOffset);
    final time = find.descendant(
      of: preview,
      matching: find.text(
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      ),
    );
    final date = find.descendant(
      of: preview,
      matching: find.text(
        '${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      ),
    );
    final name = find.descendant(of: preview, matching: find.text(course.name));
    expect(tester.widget<Text>(name).maxLines, 2);
    expect(
      tester.getTopLeft(status).dx,
      closeTo(tester.getTopLeft(name).dx, .001),
    );
    expect(
      tester.getTopLeft(name).dy,
      greaterThan(tester.getBottomLeft(status).dy),
    );
    expect(
      tester.getTopLeft(time).dx,
      greaterThan(tester.getTopRight(name).dx),
    );
    expect(
      tester.getTopRight(time).dx,
      closeTo(tester.getTopRight(date).dx, .001),
    );
    expect(
      tester.getTopLeft(date).dy,
      greaterThan(tester.getBottomLeft(time).dy),
    );
    expect(
      find.descendant(of: preview, matching: find.text(course.location)),
      findsNothing,
    );
    expect(events, isEmpty);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('manual refresh fetches data before generating a snapshot', (
    tester,
  ) async {
    final l10n = await open(tester);
    final refresh = find.text(l10n.nextCourseWidgetRefresh);
    await reveal(tester, refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(events, ['network', 'snapshot']);
    expect(calls, isEmpty);
    expect(find.text(l10n.nextCourseWidgetUpdated), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('failed network refresh keeps the cache and shows failure', (
    tester,
  ) async {
    sync.refreshSucceeds = false;
    final previous = NextCourseWidgetSnapshot(
      generatedAt: DateTime.utc(2026, 9, 13, 16),
      days: const [],
    );
    widgets.snapshot.value = previous;
    final l10n = await open(tester);
    final refresh = find.text(l10n.nextCourseWidgetRefresh);
    await reveal(tester, refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(events, ['network', 'snapshot']);
    expect(widgets.snapshot.value, same(previous));
    expect(find.text(l10n.widgetSyncFailed), findsWidgets);
    expect(find.text(l10n.nextCourseWidgetUpdated), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('nightly preferences, permission link and resume reload work', (
    tester,
  ) async {
    final l10n = await open(tester);
    final enabled = find.widgetWithText(SwitchListTile, l10n.widgetSyncEnabled);
    await reveal(tester, enabled);
    await tester.tap(enabled);
    await tester.pumpAndSettle();
    expect(sync.enabled.value, isFalse);
    ListTile timeTile() => tester.widget<ListTile>(
      find.widgetWithText(ListTile, l10n.widgetSyncTime),
    );
    expect(timeTile().onTap, isNull);
    await tester.tap(enabled);
    await tester.pumpAndSettle();
    expect(sync.enabled.value, isTrue);
    final time = find.text(l10n.widgetSyncTime);
    await reveal(tester, time);
    await tester.tap(time);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialTime,
      const TimeOfDay(hour: 23, minute: 0),
    );
    final material = MaterialLocalizations.of(
      tester.element(find.byType(TimePickerDialog)),
    );
    await tester.tap(find.byTooltip(material.inputTimeModeButtonLabel));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '22');
    await tester.enterText(find.byType(TextField).at(1), '15');
    await tester.tap(find.text(material.okButtonLabel));
    await tester.pumpAndSettle();
    expect(sync.minutes.value, 22 * 60 + 15);
    final permission = find.text(l10n.reminderExactPermission);
    await reveal(tester, permission);
    await tester.tap(permission);
    await tester.pumpAndSettle();
    expect(sync.permissionRequests, 1);
    final before = sync.loads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(sync.loads, before + 1);
    expect(sync.reconciles, sync.loads);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('successful sync timestamps display in Beijing time', (
    tester,
  ) async {
    // This test compares timezone formatting across the permission/status rows;
    // scrolling itself is covered by the compact settings interaction tests.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    sync.status.value = WidgetSyncStatus(
      exactAllowed: true,
      lastSuccess: DateTime.utc(2026, 9, 13, 15, 45),
      nextAt: DateTime.utc(2026, 9, 14, 15),
    );
    final l10n = await open(tester, language: 'en');
    final last = find.widgetWithText(ListTile, l10n.widgetSyncLastSuccess);
    await reveal(tester, last);
    final value = tester.widget<ListTile>(last).subtitle! as Text;
    expect(value.data, contains('23:45'));
    expect(value.data, contains('Beijing time'));
    final permission = find.widgetWithText(
      ListTile,
      l10n.reminderExactPermission,
    );
    expect(
      (tester.widget<ListTile>(permission).subtitle! as Text).data,
      l10n.reminderPermissionGranted,
    );
    await reveal(tester, find.text(l10n.widgetSyncNext));
    expect(find.text(l10n.widgetSyncNext), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final language in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      for (final textScale in [1.4, 2.0]) {
        testWidgets(
          'MD3 variants fit narrow $language ${brightness.name} screens at $textScale text',
          (tester) async {
            tester.view.physicalSize = const Size(320, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final course = seedPreview(language);
            await open(
              tester,
              language: language,
              textScale: textScale,
              brightness: brightness,
            );
            for (final variant in NextCourseWidgetVariant.values) {
              final chip = find.byKey(
                ValueKey('widget-variant-${variant.name}'),
              );
              await reveal(tester, chip);
              await tester.tap(chip);
              await tester.pumpAndSettle();
              final preview = find.byKey(
                ValueKey('widget-preview-${variant.name}'),
              );
              await reveal(tester, preview);
              final decoration =
                  tester.widget<DecoratedBox>(preview).decoration
                      as BoxDecoration;
              final colors = Theme.of(tester.element(preview)).colorScheme;
              expect(decoration.color, colors.surfaceContainer);
              expect(decoration.borderRadius, BorderRadius.circular(28));
              final bounds = tester.getRect(preview);
              expect(bounds.left, greaterThanOrEqualTo(16));
              expect(bounds.right, lessThanOrEqualTo(304));
              expect(
                find.descendant(of: preview, matching: find.text(course.name)),
                findsOneWidget,
              );
              if (variant != NextCourseWidgetVariant.timetable) {
                expect(
                  find.descendant(
                    of: preview,
                    matching: find.text(course.location),
                  ),
                  variant == NextCourseWidgetVariant.square
                      ? findsOneWidget
                      : findsNothing,
                );
              }
              expect(tester.takeException(), isNull);
            }
            expect(events, isEmpty);
            expect(calls, isEmpty);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.android),
        );
      }
    }
  }

  testWidgets('unsupported hosts do not initialize nightly updates', (
    tester,
  ) async {
    final l10n = await open(tester);
    expect(find.text(l10n.nextCourseWidgetUnsupported), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(sync.loads, 0);
    expect(sync.reconciles, 0);
    expect(events, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
