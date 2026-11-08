import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:fzu_assistant/service/api/classroom_usage_service.dart';

String usageFixture({int day = 1, bool secondRoom = false}) {
  final result = StringBuffer('''
    <select id="jsdpl"><option value="">全部</option>
    <option value="东1-101">东1-101 60(人) 多媒体</option>
    ${secondRoom ? '<option value="东1-102">东1-102 30(人) 普通</option>' : ''}
    </select><div id="ContentPlaceHolder1_LB_kb"><table>
    <tr><td rowspan="3">教室</td>
  ''');
  for (var d = 1; d <= 7; d++) {
    result.write('<td colspan="11">周$d</td>');
  }
  result.write('</tr><tr>');
  for (var d = 1; d <= 7; d++) {
    result.write('<td colspan="11">节次</td>');
  }
  result.write('</tr><tr>');
  for (var d = 1; d <= 7; d++) {
    for (var s = 1; s <= 11; s++) {
      result.write('<td>$s</td>');
    }
  }
  result.write('</tr><tr><td rowspan="2">东1-101</td>');
  for (var d = 1; d <= 7; d++) {
    for (var s = 1; s <= 11; s++) {
      if (d == day && s == 1) {
        result.write('<td colspan="2">数学 &amp; 应用<br>(1-18)</td>');
        s++;
      } else {
        result.write('<td></td>');
      }
    }
  }
  result.write('</tr><tr>');
  for (var d = 1; d <= 7; d++) {
    for (var s = 1; s <= 11; s++) {
      result.write('<td>${d == day && s == 1 ? '计算机班' : ''}</td>');
    }
  }
  result.write('</tr></table></div>');
  return result.toString();
}

void main() {
  test('展开跨行跨列，合并连续占用并解码实体及换行', () {
    final rooms = ClassroomUsageService.parse(html.parse(usageFixture()), 1);
    expect(rooms.single.name, '东1-101');
    expect(rooms.single.capacity, '60');
    expect(rooms.single.occupancies.single.start, 1);
    expect(rooms.single.occupancies.single.end, 2);
    expect(rooms.single.occupancies.single.event, '数学 & 应用 (1-18)');
    expect(rooms.single.occupancies.single.occupant, '计算机班');
    expect(rooms.single.occupied(2), isTrue);
    expect(rooms.single.occupied(3), isFalse);
  });
  test('周日映射第七组列，周一不误读周日', () {
    final doc = html.parse(usageFixture(day: 7));
    expect(ClassroomUsageService.parse(doc, 7).single.occupied(1), isTrue);
    expect(ClassroomUsageService.parse(doc, 1).single.occupancies, isEmpty);
  });
  test('拒绝缺少表格和被截断的响应', () {
    expect(
      () => ClassroomUsageService.parse(html.parse(''), 1),
      throwsFormatException,
    );
    final raw = usageFixture().replaceFirst(
      '<td colspan="11">周1</td>',
      '<td>周1</td>',
    );
    expect(
      () => ClassroomUsageService.parse(html.parse(raw), 1),
      throwsFormatException,
    );
  });
  test('拒绝表头漂移、非法跨度及缺失的教室', () {
    for (final raw in [
      usageFixture().replaceFirst('周1', '周日'),
      usageFixture().replaceFirst('colspan="11"', 'colspan="0"'),
      usageFixture(secondRoom: true),
    ]) {
      expect(
        () => ClassroomUsageService.parse(html.parse(raw), 1),
        throwsFormatException,
      );
    }
  });
  test('下拉选项保留真实 value，不把显示名称当请求值', () {
    final values = ClassroomUsageService.choices(
      html.parse(
        '<select id="xqdpl"><option value="">请选择</option><option value="01">旗山</option></select>',
      ),
      'xqdpl',
    );
    expect(values.single.value, '01');
    expect(values.single.label, '旗山');
  });
}
