class SemesterUtils {
  SemesterUtils._();

  static String formatSemester(String term) {
    if (term.length < 6) return term;

    final year = int.tryParse(term.substring(0, 4));
    final semester = int.tryParse(term.substring(4, 6));
    if (year == null || semester == null) return term;

    return '$year-${year + 1} 学年 第$semester学期';
  }
}
