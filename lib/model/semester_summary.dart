import 'package:fzu_assistant/common/utils/grade_summary.dart';
import 'package:fzu_assistant/model/mark.dart';

/// A local estimate derived from the effective course attempts in one semester.
/// Missing GPA/credits remain missing, rather than counting as a failing grade.
class SemesterSummary {
  final int courseCount;

  /// Planned course credits, including failed and GPA-excluded courses.
  /// When [missingCreditsCount] is positive this is only the known subtotal.
  final double totalCredits;

  /// The original numeric or text grade, never a fabricated numeric equivalent.
  final String? highestScore;
  final double? estimatedGpa;
  final int gpaCourseCount;

  /// Eligible courses whose GPA is missing or whose result is still pending.
  final int missingGpaCount;
  final int missingCreditsCount;

  /// Effective attempts used in every summary metric, in their original order.
  final List<Mark> courses;

  final bool isGpaIncomplete;

  const SemesterSummary._({
    required this.courseCount,
    required this.totalCredits,
    required this.highestScore,
    required this.estimatedGpa,
    required this.gpaCourseCount,
    required this.missingGpaCount,
    required this.missingCreditsCount,
    required this.courses,
    required this.isGpaIncomplete,
  });

  factory SemesterSummary.fromMarks(Iterable<Mark> marks) {
    final courses = GradeSummary.effectiveMarks(marks);
    var totalCredits = 0.0;
    Mark? highest;
    var gpaCredits = 0.0;
    var weightedGpa = 0.0;
    var gpaCourseCount = 0;
    var missingGpaCount = 0;
    var missingCreditsCount = 0;
    var isGpaIncomplete = false;

    for (final course in courses) {
      final credit = GradeSummary.nonNegativeNumber(course.credits);
      if (credit == null || !(totalCredits + credit).isFinite) {
        missingCreditsCount++;
      } else {
        totalCredits += credit;
      }
      if (GradeSummary.scoreOrder(course.score) != null &&
          (highest == null || GradeSummary.compareMarks(course, highest) < 0)) {
        highest = course;
      }

      final gpaStatus = GradeSummary.gpaStatus(course);
      if (gpaStatus == CourseGpaStatus.notApplicable) continue;
      gpaCourseCount++;
      final gpa = gpaStatus == CourseGpaStatus.available
          ? GradeSummary.nonNegativeNumber(course.gpa)
          : null;
      if (gpa == null) missingGpaCount++;
      if (credit == null || gpa == null) {
        isGpaIncomplete = true;
        continue;
      }
      final product = credit * gpa;
      if (!product.isFinite ||
          !(weightedGpa + product).isFinite ||
          !(gpaCredits + credit).isFinite) {
        isGpaIncomplete = true;
        continue;
      }
      weightedGpa += product;
      gpaCredits += credit;
    }

    return SemesterSummary._(
      courseCount: courses.length,
      totalCredits: totalCredits,
      highestScore: highest?.score.trim(),
      estimatedGpa: !isGpaIncomplete && gpaCredits > 0
          ? weightedGpa / gpaCredits
          : null,
      gpaCourseCount: gpaCourseCount,
      missingGpaCount: missingGpaCount,
      missingCreditsCount: missingCreditsCount,
      courses: courses,
      isGpaIncomplete: isGpaIncomplete,
    );
  }
}
