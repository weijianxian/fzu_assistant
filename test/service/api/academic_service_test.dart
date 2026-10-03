import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  group('AcademicService.extractAlertMessage', () {
    test('识别教务处用 window.alert 代替页面内容的提示', () {
      final doc = html_parser.parse('''
        <html><head><script type="text/javascript">
          window.alert( '你尚有学费未缴清，暂时不能查询成绩，如有疑问请与计财处联系！');
        </script></head><body><div>请稍候</div></body></html>
      ''');

      expect(
        AcademicService.extractAlertMessage(doc),
        '你尚有学费未缴清，暂时不能查询成绩，如有疑问请与计财处联系！',
      );
    });

    test('双引号写法同样识别', () {
      final doc = html_parser.parse(
        '<html><body><script>window.alert("选课时间未到");</script></body></html>',
      );

      expect(AcademicService.extractAlertMessage(doc), '选课时间未到');
    });

    test('空提示不算命中', () {
      final doc = html_parser.parse(
        "<html><body><script>window.alert('');</script></body></html>",
      );

      expect(AcademicService.extractAlertMessage(doc), isNull);
    });

    test('正常成绩页面不误报', () {
      final doc = html_parser.parse(
        '<html><body><table id="ContentPlaceHolder1_DataList_xxk">'
        '<tbody><tr style="background:#efefef"><td>课程名称</td></tr></tbody>'
        '</table></body></html>',
      );

      expect(AcademicService.extractAlertMessage(doc), isNull);
    });
  });
}
