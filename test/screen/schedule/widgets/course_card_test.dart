import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/screen/schedule/widgets/course_card.dart';
import 'package:fzu_assistant/screen/schedule/widgets/schedule_grid.dart';
import 'package:fzu_assistant/service/app_themes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

void main() {
  const course = Course(
    type: '',
    name: '高等数学与线性代数 Advanced Mathematics',
    credits: '4',
    electiveType: '',
    examType: '',
    teacher: '',
    scheduleRules: [],
    adjustRules: [],
    rawExamTime: '',
    remark: '',
    syllabus: '',
    lessonplan: '',
  );

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'Windows single-period card fits at $brightness and text scale $scale',
        (tester) async {
          var tapped = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(Colors.deepPurple, brightness: brightness),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Center(
                    child: SizedBox(
                      width: 100,
                      height: 50,
                      child: CourseCard(
                        course: course,
                        location: '旗山校区公共教学楼东三 301',
                        onTap: () => tapped = true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(CourseCard));
          expect(tapped, isTrue);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  testWidgets('Windows schedule labels fit when system text is enlarged', (
    tester,
  ) async {
    final settings = AppSettings();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          theme: buildTheme(Colors.deepPurple),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: ScheduleGrid(
                courses: const [],
                examRooms: const [],
                week: 1,
                firstMonday: DateTime(2026, 9, 28),
                onRefresh: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9/28'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
