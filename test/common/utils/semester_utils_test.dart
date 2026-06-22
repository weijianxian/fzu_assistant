import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/semester_utils.dart';

void main() {
  group('SemesterUtils.formatSemester', () {
    test('formats six digit semester keys', () {
      expect(SemesterUtils.formatSemester('202401'), '2024-2025 学年 第1学期');
      expect(SemesterUtils.formatSemester('202402'), '2024-2025 学年 第2学期');
    });

    test('keeps short or malformed values unchanged', () {
      expect(SemesterUtils.formatSemester(''), '');
      expect(SemesterUtils.formatSemester('2024'), '2024');
      expect(SemesterUtils.formatSemester('abcdef'), 'abcdef');
    });
  });
}
