import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/date_text.dart';

void main() {
  group('DateText.parseChineseDate', () {
    test('parses Chinese date text', () {
      expect(DateText.parseChineseDate('2024年11月17日'), DateTime(2024, 11, 17));
      expect(DateText.parseChineseDate('考试：2024年1月7日'), DateTime(2024, 1, 7));
    });

    test('returns null for missing or invalid dates', () {
      expect(DateText.parseChineseDate('2024-11-17'), isNull);
      expect(DateText.parseChineseDate('2024年13月40日'), isNull);
    });
  });

  group('DateText.parseChineseDateOrEpoch', () {
    test('falls back to epoch date', () {
      expect(DateText.parseChineseDateOrEpoch(''), DateTime(1970));
    });
  });
}
