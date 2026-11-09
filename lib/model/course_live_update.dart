import 'package:fzu_assistant/model/next_course_widget.dart';

enum CourseLiveUpdatePreview { inProgress, ended, nextClass }

enum CourseDayPart {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening');

  const CourseDayPart(this.label);
  final String label;

  static CourseDayPart forPeriod(int period) => switch (period) {
    <= 4 => morning,
    <= 8 => afternoon,
    _ => evening,
  };
}

class CourseLiveUpdateFrame {
  const CourseLiveUpdateFrame(
    this.state,
    this.courses, {
    List<NextCourseWidgetEntry>? partCourses,
  }) : partCourses = partCourses ?? courses;

  final CourseLiveUpdatePreview state;
  final List<NextCourseWidgetEntry> courses;
  final List<NextCourseWidgetEntry> partCourses;

  CourseDayPart get part => CourseDayPart.forPeriod(courses.first.startClass);
  DateTime get start => courses.first.start;
  DateTime get end => courses
      .map((course) => course.end)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime get progressStart => partCourses
      .map((course) => course.start)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime get progressEnd => partCourses
      .map((course) => course.end)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  List<({int seconds, bool isBreak})> get progressSegments {
    final ordered = [...partCourses]
      ..sort((a, b) => a.start.compareTo(b.start));
    final origin = ordered.first.start;
    final segments = <({int seconds, bool isBreak})>[];
    var elapsed = 0;
    void addUntil(DateTime time, {required bool isBreak}) {
      final boundary = time.difference(origin).inSeconds;
      if (boundary > elapsed) {
        segments.add((seconds: boundary - elapsed, isBreak: isBreak));
      }
      elapsed = boundary;
    }

    var blockEnd = ordered.first.end;
    for (final course in ordered.skip(1)) {
      if (course.start.isAfter(blockEnd)) {
        addUntil(blockEnd, isBreak: false);
        addUntil(course.start, isBreak: true);
        blockEnd = course.end;
      } else if (course.end.isAfter(blockEnd)) {
        blockEnd = course.end;
      }
    }
    addUntil(blockEnd, isBreak: false);
    return segments.isEmpty ? [(seconds: 1, isBreak: false)] : segments;
  }
}

/// Consumes one day's already filtered timetable, including adjusted/custom
/// courses. Gaps keep tracking the next class only within the same day part.
class CourseLiveUpdateTimeline {
  CourseLiveUpdateTimeline(List<NextCourseWidgetEntry> courses)
    : courses =
          courses
              .where(
                (course) =>
                    course.startClass >= 1 &&
                    course.endClass >= course.startClass &&
                    course.endClass <= 11 &&
                    course.end.isAfter(course.start),
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));

  final List<NextCourseWidgetEntry> courses;
  static const endedLifetime = Duration(minutes: 5);

  CourseLiveUpdateFrame? at(DateTime now) {
    final active = courses
        .where(
          (course) => !course.start.isAfter(now) && course.end.isAfter(now),
        )
        .toList();
    if (active.isNotEmpty) {
      return _frame(CourseLiveUpdatePreview.inProgress, active);
    }

    final completed = courses.where((course) => !course.end.isAfter(now));
    if (completed.isNotEmpty) {
      final last = completed.reduce((a, b) => a.end.isAfter(b.end) ? a : b);
      final part = CourseDayPart.forPeriod(last.startClass);
      final next = courses
          .where(
            (course) =>
                course.start.isAfter(now) &&
                CourseDayPart.forPeriod(course.startClass) == part,
          )
          .toList();
      if (next.isNotEmpty) {
        return _frame(
          CourseLiveUpdatePreview.nextClass,
          next.where((course) => course.start == next.first.start).toList(),
        );
      }
      if (now.isBefore(last.end.add(endedLifetime))) {
        return _frame(CourseLiveUpdatePreview.ended, [
          ...completed.where((course) => course.end == last.end),
        ]);
      }
    }
    final upcoming = courses.where((course) => course.start.isAfter(now));
    if (upcoming.isNotEmpty &&
        upcoming.first.start.difference(now) <= const Duration(minutes: 5)) {
      return _frame(
        CourseLiveUpdatePreview.nextClass,
        upcoming
            .where((course) => course.start == upcoming.first.start)
            .toList(),
      );
    }
    return null;
  }

  CourseLiveUpdateFrame _frame(
    CourseLiveUpdatePreview state,
    List<NextCourseWidgetEntry> selected,
  ) => CourseLiveUpdateFrame(
    state,
    selected,
    partCourses: courses
        .where(
          (course) =>
              CourseDayPart.forPeriod(course.startClass) ==
              CourseDayPart.forPeriod(selected.first.startClass),
        )
        .toList(),
  );

  DateTime? nextChangeAfter(DateTime now) {
    final changes = [
      for (final course in courses) ...[course.start, course.end],
      for (final part in CourseDayPart.values)
        if (courses.any(
          (course) => CourseDayPart.forPeriod(course.startClass) == part,
        ))
          courses
              .firstWhere(
                (course) => CourseDayPart.forPeriod(course.startClass) == part,
              )
              .start
              .subtract(const Duration(minutes: 5)),
    ].where((time) => time.isAfter(now)).toList()..sort();
    return changes.firstOrNull;
  }
}
