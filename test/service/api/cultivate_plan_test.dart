import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

void main() {
  test('fallback matches exact major and only accepts official plan links', () {
    final doc = parse(
      '''<table><tr><td>（工学）计算机科学与技术</td>
      <td><a href="javascript:pop1('pyfa_bzy.aspx?nj=2023&amp;zyh=10')">查看</a></td></tr>
      <tr><td>计算机</td><td><a href="pyfa_wrong.aspx">查看</a></td></tr></table>''',
    );
    expect(
      AcademicService.parseCultivatePlanLink(doc, '计算机科学与技术'),
      'https://jwcjwxt2.fzu.edu.cn:81/pyfa/pyjh/pyfa_bzy.aspx?nj=2023&zyh=10',
    );
    expect(
      () => AcademicService.parseCultivatePlanLink(doc, '软件工程'),
      throwsException,
    );
    expect(
      () => AcademicService.parseCultivatePlanLink(
        parse('<tr><td>软件工程</td></tr>'),
        '',
      ),
      throwsException,
    );
    final malicious = parse(
      '<table><tr><td>软件工程</td><td><a href="https://example.com/pyfa/x">x</a></td></tr></table>',
    );
    expect(
      () => AcademicService.parseCultivatePlanLink(malicious, '软件工程'),
      throwsException,
    );
  });
}
