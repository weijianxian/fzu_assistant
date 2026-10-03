import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  test('大纲和授课计划保留完整课程参数，移除旧会话 id', () {
    final doc = html_parser.parse('''
      <table><tr><td>
        <a href="javascript:pop1('/student/kcdg.aspx?kcid=123&amp;xnxq=202601&amp;id=OLD')">大纲</a>
        <a href="javascript:pop1('/student/jh.aspx?kcid=123&amp;bh=456&amp;id=OLD')">计划</a>
      </td></tr></table>
    ''');
    final links = CourseService.extractLinks(doc.querySelector('td')!);
    expect(links, hasLength(2));
    expect(Uri.parse(links[0]).queryParameters, {
      'kcid': '123',
      'xnxq': '202601',
    });
    expect(Uri.parse(links[1]).queryParameters, {'kcid': '123', 'bh': '456'});
    expect(Uri.parse(links[0]).host, 'jwcjwxt2.fzu.edu.cn');
  });

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
