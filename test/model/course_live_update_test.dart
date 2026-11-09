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

  test(
    'the whole morning keeps the same course blocks through every stage',
    () {
      for (final time in [
        at(8, 15),
        at(8, 20),
        at(9),
        at(10),
        at(10, 10),
        at(10, 20),
        at(11),
        at(12),
      ]) {
        final frame = timeline.at(time)!;
        expect(frame.partCourses, [first, second]);
        expect(frame.progressStart, at(8, 20));
        expect(frame.progressEnd, at(12));
        expect(frame.progressSegments, [
          (seconds: 100 * 60, isBreak: false),
          (seconds: 20 * 60, isBreak: true),
          (seconds: 100 * 60, isBreak: false),
        ]);
      }
    },
  );

  test('a course block is not split into its individual periods', () {
    final wholeMorning = CourseLiveUpdateTimeline([
      course('Whole morning', 1, 4, at(8, 20), at(12)),
    ]);
    expect(wholeMorning.at(at(9))!.progressSegments, [
      (seconds: 220 * 60, isBreak: false),
    ]);
  });

  test('a single period has one segment without an invented break', () {
    final single = CourseLiveUpdateTimeline([
      course('Single lesson', 11, 11, at(20, 50), at(21, 35)),
    ]);
    expect(single.at(at(21))!.progressSegments, [
      (seconds: 45 * 60, isBreak: false),
    ]);
  });

  test('compressed previews retain course blocks and the full time range', () {
    final start = at(8, 20);
    final compressed = CourseLiveUpdateTimeline([
      course('First', 1, 2, start, start.add(const Duration(seconds: 30))),
      course(
        'Second',
        3,
        4,
        start.add(const Duration(seconds: 60)),
        start.add(const Duration(seconds: 110)),
      ),
    ]);
    for (final seconds in [0, 30, 40, 60, 90, 110]) {
      final frame = compressed.at(start.add(Duration(seconds: seconds)))!;
      expect(frame.progressSegments, [
        (seconds: 30, isBreak: false),
        (seconds: 30, isBreak: true),
        (seconds: 50, isBreak: false),
      ]);
      expect(frame.progressStart, start);
      expect(frame.progressEnd, start.add(const Duration(seconds: 110)));
    }
  });

  test('overlapping courses are merged without changing stage deadlines', () {
    final longer = course('Longer', 1, 3, at(8, 20), at(11, 5));
    final overlapping = CourseLiveUpdateTimeline([second, longer, first]);
    final frame = overlapping.at(at(9))!;
    expect(frame.end, at(10));
    expect(frame.progressEnd, at(12));
    expect(frame.progressSegments, [(seconds: 220 * 60, isBreak: false)]);
    expect(overlapping.at(at(10))!.progressSegments, frame.progressSegments);
    expect(
      overlapping.at(at(11, 10))!.progressSegments,
      frame.progressSegments,
    );
  });

  test('nested and adjacent courses do not invent breaks or count twice', () {
    final overlapping = CourseLiveUpdateTimeline([
      course('Later', 3, 4, at(10, 20), at(12)),
      course('Nested', 1, 1, at(8, 30), at(9)),
      course('Adjacent', 1, 2, at(9, 20), at(10)),
      course('First', 1, 2, at(8, 20), at(9, 20)),
    ]);
    expect(overlapping.at(at(9))!.progressSegments, [
      (seconds: 100 * 60, isBreak: false),
      (seconds: 20 * 60, isBreak: true),
      (seconds: 100 * 60, isBreak: false),
    ]);
  });

  test('a break within the morning points to the next morning class', () {
    expect(timeline.at(at(9))!.state, CourseLiveUpdatePreview.inProgress);
    final breakTime = timeline.at(at(10))!;
    expect(breakTime.state, CourseLiveUpdatePreview.nextClass);
    expect(breakTime.courses.single.name, 'Morning 2');
    expect(breakTime.part, CourseDayPart.morning);
    expect(breakTime.start, second.start);
    expect(breakTime.end, second.end);
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
    for (final (time, entry) in [(at(14), afternoon), (at(19), evening)]) {
      final frame = timeline.at(time)!;
      expect(frame.partCourses, [entry]);
      expect(frame.progressStart, entry.start);
      expect(frame.progressEnd, entry.end);
    }
  });

  test('a filtered last class ends the morning earlier', () {
    final filtered = CourseLiveUpdateTimeline([first, afternoon]);
    final frame = filtered.at(at(10))!;
    expect(frame.state, CourseLiveUpdatePreview.ended);
    expect(frame.courses.single.name, 'Morning 1');
    expect(frame.part, CourseDayPart.morning);
    expect(frame.progressStart, first.start);
    expect(frame.progressEnd, first.end);
    expect(frame.progressSegments, [(seconds: 100 * 60, isBreak: false)]);
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
