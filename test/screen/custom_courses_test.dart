import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/settings/custom_courses_page.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

CustomCourse _course({
  String id = 'current',
  String account = 'student-a',
  String term = '202601',
  String name = '当前课程',
}) => CustomCourse(
  id: id,
  account: account,
  term: term,
  name: name,
  startClass: 1,
  endClass: 2,
  startWeek: 1,
  endWeek: 19,
  weekday: 1,
);

Widget _app(AppSettings settings, CustomCourseStore store) =>
    AppSettingsProvider(
      settings: settings,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CustomCoursesPage(
          store: store,
          accountProvider: () => 'student-a',
        ),
        onGenerateRoute: (route) {
          expect(route.name, AppRoutes.customCourseEdit);
          return MaterialPageRoute<void>(
            settings: route,
            builder: (_) => CustomCourseEditPage(
              args: route.arguments as CustomCourseEditArgs,
              store: store,
              accountProvider: () => 'student-a',
            ),
          );
        },
      ),
    );

void main() {
  for (final size in [const Size(360, 740), const Size(1000, 600)]) {
    testWidgets(
      'custom course editor and management stay account/term scoped at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final settings = AppSettings();
        final store = CustomCourseStore();
        await settings.load();
        settings.termsKey.value = ['202601', '202501'];
        settings.selectedSemesterKey.value = '202601';
        await store.replaceAll([
          _course(),
          _course(id: 'other-account', account: 'student-b', name: '其他账号课程'),
          _course(id: 'previous-term', term: '202501', name: '历史学期课程'),
        ]);
        addTearDown(settings.dispose);
        addTearDown(store.dispose);
        await tester.pumpWidget(_app(settings, store));
        await tester.pumpAndSettle();
        expect(find.text('当前课程'), findsOneWidget);
        expect(find.text('其他账号课程'), findsNothing);
        expect(find.text('历史学期课程'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('添加课程'), findsNothing);
        // Creation is entered from the timetable action; the management page
        // only supplies edit/delete actions for existing custom courses.
        unawaited(
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .pushNamed<void>(
                AppRoutes.customCourseEdit,
                arguments: const CustomCourseEditArgs(term: '202601'),
              ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, '课程名称'),
          '新实验课',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final mainScroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomCourseEditPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        for (var i = 0; i < 6; i++) {
          mainScroll.position.jumpTo(mainScroll.position.maxScrollExtent);
          await tester.pump();
        }
        await tester.ensureVisible(find.text('保存课程'));
        await tester.tap(find.text('保存课程'));
        await tester.pumpAndSettle();
        expect(
          store.forTerm('student-a', '202601').map((entry) => entry.name),
          contains('新实验课'),
        );
        expect(store.value, hasLength(4));
        expect(find.text('新实验课'), findsOneWidget);
        await tester.tap(find.text('新实验课'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, '课程名称'),
          '修改后的实验课',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final editScroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomCourseEditPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        for (var i = 0; i < 6; i++) {
          editScroll.position.jumpTo(editScroll.position.maxScrollExtent);
          await tester.pump();
        }
        await tester.ensureVisible(find.text('保存课程'));
        await tester.tap(find.text('保存课程'));
        await tester.pumpAndSettle();
        expect(find.text('新实验课'), findsNothing);
        expect(find.text('修改后的实验课'), findsOneWidget);
        final tile = find.ancestor(
          of: find.text('修改后的实验课'),
          matching: find.byType(ListTile),
        );
        await tester.tap(
          find.descendant(
            of: tile,
            matching: find.byIcon(Icons.delete_outline),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '删除课程'));
        await tester.pumpAndSettle();
        expect(find.text('修改后的实验课'), findsNothing);
        expect(store.value, hasLength(3));
        expect(store.forTerm('student-b', '202601').single.name, '其他账号课程');
        expect(store.forTerm('student-a', '202501').single.name, '历史学期课程');
        final reloaded = CustomCourseStore();
        await reloaded.load();
        expect(reloaded.value, hasLength(3));
        reloaded.dispose();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
