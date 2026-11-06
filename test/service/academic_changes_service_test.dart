import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/academic_change.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/model/mark.dart';
import 'package:fzu_assistant/service/academic_changes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Mark grade(String score, {String name = '数学', String term = '202601'}) => Mark(
  type: 'required',
  semester: term,
  name: name,
  credits: '3',
  score: score,
  gpa: '3',
  earnedCredits: '3',
  electiveType: '',
  examType: '期末',
  teacher: '李老师',
  classroom: '',
  examTime: '',
);
ExamRoomInfo exam({
  String time = '14:00-16:00',
  String location = '旗山东3-106',
  String name = '数学',
}) => ExamRoomInfo(
  courseName: name,
  credit: '3',
  teacher: '李老师',
  date: time.isEmpty ? '' : '2026年11月6日',
  time: time,
  location: location,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AcademicChangesService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = AcademicChangesService(now: () => DateTime.utc(2026, 11, 6));
  });
  tearDown(() async {
    await service.clear();
    service.dispose();
  });
  Future<void> grades(List<Mark> marks) =>
      service.observeMarks(service.begin('A'), marks);
  Future<void> exams(List<ExamRoomInfo> exams, {String term = '202601'}) =>
      service.observeExams(service.begin('A'), term, exams);

  test('首次静默，出分、改分各记录一次，顺序和重复记录不触发', () async {
    await grades([grade('成绩尚未录入'), grade('80', name: '英语')]);
    expect(service.value, isEmpty);
    await grades([grade('80', name: '英语'), grade('90'), grade('90')]);
    expect(service.value.single.type, AcademicChangeType.gradeAdded);
    expect(service.value.single.after, '90');
    await grades([grade('90'), grade('80', name: '英语')]);
    expect(service.value, hasLength(1));
    await grades([grade('95'), grade('80', name: '英语')]);
    expect(service.value.first.type, AcademicChangeType.gradeChanged);
    expect(service.value.first.before, '90');
    expect(service.value.first.after, '95');
  });

  test('临时缺行、缺分和冲突行不抹去有效基线，不产生伪出分通知', () async {
    await grades([grade('80')]);
    await grades([]);
    await grades([grade('成绩尚未录入')]);
    await grades([grade('80'), grade('90')]);
    await grades([grade('80')]);
    expect(service.value, isEmpty);
    await grades([grade('85')]);
    expect(service.value.single.before, '80');
  });

  test('考试按学期隔离，识别新增、变更和撤回，异常记录保留旧基线', () async {
    await exams([exam(time: '')]);
    await exams([exam()]);
    expect(service.value.single.type, AcademicChangeType.examAdded);
    await exams([exam(name: '其他学期')], term: '202602');
    expect(service.value, hasLength(1));
    await exams([exam(location: '铜盘')]);
    expect(service.value.first.type, AcademicChangeType.examChanged);
    await exams([
      const ExamRoomInfo(
        courseName: '数学',
        credit: '3',
        teacher: '李老师',
        date: '',
        time: '',
        location: '',
        rawExamTime: '格式异常',
      ),
    ]);
    await exams([exam(location: '铜盘')]);
    expect(service.value, hasLength(2));
    await exams([]);
    expect(service.value.first.type, AcademicChangeType.examRemoved);
    await exams([]);
    expect(service.value, hasLength(3));
  });

  test('后返回的旧请求不能覆盖新结果，退出和换号均拒绝在途结果', () async {
    await grades([grade('80')]);
    final old = service.begin('A'), latest = service.begin('A');
    await service.observeMarks(latest, [grade('90')]);
    await service.observeMarks(old, [grade('85')]);
    expect(service.value.single.after, '90');
    final pending = service.begin('A');
    await service.clear();
    await service.observeMarks(pending, [grade('95')]);
    expect(service.value, isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getString(
        AcademicChangesService.storageKey,
      ),
      isNull,
    );
    await service.observeMarks(service.begin('B'), [grade('60')]);
    await service.observeMarks(pending, [grade('100')]);
    await service.observeMarks(service.begin('B'), [grade('70')]);
    expect(service.value.single.before, '60');
    expect(service.value.single.after, '70');
    final stored = jsonDecode(
      (await SharedPreferences.getInstance()).getString(
        AcademicChangesService.storageKey,
      )!,
    ) as Map;
    expect(stored['account'], 'B');
  });

  test('记录可恢复、已读状态持久化，并保持最近 100 条上限', () async {
    await grades([grade('0')]);
    for (var i = 1; i <= 105; i++) {
      await grades([grade('$i')]);
    }
    expect(service.value, hasLength(100));
    expect(service.value.first.after, '105');
    await service.markRead(id: service.value.first.id);
    expect(service.value.where((e) => e.read), hasLength(1));
    final restored = AcademicChangesService();
    await restored.load('A');
    expect(restored.value.first.read, isTrue);
    await restored.markRead();
    expect(restored.value.every((e) => e.read), isTrue);
    restored.dispose();
  });
}
