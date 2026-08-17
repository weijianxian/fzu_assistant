import 'package:fzu_assistant/model/course.dart';

const coursePeriodTimes = [
  ('8:20', '9:05'),
  ('9:15', '10:00'),
  ('10:20', '11:05'),
  ('11:15', '12:00'),
  ('14:00', '14:45'),
  ('14:55', '15:40'),
  ('15:50', '16:35'),
  ('16:45', '17:30'),
  ('19:00', '19:45'),
  ('19:55', '20:40'),
  ('20:50', '21:35'),
];

final maxCoursePeriod = coursePeriodTimes.length;

class CourseSession {
  final Course course;
  final int startClass;
  final int endClass;
  final String location;
  final bool adjusted;

  const CourseSession({
    required this.course,
    required this.startClass,
    required this.endClass,
    required this.location,
    required this.adjusted,
  });
}

abstract final class CourseSessions {
  static List<CourseSession> forDay({
    required List<Course> courses,
    required int week,
    required int weekday,
    required bool autoAdjust,
  }) {
    final sessions = <CourseSession>[];

    for (final course in courses) {
      final canceledSlots = <(int, int)>[];
      final adjustedSlots = <CourseAdjustRule>[];

      if (autoAdjust) {
        for (final adjustment in course.adjustRules) {
          if (adjustment.oldWeek == week && adjustment.oldWeekday == weekday) {
            canceledSlots.add((
              adjustment.oldStartClass,
              adjustment.oldEndClass,
            ));
          }
          if (adjustment.newWeek == week &&
              adjustment.newWeekday == weekday &&
              !adjustment.canceled) {
            adjustedSlots.add(adjustment);
          }
        }
      }

      for (final rule in course.scheduleRules) {
        if (rule.weekday != weekday) continue;
        if (rule.startWeek > week || rule.endWeek < week) continue;
        if (rule.single && !rule.double && week.isEven) continue;
        if (rule.double && !rule.single && week.isOdd) continue;
        if (rule.startClass < 1 || rule.startClass > maxCoursePeriod) continue;

        final isCanceled = canceledSlots.any(
          (slot) => rule.startClass == slot.$1 && rule.endClass == slot.$2,
        );
        if (isCanceled) continue;

        sessions.add(
          CourseSession(
            course: course,
            startClass: rule.startClass,
            endClass: rule.endClass.clamp(1, maxCoursePeriod),
            location: rule.location,
            adjusted: false,
          ),
        );
      }

      for (final adjustment in adjustedSlots) {
        if (adjustment.newStartClass < 1 ||
            adjustment.newStartClass > maxCoursePeriod) {
          continue;
        }
        sessions.add(
          CourseSession(
            course: course,
            startClass: adjustment.newStartClass,
            endClass: adjustment.newEndClass.clamp(1, maxCoursePeriod),
            location: adjustment.newLocation,
            adjusted: true,
          ),
        );
      }
    }

    sessions.sort((a, b) {
      final byStart = a.startClass.compareTo(b.startClass);
      if (byStart != 0) return byStart;
      return a.endClass.compareTo(b.endClass);
    });
    return sessions;
  }
}
