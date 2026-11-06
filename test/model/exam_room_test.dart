import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/exam_room.dart';

Course course(String raw, {String name = '数学'}) => Course(
  type: '',
  name: name,
  credits: '3',
  electiveType: '',
  examType: '',
  teacher: '李老师',
  scheduleRules: const [],
  adjustRules: const [],
  rawExamTime: raw,
  remark: '',
);

void main() {
  test('从选课原文解析无空格、多字地点及全角时间并按北京时间解释', () {
    final exam = ExamRoomInfo.fromCourse(
      course('2026年11月6日14：00 - 16：00旗山 数计3-404'),
    );
    expect(exam.date, '2026年11月6日');
    expect(exam.time, '14:00-16:00');
    expect(exam.location, '旗山 数计3-404');
    expect(exam.startTime, DateTime.utc(2026, 11, 6, 6));
    expect(exam.endTime, DateTime.utc(2026, 11, 6, 8));
    expect(exam.hasFinished(DateTime.utc(2026, 11, 6)), isFalse);
    expect(exam.hasFinished(DateTime.utc(2026, 11, 6, 7, 59)), isFalse);
    expect(exam.hasFinished(DateTime.utc(2026, 11, 6, 8)), isTrue);
    expect(ExamRoomInfo.fromJson(exam.toJson()).rawExamTime, exam.rawExamTime);
  });

  test('保留待安排或非法日期时间原文，不能误报已考完', () {
    for (final raw in [
      '',
      '考试待安排',
      '2026年2月30日14:00-16:00旗山',
      '2026年11月6日25:00-26:00旗山',
      '2026年11月6日14:60-16:00旗山',
      '2026年11月6日16:00-14:00旗山',
    ]) {
      final exam = ExamRoomInfo.fromCourse(course(raw));
      expect(exam.rawExamTime, raw);
      expect(exam.startTime, isNull);
      expect(exam.hasFinished(DateTime.utc(2030)), isFalse);
    }
  });

  test('待考最近优先、已考倒序、未安排最后，不修改原列表', () {
    final pending = ExamRoomInfo.fromCourse(course('', name: '待安排'));
    final yesterday = ExamRoomInfo.fromCourse(
      course('2026年11月5日14:00-16:00旗山', name: '昨日'),
    );
    final today = ExamRoomInfo.fromCourse(
      course('2026年11月6日14:00-16:00旗山', name: '今日'),
    );
    final tomorrow = ExamRoomInfo.fromCourse(
      course('2026年11月7日14:00-16:00旗山', name: '明日'),
    );
    final input = [pending, yesterday, tomorrow, today];
    expect(
      ExamRoomInfo.sorted(
        input,
        DateTime.utc(2026, 11, 6, 7),
      ).map((e) => e.courseName),
      ['今日', '明日', '昨日', '待安排'],
    );
    expect(input.first, same(pending));
    expect(
      ExamRoomInfo.sorted(
        input,
        DateTime.utc(2026, 11, 6, 9),
      ).map((e) => e.courseName),
      ['明日', '今日', '昨日', '待安排'],
    );
  });
}
