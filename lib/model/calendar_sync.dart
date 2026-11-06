import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/calendar_export.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';

String calendarAccountKey(String account) =>
    sha256.convert(utf8.encode(account)).toString();

/// Only complete, freshly fetched terms may replace events in those terms.
Map<String, Object> buildCalendarSyncPayload({
  required String account,
  required List<CalTerm> terms,
  required Map<String, List<Course>> coursesByTerm,
  required List<CustomCourse> customCourses,
  required List<HiddenCourseSession> hiddenSessions,
  required bool autoAdjust,
  required bool includeExams,
  required int reminderMinutes,
  required DateTime now,
}) {
  if (terms.isEmpty ||
      terms.any((term) => !coursesByTerm.containsKey(term.term))) {
    throw StateError('课表数据不完整，保留已有日程');
  }
  final events = <Map<String, Object>>[];
  final protected = <String>[];
  var occurrenceCount = 0;
  for (final term in terms) {
    final courses = [
      ...coursesByTerm[term.term]!,
      ...customCourses
          .where((entry) => entry.account == account && entry.term == term.term)
          .map((entry) => entry.toCourse()),
    ];
    final expanded = CalendarExport.build(
      account: account,
      term: term,
      courses: courses,
      hiddenSessions: hiddenSessions,
      autoAdjust: autoAdjust,
      includeExams: includeExams,
      reminderMinutes: reminderMinutes,
      calendarName: '',
      generatedAt: now,
    );
    final base = CalendarExport.build(
      account: account,
      term: term,
      courses: courses,
      hiddenSessions: const [],
      autoAdjust: false,
      includeExams: false,
      reminderMinutes: reminderMinutes,
      calendarName: '',
      generatedAt: now,
    );
    // Expand in memory with the timetable's rules, but store weekly series and
    // native exceptions in the provider, never one row per ordinary occurrence.
    events.addAll(
      _recurringEvents(
        account: account,
        term: term,
        courses: courses,
        base: base.events,
        actual: expanded.events,
        autoAdjust: autoAdjust,
      ),
    );
    occurrenceCount += expanded.eventCount;
    protected.addAll(expanded.protectedUids);
  }
  return {
    'owner': calendarAccountKey(account),
    'terms': terms.map((term) => term.term).toList(),
    'events': events,
    'protected': protected,
    'occurrenceCount': occurrenceCount,
  };
}

String _uid(String term, Object identity) =>
    'fzu-v2:$term:${sha256.convert(utf8.encode(jsonEncode(identity)))}';

String _timestamp(DateTime value) =>
    '${value.toUtc().toIso8601String().substring(0, 19).replaceAll(RegExp(r'[-:]'), '')}Z';

class _CalendarSeries {
  _CalendarSeries(this.uid, this.instances);

  final String uid;
  final List<ScheduleCalendarEvent> instances;
  final excluded = <DateTime>{};
  final exceptions = <Map<String, Object>>[];
  ScheduleCalendarEvent get first => instances.first;

  int get interval =>
      instances.length > 1 &&
          instances.every(
            (event) => event.start.difference(first.start).inDays % 14 == 0,
          )
      ? 2
      : 1;

  Map<String, Object> toJson() {
    final step = Duration(days: 7 * interval);
    final scheduled = instances.map((event) => event.start).toSet();
    for (
      var time = first.start;
      !time.isAfter(instances.last.start);
      time = time.add(step)
    ) {
      if (!scheduled.contains(time)) excluded.add(time);
    }
    final count =
        instances.last.start.difference(first.start).inDays ~/ (7 * interval) +
        1;
    return {
      ...first.toJson(),
      'uid': uid,
      'rrule': 'FREQ=WEEKLY;INTERVAL=$interval;COUNT=$count',
      if (excluded.isNotEmpty)
        'exdate': (excluded.toList()..sort()).map(_timestamp).join(','),
    };
  }

  void replace(ScheduleCalendarEvent original, ScheduleCalendarEvent actual) {
    exceptions.add({
      ...actual.toJson(),
      'uid': _uid(original.term, [uid, original.start.millisecondsSinceEpoch]),
      'originalUid': uid,
      'originalStart': original.start.millisecondsSinceEpoch,
    });
  }
}

List<Map<String, Object>> _recurringEvents({
  required String account,
  required CalTerm term,
  required List<Course> courses,
  required List<ScheduleCalendarEvent> base,
  required List<ScheduleCalendarEvent> actual,
  required bool autoAdjust,
}) {
  final groups =
      <(String, int, int, int, String), List<ScheduleCalendarEvent>>{};
  for (final event in base) {
    final beijing = event.start.add(const Duration(hours: 8));
    final key = (
      event.courseKey,
      beijing.weekday,
      beijing.hour * 60 + beijing.minute,
      event.end.difference(event.start).inMinutes,
      event.location,
    );
    groups.putIfAbsent(key, () => []).add(event);
  }
  final series = [
    for (final entry in groups.entries)
      _CalendarSeries(
        _uid(term.term, [
          account,
          term.term,
          'series',
          entry.key.$1,
          entry.key.$2,
          entry.key.$3,
          entry.key.$4,
          entry.key.$5,
        ]),
        entry.value..sort((a, b) => a.start.compareTo(b.start)),
      ),
  ];
  final remaining = {
    for (final event in actual)
      if (!event.isExam) event.uid: event,
  };
  final missing = <(_CalendarSeries, ScheduleCalendarEvent)>[];
  // Claim all unchanged slots first; two adjustments into the same slot must
  // still produce only the one visible occurrence shown by the timetable.
  for (final group in series) {
    for (final original in group.instances) {
      final current = remaining.remove(original.uid);
      if (current == null) {
        missing.add((group, original));
      } else if (current.location != group.first.location) {
        group.replace(original, current);
      }
    }
  }
  final first = DateTime.parse('${term.startDate}T00:00:00Z');
  final monday = first.subtract(Duration(days: first.weekday - 1));

  DateTime? adjustedTime(int week, int weekday, int period, bool end) {
    if (week < 1 || weekday < 1 || weekday > 7 || period < 1) return null;
    if (!end && period > maxCoursePeriod) return null;
    final times = coursePeriodTimes[period.clamp(1, maxCoursePeriod) - 1];
    final parts = (end ? times.$2 : times.$1).split(':');
    return monday.add(
      Duration(
        days: (week - 1) * 7 + weekday - 1,
        hours: int.parse(parts[0]) - 8,
        minutes: int.parse(parts[1]),
      ),
    );
  }

  final adjustments = <String, List<CourseAdjustRule>>{};
  if (autoAdjust) {
    for (final course in courses) {
      adjustments
          .putIfAbsent(HiddenCourseSession.keyForCourse(course), () => [])
          .addAll(course.adjustRules);
    }
  }
  for (final (group, original) in missing) {
    ScheduleCalendarEvent? replacement;
    for (final change
        in adjustments[original.courseKey] ?? <CourseAdjustRule>[]) {
      if (change.canceled ||
          adjustedTime(
                change.oldWeek,
                change.oldWeekday,
                change.oldStartClass,
                false,
              ) !=
              original.start ||
          adjustedTime(
                change.oldWeek,
                change.oldWeekday,
                change.oldEndClass,
                true,
              ) !=
              original.end) {
        continue;
      }
      final start = adjustedTime(
        change.newWeek,
        change.newWeekday,
        change.newStartClass,
        false,
      );
      final end = adjustedTime(
        change.newWeek,
        change.newWeekday,
        change.newEndClass,
        true,
      );
      for (final event in remaining.values) {
        if (event.courseKey == original.courseKey &&
            event.start == start &&
            event.end == end) {
          replacement = event;
          break;
        }
      }
      if (replacement != null) break;
    }
    if (replacement == null) {
      group.excluded.add(original.start);
    } else {
      remaining.remove(replacement.uid);
      group.replace(original, replacement);
    }
  }
  return [
    for (final group in series) group.toJson(),
    for (final group in series) ...group.exceptions,
    // A genuine one-off added session without an original slot, and exams,
    // remain single events.
    ...remaining.values.map((event) => event.toJson()),
    ...actual.where((event) => event.isExam).map((event) => event.toJson()),
  ];
}
