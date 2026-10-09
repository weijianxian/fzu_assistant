import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/service/api/html_helper.dart';

void main() {
  test('学期表单解析保留顺序，过滤空项并解码提交令牌', () {
    final info = HtmlHelper.parseTermInfo(
      html.parse('''
      <input id="__VIEWSTATE" value="a&amp;b">
      <input id="__EVENTVALIDATION" value="token">
      <select id="ContentPlaceHolder1_DDL_xnxq">
        <option value="">请选择</option>
        <option value="202601">本学期</option>
        <option value="202501">上学期</option>
      </select>
    '''),
    );
    expect(info.terms, ['202601', '202501']);
    expect(info.viewState, 'a&b');
    expect(info.eventValidation, 'token');
    expect(
      () => HtmlHelper.parseTermInfo(html.parse('<html></html>')),
      throwsException,
    );
  });

  test('移除未使用的课程标记后仍兼容旧缓存', () {
    final rule = CourseScheduleRule.fromJson({
      'location': 'A101',
      'startClass': 1,
      'endClass': 8,
      'startWeek': 1,
      'endWeek': 2,
      'weekday': 1,
      'single': true,
      'double': true,
      'adjust': true,
      'fromFullWeek': true,
    });
    expect(rule.startClass, 1);
    expect(rule.endClass, 8);
    expect(rule.startWeek, 1);
    expect(rule.endWeek, 2);
    expect(rule.toJson().containsKey('adjust'), isFalse);
    expect(rule.toJson().containsKey('fromFullWeek'), isFalse);
  });
}
