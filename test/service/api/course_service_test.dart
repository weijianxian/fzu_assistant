import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/service/api/course_service.dart';

void main() {
  group('CourseService.getFirstMondayFromTerm', () {
    test('returns the Monday containing the first term day', () {
      const term = CalTerm(
        termId: '1',
        schoolYear: '2024-2025',
        term: '202401',
        startDate: '2024-09-04',
        endDate: '2025-01-10',
      );

      expect(CourseService.getFirstMondayFromTerm(term), DateTime(2024, 9, 2));
    });

    test('returns null for an invalid start date', () {
      const term = CalTerm(
        termId: '1',
        schoolYear: '2024-2025',
        term: '202401',
        startDate: 'invalid',
        endDate: '',
      );

      expect(CourseService.getFirstMondayFromTerm(term), isNull);
    });
  });

  group('course week calculations', () {
    final firstMonday = DateTime(2024, 9, 2);

    test('calculates and clamps display weeks', () {
      expect(
        CourseService.getWeekFromFirstMonday(firstMonday, DateTime(2024, 9, 2)),
        1,
      );
      expect(
        CourseService.getWeekFromFirstMonday(
          firstMonday,
          DateTime(2024, 9, 16),
        ),
        3,
      );
      expect(
        CourseService.getWeekFromFirstMonday(firstMonday, DateTime(2024, 8, 1)),
        1,
      );
      expect(
        CourseService.getWeekFromFirstMonday(
          firstMonday,
          DateTime(2025, 12, 1),
        ),
        CourseService.totalScheduleWeeks,
      );
    });

    test('returns null outside the actual schedule range', () {
      expect(
        CourseService.getScheduleWeekForDate(
          firstMonday,
          firstMonday.subtract(const Duration(days: 1)),
        ),
        isNull,
      );
      expect(CourseService.getScheduleWeekForDate(firstMonday, firstMonday), 1);
      expect(
        CourseService.getScheduleWeekForDate(
          firstMonday,
          firstMonday.add(const Duration(days: 132)),
        ),
        CourseService.totalScheduleWeeks,
      );
      expect(
        CourseService.getScheduleWeekForDate(
          firstMonday,
          firstMonday.add(const Duration(days: 133)),
        ),
        isNull,
      );
    });

    test('normalizes time-of-day before calculating a week', () {
      expect(
        CourseService.getScheduleWeekForDate(
          DateTime(2024, 9, 2, 23, 30),
          DateTime(2024, 9, 9, 0, 1),
        ),
        2,
      );
    });
  });
}
