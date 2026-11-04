import 'package:fzu_assistant/model/mark.dart';

/// Presentation bands also cover the five-level and pass/fail grading systems.
enum GradeBand { excellent, good, medium, pass, fail, unknown }

/// An unpublished numeric placeholder is not a confirmed course GPA.
enum CourseGpaStatus { notApplicable, pending, missing, available }

/// Pure grade interpretation. Ordering values are never used to invent a GPA.
abstract final class GradeSummary {
  static const _excludedElectiveTypes = {
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
  };

  static const _pendingScores = {
    '',
    '成绩尚未录入',
    '尚未录入',
    '未录入',
    '待录入',
    '成绩只录一遍',
    '录入中',
    '暂无',
    '缓考',
  };

  /// Rejects missing, malformed, negative and non-finite numeric values.
  static double? nonNegativeNumber(String value) {
    final number = double.tryParse(value.trim());
    return number != null && number.isFinite && number >= 0 ? number : null;
  }

  static double? numericScore(String score) {
    final number = nonNegativeNumber(score);
    return number != null && number <= 100 ? number : null;
  }

  /// Representative scores provide a consistent display order for text grades.
  /// Keep the original text on screen; these values do not enter GPA arithmetic.
  static double? scoreOrder(String score) {
    final numeric = numericScore(score);
    if (numeric != null) return numeric;
    return switch (score.trim()) {
      '优秀' || '优' => 95,
      '良好' || '良' => 85,
      '中等' || '中' => 75,
      '及格' => 65,
      '合格' => 60,
      '不及格' || '不合格' => 0,
      _ => null,
    };
  }

  static GradeBand scoreBand(String score) {
    return switch (score.trim()) {
      '优秀' || '优' => GradeBand.excellent,
      '良好' || '良' => GradeBand.good,
      '中等' || '中' => GradeBand.medium,
      '及格' || '合格' => GradeBand.pass,
      '不及格' || '不合格' => GradeBand.fail,
      _ => _numericBand(numericScore(score)),
    };
  }

  static GradeBand _numericBand(double? score) {
    if (score == null) return GradeBand.unknown;
    if (score >= 90) return GradeBand.excellent;
    if (score >= 80) return GradeBand.good;
    if (score >= 70) return GradeBand.medium;
    if (score >= 60) return GradeBand.pass;
    return GradeBand.fail;
  }

  static int compareMarks(Mark first, Mark second) {
    final a = scoreOrder(first.score);
    final b = scoreOrder(second.score);
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  static bool isSecondMajor(Mark mark) {
    final category = '${mark.type} ${mark.electiveType}';
    return category.contains('二专业') || category.contains('第二专业');
  }

  static bool contributesToGpa(Mark mark) {
    return !_excludedElectiveTypes.contains(mark.electiveType.trim()) &&
        !isSecondMajor(mark) &&
        !{'合格', '不合格'}.contains(mark.score.trim());
  }

  static bool isPendingScore(String score) =>
      _pendingScores.contains(score.trim());

  /// Shared by the summary and course details so inapplicable and unavailable
  /// GPAs cannot be confused. Category exclusions and zero credits take
  /// precedence over a missing result.
  static CourseGpaStatus gpaStatus(Mark mark) {
    if (!contributesToGpa(mark) || nonNegativeNumber(mark.credits) == 0) {
      return CourseGpaStatus.notApplicable;
    }
    if (isPendingScore(mark.score)) return CourseGpaStatus.pending;
    return nonNegativeNumber(mark.gpa) == null
        ? CourseGpaStatus.missing
        : CourseGpaStatus.available;
  }

  static bool _isMakeUp(Mark mark) => mark.examType.contains('补考');

  static bool _hasResult(Mark mark) {
    if (scoreOrder(mark.score) != null) return true;
    if (isPendingScore(mark.score)) return false;
    return nonNegativeNumber(mark.gpa) != null;
  }

  /// Resolve attempts for summaries without altering the original grade list.
  ///
  /// The academic response has no course ID. Match semester, name and teacher,
  /// keeping second-major records separate. A published make-up result takes
  /// precedence; pending make-ups cannot displace an existing original result.
  /// Within duplicate attempts, prefer a published result and then the better
  /// grade. Repeated rows therefore never increase credits.
  static List<Mark> effectiveMarks(Iterable<Mark> marks) {
    final courses = <(String, String, String, bool), List<Mark>>{};
    for (final mark in marks) {
      final key = (
        mark.semester.trim(),
        mark.name.trim(),
        mark.teacher.trim(),
        isSecondMajor(mark),
      );
      courses.putIfAbsent(key, () => []).add(mark);
    }

    final result = <Mark>[];
    for (final attempts in courses.values) {
      final publishedMakeUps = attempts
          .where((mark) => _isMakeUp(mark) && _hasResult(mark))
          .toList();
      final originals = attempts.where((mark) => !_isMakeUp(mark)).toList();
      final candidates = publishedMakeUps.isNotEmpty
          ? publishedMakeUps
          : originals.isNotEmpty
          ? originals
          : attempts;
      var selected = candidates.first;
      for (final candidate in candidates.skip(1)) {
        final candidateHasResult = _hasResult(candidate);
        final selectedHasResult = _hasResult(selected);
        if (candidateHasResult != selectedHasResult) {
          if (candidateHasResult) selected = candidate;
          continue;
        }
        final order = compareMarks(candidate, selected);
        if (order < 0 ||
            (order == 0 &&
                (nonNegativeNumber(candidate.gpa) ?? -1) >
                    (nonNegativeNumber(selected.gpa) ?? -1))) {
          selected = candidate;
        }
      }
      result.add(selected);
    }
    return List.unmodifiable(result);
  }
}
