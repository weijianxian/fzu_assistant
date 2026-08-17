import 'package:fzu_assistant/common/utils/date_text.dart';
import 'package:fzu_assistant/model/calendar.dart';

enum TimelineEventBoundary { single, starts, ends }

class TimelineEventEntry {
  final CalTermEvent event;
  final DateTime date;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final TimelineEventBoundary boundary;

  const TimelineEventEntry({
    required this.event,
    required this.date,
    required this.rangeStart,
    required this.rangeEnd,
    required this.boundary,
  });
}

class TimelineEventGroups {
  final List<TimelineEventEntry> dated;
  final List<CalTermEvent> other;

  const TimelineEventGroups({required this.dated, required this.other});
}

abstract final class TimelineEvents {
  static final _monthDayPattern = RegExp(r'(\d{1,2})\s*[月/-]\s*(\d{1,2})\s*日?');
  static final _yearPattern = RegExp(r'\d{4}\s*[年/-]');

  static TimelineEventGroups split(List<CalTermEvent> events) {
    final dated = <TimelineEventEntry>[];
    final other = <CalTermEvent>[];

    for (final event in events) {
      final start = _parseDate(event.startDate);
      if (start == null) {
        other.add(event);
        continue;
      }

      var end = _parseDate(event.endDate, fallbackYear: start.year) ?? start;
      if (end.isBefore(start) && !_containsYear(event.endDate)) {
        end = DateTime(start.year + 1, end.month, end.day);
      }

      if (!end.isAtSameMomentAs(start)) {
        dated.add(
          TimelineEventEntry(
            event: event,
            date: start,
            rangeStart: start,
            rangeEnd: end,
            boundary: TimelineEventBoundary.starts,
          ),
        );
        dated.add(
          TimelineEventEntry(
            event: event,
            date: end,
            rangeStart: start,
            rangeEnd: end,
            boundary: TimelineEventBoundary.ends,
          ),
        );
      } else {
        dated.add(
          TimelineEventEntry(
            event: event,
            date: start,
            rangeStart: start,
            rangeEnd: end,
            boundary: TimelineEventBoundary.single,
          ),
        );
      }
    }

    return TimelineEventGroups(dated: dated, other: other);
  }

  static DateTime? _parseDate(String value, {int? fallbackYear}) {
    if (value.trim().isEmpty) return null;

    final chinese = DateText.parseChineseDate(value);
    if (chinese != null) return chinese;

    final iso = DateTime.tryParse(value.trim());
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    if (fallbackYear == null) return null;
    final match = _monthDayPattern.firstMatch(value);
    if (match == null) return null;
    final month = int.tryParse(match.group(1)!);
    final day = int.tryParse(match.group(2)!);
    if (month == null || day == null) return null;
    final date = DateTime(fallbackYear, month, day);
    if (date.month != month || date.day != day) return null;
    return date;
  }

  static bool _containsYear(String value) => _yearPattern.hasMatch(value);
}
