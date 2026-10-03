import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/evaluation_required_exception.dart';

void main() {
  group('EvaluationRequiredDetector.isRequired', () {
    test('覆盖 jwch 实测文案', () {
      expect(
        EvaluationRequiredDetector.isRequired('<p>请先对任课教师进行测评</p>'),
        isTrue,
      );
    });

    test('覆盖带"和教材"的文案', () {
      expect(EvaluationRequiredDetector.isRequired('请先对任课教师和教材进行测评'), isTrue);
    });

    test('不误判普通页面', () {
      expect(
        EvaluationRequiredDetector.isRequired('<html>GPA</html>'),
        isFalse,
      );
      expect(EvaluationRequiredDetector.isRequired('请先完成教师评议'), isFalse);
    });
  });
}
