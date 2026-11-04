import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/job_fair.dart';

Map<String, dynamic> _row({
  String id = 'event-1',
  String date = '20261105',
  String time = '14:30',
  Object? type = '3',
}) => {
  'id': id,
  'title': '校园宣讲会',
  'place': '旗山校区',
  'start_time': date,
  'time': time,
  'zphval': type,
};

void main() {
  test(
    'source dates are absolute Beijing instants, including month boundaries',
    () {
      final event = JobFair.fromJson(_row(date: '20261101', time: '00:15'));
      expect(event.startsAt, DateTime.utc(2026, 10, 31, 16, 15));
      expect(event.startsAt.isUtc, isTrue);
      expect(event.beijingStart, DateTime.utc(2026, 11, 1, 0, 15));
      expect(JobFairMonth(2026, 11).contains(event.startsAt), isTrue);
      expect(JobFairMonth(2026, 10).contains(event.startsAt), isFalse);
      expect(
        JobFairMonth.fromInstant(DateTime.utc(2026, 10, 31, 16)),
        JobFairMonth(2026, 11),
      );
      expect(JobFairMonth(2026, 11).apiValue, '2026/11');
      expect(JobFairMonth(2026, 12).shift(1), JobFairMonth(2027, 1));
      expect(JobFairMonth(2026, 1).shift(-1), JobFairMonth(2025, 12));
    },
  );

  test('impossible dates and times are not silently normalized', () {
    for (final date in [
      '20260229',
      '20261301',
      '20260001',
      '20261131',
      '00001101',
      '2026-11-05',
      '',
    ]) {
      expect(
        () => JobFair.fromJson(_row(date: date)),
        throwsFormatException,
        reason: date,
      );
    }
    for (final time in ['24:00', '08:60', '14:30:60', 'noon', '']) {
      expect(
        () => JobFair.fromJson(_row(time: time)),
        throwsFormatException,
        reason: time,
      );
    }
    expect(
      JobFair.fromJson(_row(date: '20240229', time: '8:05:30')).startsAt,
      DateTime.utc(2024, 2, 29, 0, 5, 30),
    );
    expect(() => JobFairMonth(2026, 13), throwsFormatException);
    expect(() => JobFairMonth(0, 1), throwsFormatException);
  });

  test('detail URI encodes opaque IDs and chooses the official event type', () {
    const id = '招生 &redirect=https://evil.invalid/#?id=2';
    final talk = JobFair.fromJson(_row(id: id, type: 3));
    expect(talk.type, JobFairType.careerTalk);
    expect(talk.detailUri!.host, JobFair.officialHost);
    expect(talk.detailUri!.path, '/cms/xjhdetail.html');
    expect(talk.detailUri!.queryParameters, {'id': id});
    expect(talk.detailUri!.hasFragment, isFalse);
    expect(JobFair.isOfficialDetailUri(talk.detailUri!), isTrue);

    final fair = JobFair.fromJson(_row(type: '1'));
    expect(fair.type, JobFairType.recruitment);
    expect(fair.detailUri!.path, '/cms/zphdetail.html');
    expect(JobFair.isOfficialDetailUri(fair.detailUri!), isTrue);
    for (final badId in ['', ' ', 'event\r\nHeader: injected']) {
      expect(() => JobFair.fromJson(_row(id: badId)), throwsFormatException);
    }
  });

  test('details validation rejects foreign hosts, paths and ambiguous IDs', () {
    for (final url in [
      'https://fjrclh.fzu.edu.cn.evil.invalid/cms/xjhdetail.html?id=1',
      'https://evil.invalid/cms/xjhdetail.html?id=1',
      'https://fjrclh.fzu.edu.cn/cms/other.html?id=1',
      'https://fjrclh.fzu.edu.cn:444/cms/xjhdetail.html?id=1',
      'https://user@fjrclh.fzu.edu.cn/cms/xjhdetail.html?id=1',
      'https://fjrclh.fzu.edu.cn/cms/xjhdetail.html?id=1#fragment',
      'https://fjrclh.fzu.edu.cn/cms/xjhdetail.html?id=1&id=2',
      'https://fjrclh.fzu.edu.cn/cms/xjhdetail.html?id=1&next=evil',
      'https://fjrclh.fzu.edu.cn/cms/xjhdetail.html?id=',
      'https://fjrclh.fzu.edu.cn/cms/xjhdetail.html?id=%0d%0a',
      'javascript:alert(1)',
      '/cms/xjhdetail.html?id=1',
    ]) {
      expect(JobFair.isOfficialDetailUri(Uri.parse(url)), isFalse, reason: url);
    }
  });

  test('upcoming entries ascend and already-started entries descend', () {
    final result = JobFairMonthData(
      month: JobFairMonth(2026, 11),
      events: [
        JobFair.fromJson(_row(id: 'later', date: '20261107')),
        JobFair.fromJson(_row(id: 'oldest', date: '20261101')),
        JobFair.fromJson(_row(id: 'next', date: '20261106')),
        JobFair.fromJson(_row(id: 'at-start', date: '20261105')),
        JobFair.fromJson(_row(id: 'recent', date: '20261104')),
      ],
    );
    final groups = result.groupsAt(DateTime.utc(2026, 11, 5, 6, 30));
    expect(groups.upcoming.map((event) => event.id), ['next', 'later']);
    expect(groups.past.map((event) => event.id), [
      'at-start',
      'recent',
      'oldest',
    ]);
    expect(() => result.events.clear(), throwsUnsupportedError);
  });

  test(
    'missing text remains missing, and malformed field objects are rejected',
    () {
      final row = _row()
        ..['title'] = null
        ..['place'] = null
        ..['id'] = 123;
      final event = JobFair.fromJson(row);
      expect(event.id, '123');
      expect(event.title, isEmpty);
      expect(event.place, isEmpty);
      row['time'] = {'hour': 8};
      expect(() => JobFair.fromJson(row), throwsFormatException);
    },
  );
}
