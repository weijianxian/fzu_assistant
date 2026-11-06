import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/model/hidden_course_session.dart';

/// Shared occurrence model for ICS and native recurrence planning.
class ScheduleCalendarEvent {
  const ScheduleCalendarEvent({
    required this.uid,
    required this.term,
    required this.title,
    required this.location,
    required this.description,
    required this.start,
    required this.end,
    required this.reminderMinutes,
    required this.courseKey,
    this.isExam = false,
  });
  final String uid, term, title, location, description, courseKey;
  final DateTime start, end;
  final int reminderMinutes;
  final bool isExam;

  Map<String, Object> toJson() => {
    'uid': 'fzu-v1:$term:$uid',
    'title': title,
    'location': location,
    'description': description,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'reminder': reminderMinutes,
  };
}

class CalendarExport {
  const CalendarExport({
    required this.content,
    required this.eventCount,
    required this.skippedExams,
    required this.events,
    required this.protectedUids,
  });

  final String content;
  final int eventCount;
  final int skippedExams;
  final List<ScheduleCalendarEvent> events;
  final List<String> protectedUids;

  /// Expand actual timetable occurrences for ICS; Android compacts these into
  /// system recurrence rules and single-instance exceptions before writing.
  static CalendarExport build({
    required String account,
    required CalTerm term,
    required List<Course> courses,
    required List<HiddenCourseSession> hiddenSessions,
    required bool autoAdjust,
    required bool includeExams,
    required int reminderMinutes,
    required String calendarName,
    required DateTime generatedAt,
  }) {
    DateTime calendarDay(String value) {
      final parsed = DateTime.parse(value);
      if (parsed.toIso8601String().substring(0, 10) != value) {
        throw const FormatException('学期日期无效，请刷新校历');
      }
      return DateTime.utc(parsed.year, parsed.month, parsed.day);
    }

    final first = calendarDay(term.startDate);
    final last = calendarDay(term.endDate);
    if (account.isEmpty ||
        last.isBefore(first) ||
        last.difference(first).inDays > 366) {
      throw const FormatException('学期日期或账号无效，请刷新课表');
    }
    final monday = first.subtract(Duration(days: first.weekday - 1));
    final lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//FZU Assistant//Schedule//ZH',
      'CALSCALE:GREGORIAN',
      'X-WR-CALNAME:${escape(calendarName)}',
      'X-WR-TIMEZONE:Asia/Shanghai',
    ];
    final identities = <String>{};
    final events = <ScheduleCalendarEvent>[];
    final protectedUids = <String>[];
    String uidFor(String identity) =>
        sha256.convert(utf8.encode(identity)).toString();
    void add({
      required String identity,
      required String name,
      required String location,
      required String description,
      required DateTime start,
      required DateTime end,
      required String courseKey,
      bool isExam = false,
    }) {
      if (!end.isAfter(start) || !identities.add(identity)) return;
      final uid = uidFor(identity);
      events.add(
        ScheduleCalendarEvent(
          uid: uid,
          term: term.term,
          title: name,
          location: location,
          description: description,
          start: start,
          end: end,
          reminderMinutes: reminderMinutes.clamp(0, 1440),
          courseKey: courseKey,
          isExam: isExam,
        ),
      );
      lines.addAll([
        'BEGIN:VEVENT',
        'UID:$uid@fzu-assistant',
        'DTSTAMP:${_timestamp(generatedAt)}',
        'DTSTART:${_timestamp(start)}',
        'DTEND:${_timestamp(end)}',
        'SUMMARY:${escape(name)}',
        'LOCATION:${escape(location)}',
        'DESCRIPTION:${escape(description)}',
      ]);
      if (reminderMinutes > 0) {
        lines.addAll([
          'BEGIN:VALARM',
          'ACTION:DISPLAY',
          'TRIGGER:-PT${reminderMinutes.clamp(1, 1440)}M',
          'DESCRIPTION:${escape(name)}',
          'END:VALARM',
        ]);
      }
      lines.add('END:VEVENT');
    }

    DateTime atPeriod(DateTime day, int period, {required bool end}) {
      final times = coursePeriodTimes[period - 1];
      final parts = (end ? times.$2 : times.$1).split(':');
      return day
          .add(
            Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1])),
          )
          .subtract(const Duration(hours: 8));
    }

    for (
      var day = first;
      !day.isAfter(last);
      day = day.add(const Duration(days: 1))
    ) {
      final week = day.difference(monday).inDays ~/ 7 + 1;
      if (week > 19) break;
      final sessions = CourseSessions.forDay(
        courses: courses,
        week: week,
        weekday: day.weekday,
        autoAdjust: autoAdjust,
        account: account,
        term: term.term,
        hiddenSessions: hiddenSessions,
      );
      for (final session in sessions) {
        if (session.endClass < session.startClass) continue;
        add(
          identity: jsonEncode([
            account,
            term.term,
            HiddenCourseSession.keyForCourse(session.course),
            day.toIso8601String(),
            session.startClass,
            session.endClass,
          ]),
          name: session.course.name,
          location: session.location,
          description: session.course.teacher,
          start: atPeriod(day, session.startClass, end: false),
          end: atPeriod(day, session.endClass, end: true),
          courseKey: HiddenCourseSession.keyForCourse(session.course),
        );
      }
    }
    var skipped = 0;
    if (includeExams) {
      for (final course in courses) {
        if (course.rawExamTime.trim().isEmpty) continue;
        final exam = ExamRoomInfo.fromCourse(course);
        final start = exam.startTime, end = exam.endTime;
        final identity = jsonEncode([
          account,
          term.term,
          'exam',
          HiddenCourseSession.keyForCourse(course),
        ]);
        if (start == null || end == null) {
          skipped++;
          // An unparseable replacement must not erase an earlier valid exam.
          protectedUids.add('fzu-v1:${term.term}:${uidFor(identity)}');
          continue;
        }
        add(
          identity: identity,
          name: course.name,
          location: exam.location,
          description: [
            course.examType,
            course.teacher,
          ].where((s) => s.isNotEmpty).join(' · '),
          start: start,
          end: end,
          courseKey: HiddenCourseSession.keyForCourse(course),
          isExam: true,
        );
      }
    }
    lines.add('END:VCALENDAR');
    return CalendarExport(
      content: '${lines.map(_fold).join('\r\n')}\r\n',
      eventCount: identities.length,
      skippedExams: skipped,
      events: List.unmodifiable(events),
      protectedUids: List.unmodifiable(protectedUids),
    );
  }

  static String escape(String value) => value
      .replaceAll('\u0000', '')
      .replaceAll('\\', '\\\\')
      .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');

  static String _timestamp(DateTime value) =>
      '${value.toUtc().toIso8601String().substring(0, 19).replaceAll(RegExp(r'[-:]'), '')}Z';

  /// RFC 5545: 75 octets per physical line, never split a UTF-8 codepoint.
  static String _fold(String line) {
    final result = StringBuffer();
    var octets = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final length = utf8.encode(char).length;
      if (octets + length > 75) {
        result.write('\r\n ');
        octets = 1;
      }
      result.write(char);
      octets += length;
    }
    return result.toString();
  }
}
