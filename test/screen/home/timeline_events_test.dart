import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/screen/home/timeline_events.dart';

void main() {
  test('keeps single-day events as one dated entry', () {
    const event = CalTermEvent(
      name: 'Registration',
      startDate: '2024年9月1日',
      endDate: '2024年9月1日',
    );

    final groups = TimelineEvents.split([event]);

    expect(groups.other, isEmpty);
    expect(groups.dated, hasLength(1));
    expect(groups.dated.single.event, same(event));
    expect(groups.dated.single.date, DateTime(2024, 9, 1));
    expect(groups.dated.single.boundary, TimelineEventBoundary.single);
  });

  test('splits a date range into start and end boundaries', () {
    const event = CalTermEvent(
      name: 'Holiday',
      startDate: '2024-10-01',
      endDate: '2024-10-07',
    );

    final entries = TimelineEvents.split([event]).dated;

    expect(entries, hasLength(2));
    expect(entries[0].date, DateTime(2024, 10, 1));
    expect(entries[0].boundary, TimelineEventBoundary.starts);
    expect(entries[1].date, DateTime(2024, 10, 7));
    expect(entries[1].boundary, TimelineEventBoundary.ends);
    expect(entries[0].rangeEnd, entries[1].date);
    expect(entries[1].rangeStart, entries[0].date);
  });

  test('rolls a yearless end date into the following year', () {
    const event = CalTermEvent(
      name: 'Winter break',
      startDate: '2024年12月30日',
      endDate: '1月2日',
    );

    final entries = TimelineEvents.split([event]).dated;

    expect(entries[0].date, DateTime(2024, 12, 30));
    expect(entries[1].date, DateTime(2025, 1, 2));
  });

  test('keeps events without a valid start date in the other group', () {
    const event = CalTermEvent(
      name: 'To be announced',
      startDate: '待定',
      endDate: '',
    );

    final groups = TimelineEvents.split([event]);

    expect(groups.dated, isEmpty);
    expect(groups.other, [same(event)]);
  });

  test('falls back to a single-day event when the end date is invalid', () {
    const event = CalTermEvent(
      name: 'Exam',
      startDate: '2025年1月8日',
      endDate: '待定',
    );

    final entry = TimelineEvents.split([event]).dated.single;

    expect(entry.date, DateTime(2025, 1, 8));
    expect(entry.rangeEnd, entry.date);
    expect(entry.boundary, TimelineEventBoundary.single);
  });
}
