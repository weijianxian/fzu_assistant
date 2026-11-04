import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/mark.dart';
import 'package:fzu_assistant/model/semester_summary.dart';

Mark mark({
  String name = '高等数学',
  String teacher = '张老师',
  String semester = '202601',
  String type = '初修',
  String credits = '3',
  String score = '85',
  String gpa = '3.5',
  String earnedCredits = '3',
  String electiveType = '必修',
  String examType = '正常考试',
}) => Mark(
  type: type,
  semester: semester,
  name: name,
  credits: credits,
  score: score,
  gpa: gpa,
  earnedCredits: earnedCredits,
  electiveType: electiveType,
  examType: examType,
  teacher: teacher,
  classroom: '',
  examTime: '',
);

void main() {
  group('SemesterSummary', () {
    test(
      'pending GPA placeholders never lower or complete a mixed estimate',
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
            final summary = SemesterSummary.fromMarks([
              mark(score: '90', gpa: '4'),
              mark(name: '大学物理', score: score, gpa: gpa),
            ]);
            expect(summary.totalCredits, 6);
            expect(summary.highestScore, '90');
            expect(summary.estimatedGpa, isNull, reason: '$score / $gpa');
            expect(summary.isGpaIncomplete, isTrue, reason: '$score / $gpa');
            expect(summary.missingGpaCount, 1);
            expect(summary.gpaCourseCount, 2);
          }
        }
      },
    );

    test('all pending zero-GPA rows remain incomplete rather than failing', () {
      final summary = SemesterSummary.fromMarks([
        mark(score: '成绩尚未录入', gpa: '0'),
        mark(name: '大学物理', score: '成绩只录一遍', gpa: '0'),
      ]);
      expect(summary.courseCount, 2);
      expect(summary.totalCredits, 6);
      expect(summary.highestScore, isNull);
      expect(summary.estimatedGpa, isNull);
      expect(summary.isGpaIncomplete, isTrue);
      expect(summary.missingGpaCount, 2);
    });

    test('recorded zero results still produce a complete zero GPA', () {
      final summary = SemesterSummary.fromMarks([
        mark(score: '0', gpa: '0'),
        mark(name: '大学物理', score: '缺考', gpa: '0'),
      ]);
      expect(summary.estimatedGpa, 0);
      expect(summary.isGpaIncomplete, isFalse);
      expect(summary.missingGpaCount, 0);
    });

    test(
      'pending excluded courses do not invalidate eligible published GPA',
      () {
        final summary = SemesterSummary.fromMarks([
          mark(score: '90', gpa: '4'),
          mark(name: '通识课程', score: '成绩尚未录入', gpa: '0', electiveType: '通识选修任选'),
        ]);
        expect(summary.totalCredits, 6);
        expect(summary.estimatedGpa, 4);
        expect(summary.gpaCourseCount, 1);
        expect(summary.missingGpaCount, 0);
        expect(summary.isGpaIncomplete, isFalse);
      },
    );

    test(
      'all-pass all-fail and mixed two-level semesters have no missing GPA',
      () {
        for (final scores in [
          ['合格', '合格'],
          ['不合格', '不合格'],
          ['合格', '不合格'],
        ]) {
          final summary = SemesterSummary.fromMarks([
            mark(score: scores[0], gpa: ''),
            mark(name: '体育实践', score: scores[1], gpa: '0'),
          ]);
          expect(summary.courseCount, 2);
          expect(summary.totalCredits, 6);
          expect(summary.estimatedGpa, isNull);
          expect(summary.gpaCourseCount, 0);
          expect(summary.missingGpaCount, 0);
          expect(summary.isGpaIncomplete, isFalse);
          expect(summary.highestScore, scores.contains('合格') ? '合格' : '不合格');
        }
      },
    );

    test(
      'partially entered make-up with GPA zero cannot replace an original',
      () {
        final original = mark(score: '85', gpa: '3.5');
        final summary = SemesterSummary.fromMarks([
          original,
          mark(score: '成绩只录一遍', gpa: '0', examType: '补考'),
        ]);
        expect(summary.courses.single, same(original));
        expect(summary.estimatedGpa, 3.5);
        expect(summary.highestScore, '85');
        expect(summary.isGpaIncomplete, isFalse);
      },
    );

    test('empty input has no fabricated maximum or GPA', () {
      final summary = SemesterSummary.fromMarks([]);
      expect(summary.courseCount, 0);
      expect(summary.totalCredits, 0);
      expect(summary.highestScore, isNull);
      expect(summary.estimatedGpa, isNull);
      expect(summary.isGpaIncomplete, isFalse);
    });

    test('uses credit-weighted reported GPA and planned credits', () {
      final summary = SemesterSummary.fromMarks([
        mark(credits: '3', gpa: '4', score: '95'),
        mark(
          name: '大学物理',
          credits: '1',
          score: '50',
          gpa: '0',
          earnedCredits: '0',
        ),
      ]);
      expect(summary.courseCount, 2);
      expect(summary.totalCredits, 4);
      expect(summary.highestScore, '95');
      expect(summary.estimatedGpa, 3);
      expect(summary.gpaCourseCount, 2);
      expect(summary.isGpaIncomplete, isFalse);
    });

    test('fractional credits keep their precision', () {
      final summary = SemesterSummary.fromMarks([
        mark(credits: '1.5', gpa: '4.3'),
        mark(name: '实验', credits: '0.5', gpa: '2.1'),
      ]);
      expect(summary.totalCredits, 2);
      expect(summary.estimatedGpa, closeTo(3.75, 0.000001));
    });

    test('a recorded make-up replaces a failing original only once', () {
      final original = mark(score: '40', gpa: '0', earnedCredits: '0');
      final makeUp = mark(score: '70', gpa: '2', examType: '补考');
      final summary = SemesterSummary.fromMarks([
        original,
        makeUp,
        makeUp,
        original,
      ]);
      expect(summary.courseCount, 1);
      expect(summary.totalCredits, 3);
      expect(summary.highestScore, '70');
      expect(summary.estimatedGpa, 2);
      expect(summary.courses.single, same(makeUp));
    });

    test(
      'make-up precedence does not depend on input order or higher score',
      () {
        final original = mark(score: '85', gpa: '3.5');
        final makeUp = mark(score: '60', gpa: '1', examType: '补考');
        for (final records in [
          [original, makeUp],
          [makeUp, original],
        ]) {
          final summary = SemesterSummary.fromMarks(records);
          expect(summary.estimatedGpa, 1);
          expect(summary.highestScore, '60');
        }
      },
    );

    test('pending make-up cannot displace a published original', () {
      final original = mark(score: '45', gpa: '0');
      for (final pendingScore in ['', '成绩尚未录入', '缓考']) {
        final summary = SemesterSummary.fromMarks([
          mark(score: pendingScore, gpa: '', examType: '补考'),
          original,
        ]);
        expect(summary.courses.single, same(original));
        expect(summary.estimatedGpa, 0);
        expect(summary.totalCredits, 3);
      }
    });

    test(
      'pending score stays pending even when the row has a GPA placeholder',
      () {
        final summary = SemesterSummary.fromMarks([
          mark(score: '45', gpa: '0'),
          mark(score: '成绩尚未录入', gpa: '0', examType: '补考'),
        ]);
        expect(summary.highestScore, '45');
        expect(summary.estimatedGpa, 0);
      },
    );

    test('published zero-GPA make-up is a real result', () {
      final summary = SemesterSummary.fromMarks([
        mark(score: '40', gpa: ''),
        mark(score: '50', gpa: '0', examType: '补考'),
      ]);
      expect(summary.highestScore, '50');
      expect(summary.estimatedGpa, 0);
      expect(summary.missingGpaCount, 0);
    });

    test(
      'published make-up score with missing GPA cannot reuse original GPA',
      () {
        final summary = SemesterSummary.fromMarks([
          mark(score: '40', gpa: '0'),
          mark(score: '70', gpa: '', examType: '补考'),
        ]);
        expect(summary.highestScore, '70');
        expect(summary.totalCredits, 3);
        expect(summary.estimatedGpa, isNull);
        expect(summary.isGpaIncomplete, isTrue);
        expect(summary.missingGpaCount, 1);
      },
    );

    test('multiple published make-ups resolve to one effective course', () {
      final summary = SemesterSummary.fromMarks([
        mark(score: '40', gpa: '0'),
        mark(score: '60', gpa: '1', examType: '补考'),
        mark(score: '75', gpa: '2.5', examType: '补考'),
        mark(score: '成绩尚未录入', gpa: '', examType: '补考'),
      ]);
      expect(summary.courseCount, 1);
      expect(summary.totalCredits, 3);
      expect(summary.highestScore, '75');
      expect(summary.estimatedGpa, 2.5);
    });

    test(
      'all pending records for the same course still count credits once',
      () {
        final summary = SemesterSummary.fromMarks([
          mark(score: '', gpa: '', examType: '补考'),
          mark(score: '成绩尚未录入', gpa: '', examType: '补考'),
        ]);
        expect(summary.courseCount, 1);
        expect(summary.totalCredits, 3);
        expect(summary.highestScore, isNull);
        expect(summary.isGpaIncomplete, isTrue);
      },
    );

    test('ordinary duplicate rows do not duplicate credits', () {
      final course = mark();
      final records = [course, course, course];
      final summary = SemesterSummary.fromMarks(records);
      expect(summary.courseCount, 1);
      expect(summary.totalCredits, 3);
      expect(summary.estimatedGpa, 3.5);
      expect(records.length, 3);
    });

    test('same name with different teachers or semesters remains distinct', () {
      final summary = SemesterSummary.fromMarks([
        mark(),
        mark(teacher: '李老师'),
        mark(semester: '202602'),
      ]);
      expect(summary.courseCount, 3);
      expect(summary.totalCredits, 9);
    });

    test('second-major course does not replace the main-major course', () {
      final summary = SemesterSummary.fromMarks([
        mark(),
        mark(electiveType: '二专业必修', score: '98', gpa: '5'),
      ]);
      expect(summary.courseCount, 2);
      expect(summary.totalCredits, 6);
      expect(summary.estimatedGpa, 3.5);
      expect(summary.gpaCourseCount, 1);
    });

    test('all excluded categories contribute credits but no GPA', () {
      const categories = [
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
      ];
      final summary = SemesterSummary.fromMarks([
        mark(),
        for (final category in categories)
          mark(name: category, electiveType: category, gpa: ''),
      ]);
      expect(summary.courseCount, categories.length + 1);
      expect(summary.totalCredits, 3 * (categories.length + 1));
      expect(summary.estimatedGpa, 3.5);
      expect(summary.gpaCourseCount, 1);
      expect(summary.isGpaIncomplete, isFalse);
    });

    test('second-major study type also excludes the course from GPA', () {
      final summary = SemesterSummary.fromMarks([mark(type: '二专业', gpa: '')]);
      expect(summary.totalCredits, 3);
      expect(summary.gpaCourseCount, 0);
      expect(summary.estimatedGpa, isNull);
      expect(summary.isGpaIncomplete, isFalse);
    });

    test('two-level grades are excluded even when a GPA is supplied', () {
      final summary = SemesterSummary.fromMarks([
        mark(),
        mark(name: '实践', score: '合格', gpa: '5'),
        mark(name: '体育', score: '不合格', gpa: '0'),
      ]);
      expect(summary.totalCredits, 9);
      expect(summary.gpaCourseCount, 1);
      expect(summary.estimatedGpa, 3.5);
    });

    test('a semester with only excluded courses has no applicable GPA', () {
      final summary = SemesterSummary.fromMarks([mark(score: '合格', gpa: '')]);
      expect(summary.estimatedGpa, isNull);
      expect(summary.isGpaIncomplete, isFalse);
      expect(summary.highestScore, '合格');
    });

    test(
      'missing GPA makes the estimate missing rather than zero or partial',
      () {
        for (final missing in ['', ' ', '--', 'NaN', 'Infinity', '-1']) {
          final summary = SemesterSummary.fromMarks([
            mark(gpa: '4'),
            mark(name: '大学物理', gpa: missing),
          ]);
          expect(summary.estimatedGpa, isNull, reason: missing);
          expect(summary.missingGpaCount, 1, reason: missing);
          expect(summary.isGpaIncomplete, isTrue, reason: missing);
          expect(summary.totalCredits, 6);
        }
      },
    );

    test('invalid credits never poison totals or create a partial GPA', () {
      for (final missing in ['', '--', 'NaN', 'Infinity', '-2', '3学分']) {
        final summary = SemesterSummary.fromMarks([
          mark(),
          mark(name: '大学物理', credits: missing),
        ]);
        expect(summary.totalCredits, 3, reason: missing);
        expect(summary.missingCreditsCount, 1, reason: missing);
        expect(summary.estimatedGpa, isNull, reason: missing);
        expect(summary.isGpaIncomplete, isTrue, reason: missing);
      }
    });

    test(
      'zero-credit courses cannot cause division by zero or missing GPA',
      () {
        final summary = SemesterSummary.fromMarks([
          mark(credits: '0', gpa: ''),
        ]);
        expect(summary.totalCredits, 0);
        expect(summary.estimatedGpa, isNull);
        expect(summary.gpaCourseCount, 0);
        expect(summary.isGpaIncomplete, isFalse);
      },
    );

    test(
      'unknown credit in an excluded course does not invalidate known GPA',
      () {
        final summary = SemesterSummary.fromMarks([
          mark(),
          mark(name: '实践', credits: '', score: '合格', gpa: ''),
        ]);
        expect(summary.totalCredits, 3);
        expect(summary.missingCreditsCount, 1);
        expect(summary.estimatedGpa, 3.5);
        expect(summary.isGpaIncomplete, isFalse);
      },
    );

    test(
      'text maximum preserves text and never fabricates a numeric score',
      () {
        final summary = SemesterSummary.fromMarks([
          mark(score: '良好', gpa: '3.5'),
          mark(name: '实验', score: '优秀', gpa: '4.5'),
        ]);
        expect(summary.highestScore, '优秀');
        expect(summary.estimatedGpa, 4);
      },
    );

    test('unrecorded and non-finite scores never become highest zero', () {
      final summary = SemesterSummary.fromMarks([
        mark(score: 'NaN', gpa: ''),
        mark(name: '实验', score: '成绩尚未录入', gpa: ''),
        mark(name: '实践', score: 'Infinity', gpa: ''),
      ]);
      expect(summary.highestScore, isNull);
      expect(summary.totalCredits, 9);
      expect(summary.estimatedGpa, isNull);
    });

    test('large finite values cannot produce NaN or an infinite GPA', () {
      final summary = SemesterSummary.fromMarks([
        mark(credits: '1e308', gpa: '1e308'),
      ]);
      expect(summary.totalCredits.isFinite, isTrue);
      expect(summary.estimatedGpa, isNull);
      expect(summary.isGpaIncomplete, isTrue);
    });
  });
}
