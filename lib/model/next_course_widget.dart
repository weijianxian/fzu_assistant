import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';

/// Native provider names are selected by the stable enum name on the channel.
enum NextCourseWidgetVariant { compact, square, timetable }

/// A minimal, credential-free snapshot consumed by the native Android widget.
///
/// Dates are epoch milliseconds, calculated from Beijing calendar dates. Neither
/// account IDs, course identifiers, cookies nor QR code data are serialized.
class NextCourseWidgetSnapshot {
  const NextCourseWidgetSnapshot({
    required this.generatedAt,
    required this.days,
    this.sourceUpdatedAt,
    this.signedIn = true,
    this.locale = 'system',
  });

  final DateTime generatedAt;
  final DateTime? sourceUpdatedAt;
  final bool signedIn;
  final String locale;
  final List<NextCourseWidgetDay> days;

  static const beijingOffset = Duration(hours: 8);

  factory NextCourseWidgetSnapshot.build({
    required String account,
    required List<CalTerm> terms,
    required Map<String, List<Course>> coursesByTerm,
    required DateTime now,
    required bool autoAdjust,
    DateTime? sourceUpdatedAt,
    List<CustomCourse> customCourses = const [],
    List<HiddenCourseSession> hiddenSessions = const [],
    String locale = 'system',
    int horizonDays = 180,
    int totalScheduleWeeks = 19,
  }) {
    final beijing = now.toUtc().add(beijingOffset);
    final today = DateTime.utc(beijing.year, beijing.month, beijing.day);
    // Retain elapsed days in this week, so a weekly widget always has Monday
    // through Sunday even when the snapshot is rebuilt late in the week.
    final firstDay = today.subtract(Duration(days: today.weekday - 1));
    final days = <NextCourseWidgetDay>[];
    for (var i = 0; i < horizonDays.clamp(0, 180); i++) {
      final day = firstDay.add(Duration(days: i));
      CalTerm? term;
      DateTime? monday;
      for (final candidate in terms) {
        final start = _calendarDate(candidate.startDate);
        final end = _calendarDate(candidate.endDate);
        if (start == null || end == null || end.isBefore(start)) continue;
        if (!day.isBefore(start) && !day.isAfter(end)) {
          term = candidate;
          monday = start.subtract(Duration(days: start.weekday - 1));
          break;
        }
      }
      final offset = monday == null ? -1 : day.difference(monday).inDays;
      final week = offset ~/ 7 + 1;
      final courses = term == null ? null : coursesByTerm[term.term];
      final known =
          account.isNotEmpty &&
          courses != null &&
          offset >= 0 &&
          week >= 1 &&
          week <= totalScheduleWeeks;
      final sessions = known
          ? CourseSessions.forDay(
              courses: [
                ...courses,
                ...customCourses
                    .where((c) => c.account == account && c.term == term!.term)
                    .map((c) => c.toCourse()),
              ],
              week: week,
              weekday: day.weekday,
              autoAdjust: autoAdjust,
              account: account,
              term: term!.term,
              hiddenSessions: hiddenSessions,
            )
          : <CourseSession>[];
      days.add(
        NextCourseWidgetDay(
          start: day.subtract(beijingOffset),
          known: known,
          week: offset >= 0 && week >= 1 && week <= totalScheduleWeeks
              ? week
              : null,
          courses: [
            for (final session in sessions)
              if (session.startClass >= 1 &&
                  session.endClass >= session.startClass &&
                  session.endClass <= coursePeriodTimes.length)
                NextCourseWidgetEntry(
                  name: session.course.name,
                  location: session.location,
                  start: _atPeriod(day, session.startClass, end: false),
                  end: _atPeriod(day, session.endClass, end: true),
                  startClass: session.startClass,
                  endClass: session.endClass,
                  week: week,
                ),
          ],
        ),
      );
    }
    return NextCourseWidgetSnapshot(
      generatedAt: now.toUtc(),
      sourceUpdatedAt:
          account.isNotEmpty &&
              sourceUpdatedAt != null &&
              sourceUpdatedAt.millisecondsSinceEpoch > 0 &&
              !sourceUpdatedAt.isAfter(now)
          ? sourceUpdatedAt.toUtc()
          : null,
      signedIn: account.isNotEmpty,
      locale: locale,
      days: List.unmodifiable(days),
    );
  }

  static DateTime? _calendarDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? null
        : DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  static DateTime _atPeriod(DateTime day, int period, {required bool end}) {
    final time = end
        ? coursePeriodTimes[period - 1].$2
        : coursePeriodTimes[period - 1].$1;
    final parts = time.split(':');
    return day
        .add(Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1])))
        .subtract(beijingOffset);
  }

  /// Unknown coverage is a barrier: never jump over an uncached day to claim a
  /// later class is definitely the next one.
  NextCourseWidgetSelection select(DateTime now) {
    if (!signedIn) {
      return const NextCourseWidgetSelection(NextCourseWidgetState.signedOut);
    }
    final instant = now.toUtc();
    final index = days.indexWhere(
      (day) =>
          !instant.isBefore(day.start) &&
          instant.isBefore(day.start.add(const Duration(days: 1))),
    );
    if (index < 0 || !days[index].known) {
      return const NextCourseWidgetSelection(NextCourseWidgetState.unknown);
    }
    for (var i = index; i < days.length; i++) {
      final day = days[i];
      if (!day.known) {
        return const NextCourseWidgetSelection(NextCourseWidgetState.unknown);
      }
      final entries = day.courses
          .where((entry) => entry.end.isAfter(instant))
          .toList();
      if (entries.isEmpty) continue;
      final first = entries.first;
      return NextCourseWidgetSelection(
        first.start.isAfter(instant)
            ? NextCourseWidgetState.upcoming
            : NextCourseWidgetState.inProgress,
        courses: entries.where((entry) => entry.start == first.start).toList(),
      );
    }
    return const NextCourseWidgetSelection(NextCourseWidgetState.noUpcoming);
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'generatedAt': generatedAt.millisecondsSinceEpoch,
    if (sourceUpdatedAt != null)
      'sourceUpdatedAt': sourceUpdatedAt!.millisecondsSinceEpoch,
    'signedIn': signedIn,
    'locale': locale,
    'days': days.map((day) => day.toJson()).toList(),
  };
}

class NextCourseWidgetDay {
  const NextCourseWidgetDay({
    required this.start,
    required this.known,
    required this.courses,
    this.week,
  });

  final DateTime start;
  final bool known;
  final int? week;
  final List<NextCourseWidgetEntry> courses;

  Map<String, Object> toJson() => {
    'start': start.millisecondsSinceEpoch,
    'known': known,
    'week': ?week,
    'courses': courses.map((course) => course.toJson()).toList(),
  };
}

class NextCourseWidgetEntry {
  const NextCourseWidgetEntry({
    required this.name,
    required this.location,
    required this.start,
    required this.end,
    required this.startClass,
    required this.endClass,
    required this.week,
  });

  final String name, location;
  final DateTime start, end;
  final int startClass, endClass, week;

  Map<String, Object> toJson() => {
    'name': name,
    'location': location,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'startClass': startClass,
    'endClass': endClass,
    'week': week,
  };
}

enum NextCourseWidgetState {
  signedOut,
  unknown,
  upcoming,
  inProgress,
  noUpcoming,
}

class NextCourseWidgetSelection {
  const NextCourseWidgetSelection(this.state, {this.courses = const []});
  final NextCourseWidgetState state;
  final List<NextCourseWidgetEntry> courses;
}
