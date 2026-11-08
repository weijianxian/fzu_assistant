import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/course_live_update.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';

void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 11, 8, hour - 8, minute);
  NextCourseWidgetEntry course(
    String name,
    int startClass,
    int endClass,
    DateTime start,
    DateTime end,
  ) => NextCourseWidgetEntry(
    name: name,
    location: 'Room A',
    start: start,
    end: end,
    startClass: startClass,
    endClass: endClass,
    week: 9,
  );

  final first = course('Morning 1', 1, 2, at(8, 20), at(10));
  final second = course('Morning 2', 3, 4, at(10, 20), at(12));
  final afternoon = course('Afternoon', 5, 8, at(14), at(17, 30));
  final evening = course('Evening', 9, 11, at(19), at(21, 35));
  final timeline = CourseLiveUpdateTimeline([
    evening,
    second,
    first,
    afternoon,
  ]);

  test('a break within the morning points to the next morning class', () {
    expect(timeline.at(at(9))!.state, CourseLiveUpdatePreview.inProgress);
    final breakTime = timeline.at(at(10))!;
    expect(breakTime.state, CourseLiveUpdatePreview.nextClass);
    expect(breakTime.courses.single.name, 'Morning 2');
    expect(breakTime.part, CourseDayPart.morning);
    expect(timeline.nextChangeAfter(at(10)), at(10, 20));
    expect(timeline.at(at(10, 20))!.state, CourseLiveUpdatePreview.inProgress);
  });

  test('each day part ends without pointing to the following part', () {
    for (final (time, part) in [
      (at(12), CourseDayPart.morning),
      (at(17, 30), CourseDayPart.afternoon),
      (at(21, 35), CourseDayPart.evening),
    ]) {
      final frame = timeline.at(time)!;
      expect(frame.state, CourseLiveUpdatePreview.ended);
      expect(frame.part, part);
    }
    expect(timeline.at(at(12, 5)), isNull);
    expect(timeline.at(at(18)), isNull);
    expect(timeline.at(at(8)), isNull);
    expect(timeline.at(at(14))!.part, CourseDayPart.afternoon);
    expect(timeline.at(at(14))!.state, CourseLiveUpdatePreview.inProgress);
  });

  test('a filtered last class ends the morning earlier', () {
    final filtered = CourseLiveUpdateTimeline([first, afternoon]);
    final frame = filtered.at(at(10))!;
    expect(frame.state, CourseLiveUpdatePreview.ended);
    expect(frame.courses.single.name, 'Morning 1');
    expect(frame.part, CourseDayPart.morning);
    expect(filtered.at(at(10, 10)), isNull);
  });

  test('parallel classes stay active until all of them have ended', () {
    final longer = course('Longer', 1, 3, at(8, 20), at(11, 5));
    final overlapping = CourseLiveUpdateTimeline([longer, first, second]);
    expect(overlapping.at(at(9))!.courses, hasLength(2));
    expect(overlapping.at(at(9))!.end, at(10));
    final frame = overlapping.at(at(10))!;
    expect(frame.state, CourseLiveUpdatePreview.inProgress);
    expect(frame.courses.single.name, 'Longer');
    expect(
      overlapping.at(at(11, 10))!.state,
      CourseLiveUpdatePreview.inProgress,
    );
    expect(overlapping.at(at(12))!.state, CourseLiveUpdatePreview.ended);
  });

  test('invalid periods and reversed durations cannot create reminders', () {
    final invalid = CourseLiveUpdateTimeline([
      course('Zero', 0, 1, at(8), at(9)),
      course('Beyond timetable', 12, 13, at(8), at(9)),
      course('Reversed periods', 3, 2, at(8), at(9)),
      course('Reversed time', 1, 2, at(9), at(8)),
    ]);
    expect(invalid.at(at(8)), isNull);
    expect(invalid.nextChangeAfter(at(8)), isNull);
  });
}
