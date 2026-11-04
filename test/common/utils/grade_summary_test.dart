import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/grade_summary.dart';
import 'package:fzu_assistant/model/mark.dart';

Mark grade(
  String score, {
  String type = '',
  String credits = '1',
  String gpa = '',
  String electiveType = '',
  String examType = '',
}) => Mark(
  type: type,
  semester: '',
  name: score,
  credits: credits,
  score: score,
  gpa: gpa,
  earnedCredits: '',
  electiveType: electiveType,
  examType: examType,
  teacher: '',
  classroom: '',
  examTime: '',
);

void main() {
  group('GradeSummary', () {
    test(
      'unpublished numeric placeholders are pending rather than GPA zero',
      () {
        for (final score in [
          '',
          '成绩尚未录入',
          '尚未录入',
          '未录入',
          '待录入',
          '成绩只录一遍',
          '录入中',
          '暂无',
          '缓考',
        ]) {
          for (final gpa in ['0', '3.5']) {
            expect(
              GradeSummary.gpaStatus(grade(' $score ', gpa: gpa)),
              CourseGpaStatus.pending,
              reason: '$score / $gpa',
            );
          }
        }
      },
    );

    test('recorded failing and absent grades retain a real zero GPA', () {
      for (final score in ['0', '48', '不及格', '缺考']) {
        expect(
          GradeSummary.gpaStatus(grade(score, gpa: '0')),
          CourseGpaStatus.available,
          reason: score,
        );
      }
    });

    test('recorded grades with missing or malformed GPA stay missing', () {
      for (final gpa in ['', '--', 'NaN', 'Infinity', '-1']) {
        expect(
          GradeSummary.gpaStatus(grade('85', gpa: gpa)),
          CourseGpaStatus.missing,
          reason: gpa,
        );
      }
    });

    test('two-level grades are inapplicable with or without a numeric GPA', () {
      for (final score in ['合格', '不合格']) {
        for (final gpa in ['', '0', '4.5']) {
          expect(
            GradeSummary.gpaStatus(grade(score, gpa: gpa)),
            CourseGpaStatus.notApplicable,
            reason: '$score / $gpa',
          );
        }
      }
    });

    test('excluded categories take precedence over pending or missing GPA', () {
      for (final category in [
        '自然科学与工程技术类',
        '人文社会科学类',
        '经济管理类',
        '文学与艺术类',
        '工程技术类',
        '劳动教育类',
        '创新创业类',
        '通识选修任选',
        '任意选修',
        '任意选修课',
        '二专业必修',
        '第二专业选修',
      ]) {
        expect(
          GradeSummary.gpaStatus(grade('成绩尚未录入', electiveType: category)),
          CourseGpaStatus.notApplicable,
          reason: category,
        );
      }
      expect(
        GradeSummary.gpaStatus(grade('85', type: '二专业')),
        CourseGpaStatus.notApplicable,
      );
    });

    test('zero-credit courses do not require a reported GPA', () {
      for (final score in ['成绩尚未录入', '85']) {
        expect(
          GradeSummary.gpaStatus(grade(score, credits: '0')),
          CourseGpaStatus.notApplicable,
        );
      }
    });

    test('parses only finite non-negative complete numbers', () {
      expect(GradeSummary.nonNegativeNumber(' 3.5 '), 3.5);
      expect(GradeSummary.nonNegativeNumber('0'), 0);
      for (final value in ['', '--', 'NaN', 'Infinity', '-0.1', '3学分']) {
        expect(GradeSummary.nonNegativeNumber(value), isNull, reason: value);
      }
    });

    test('numeric scores must fall within the hundred-point scale', () {
      expect(GradeSummary.numericScore('100'), 100);
      expect(GradeSummary.numericScore('0'), 0);
      expect(GradeSummary.numericScore('100.1'), isNull);
      expect(GradeSummary.numericScore('-1'), isNull);
      expect(GradeSummary.numericScore('85分'), isNull);
    });

    test(
      'five-level abbreviations share their full names ordering and band',
      () {
        for (final pair in [
          ['优秀', '优'],
          ['良好', '良'],
          ['中等', '中'],
        ]) {
          expect(
            GradeSummary.scoreOrder(pair[0]),
            GradeSummary.scoreOrder(pair[1]),
          );
          expect(
            GradeSummary.scoreBand(pair[0]),
            GradeSummary.scoreBand(pair[1]),
          );
        }
      },
    );

    test('sorts numeric and text results ahead of missing scores', () {
      final values = [
        '成绩尚未录入',
        '不合格',
        '中等',
        '65',
        '优秀',
        '良好',
        '98',
        '合格',
      ].map(grade).toList()..sort(GradeSummary.compareMarks);
      expect(values.map((mark) => mark.score).toList(), [
        '98',
        '优秀',
        '良好',
        '中等',
        '65',
        '合格',
        '不合格',
        '成绩尚未录入',
      ]);
    });

    test('every numeric boundary selects its intended grade band', () {
      final boundaries = {
        '100': GradeBand.excellent,
        '90': GradeBand.excellent,
        '89.9': GradeBand.good,
        '80': GradeBand.good,
        '79.9': GradeBand.medium,
        '70': GradeBand.medium,
        '69.9': GradeBand.pass,
        '60': GradeBand.pass,
        '59.9': GradeBand.fail,
        '0': GradeBand.fail,
      };
      for (final entry in boundaries.entries) {
        expect(
          GradeSummary.scoreBand(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('text grades use the same semantic color bands as numeric grades', () {
      final bands = {
        '优秀': GradeBand.excellent,
        '良好': GradeBand.good,
        '中等': GradeBand.medium,
        '及格': GradeBand.pass,
        '合格': GradeBand.pass,
        '不及格': GradeBand.fail,
        '不合格': GradeBand.fail,
        '缺考': GradeBand.unknown,
        '成绩尚未录入': GradeBand.unknown,
        'NaN': GradeBand.unknown,
        'Infinity': GradeBand.unknown,
      };
      for (final entry in bands.entries) {
        expect(
          GradeSummary.scoreBand(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('comparing missing scores is symmetric and never throws', () {
      expect(GradeSummary.compareMarks(grade('NaN'), grade('')), 0);
      expect(
        GradeSummary.compareMarks(grade('NaN'), grade('0')),
        greaterThan(0),
      );
      expect(GradeSummary.compareMarks(grade('0'), grade('NaN')), lessThan(0));
    });

    test('effective result is immutable and input records stay untouched', () {
      final original = grade('85');
      final records = [original, original];
      final effective = GradeSummary.effectiveMarks(records);
      expect(effective, [original]);
      expect(records, [original, original]);
      expect(() => effective.add(original), throwsUnsupportedError);
    });
  });
}
