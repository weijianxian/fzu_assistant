import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/session_expired_exception.dart';
import 'package:html/parser.dart' as html;

String _table(String rows) =>
    '<table id="ContentPlaceHolder1_DataList_xxk">$rows</table>';

const _headers = '''
  <tr><td colspan="7">&nbsp;</td></tr>
  <tr><td colspan="7">已报名讲座</td></tr>
  <tr>
    <td>讲座类别</td><td>期数</td><td>讲座题目</td><td>主讲人</td>
    <td>时间</td><td>地点</td><td>听取讲座情况</td>
  </tr>
''';

void main() {
  group('AcademicService.parseLectures', () {
    test('parses all seven fields, entities and Beijing full-width time', () {
      final lectures = AcademicService.parseLectures(
        html.parse(
          _table('''
          $_headers
          <tr style="background-color:white">
            <td> 人文 &amp; 科学 </td><td>012</td>
            <td><span>学习与创新</span></td><td> 张&nbsp;老师 </td>
            <td>2026-11-05&nbsp;&nbsp;19：30</td>
            <td> 旗山校区　图书馆报告厅 </td><td> 已听取 </td>
          </tr>
        '''),
        ),
      );
      expect(lectures, hasLength(1));
      final lecture = lectures.single;
      expect(lecture.category, '人文 & 科学');
      expect(lecture.issueNumber, 12);
      expect(lecture.title, '学习与创新');
      expect(lecture.speaker, '张 老师');
      expect(lecture.rawDateTime, '2026-11-05 19：30');
      expect(lecture.startTime, DateTime.utc(2026, 11, 5, 11, 30));
      expect(lecture.startTime!.isUtc, isTrue);
      expect(lecture.beijingStartTime, DateTime.utc(2026, 11, 5, 19, 30));
      expect(lecture.location, '旗山校区 图书馆报告厅');
      expect(lecture.attendanceStatus, '已听取');
    });

    test('does not require styling or exactly three leading rows', () {
      final lectures = AcademicService.parseLectures(
        html.parse(
          _table('''
          <tr><th>类别</th><th>期数</th><th>题目</th><th>主讲人</th>
            <th>日期</th><th>地点</th><th>出勤</th></tr>
          <tr><td>科技</td><td>18</td><td>机器人与未来</td><td>李老师</td>
            <td>2026/11/06 9:05:30</td><td>报告厅</td><td>未听取</td>
            <td><a>操作</a></td></tr>
        '''),
        ),
      );
      expect(lectures, hasLength(1));
      expect(lectures.single.title, '机器人与未来');
      expect(lectures.single.startTime, DateTime.utc(2026, 11, 6, 1, 5, 30));
    });

    test('empty, header-only and explicit empty tables return no lectures', () {
      for (final rows in [
        '',
        _headers,
        '$_headers<tr><td colspan="7">暂无报名记录</td></tr>',
        '<tr>${List.filled(7, '<td>&nbsp;</td>').join()}</tr>',
      ]) {
        expect(
          AcademicService.parseLectures(html.parse(_table(rows))),
          isEmpty,
        );
      }
    });

    test('missing table and empty response are query errors', () {
      for (final page in ['', '<html><body>系统繁忙</body></html>']) {
        expect(
          () => AcademicService.parseLectures(html.parse(page)),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('未找到已报名讲座表格'),
            ),
          ),
        );
      }
    });

    test('expired and password-login pages cannot become empty results', () {
      for (final page in [
        '<p>会话已失效，请重新登录</p>${_table(_headers)}',
        '<form><input type="password"></form>${_table(_headers)}',
        '<script>window.alert("请重新登录");</script>${_table(_headers)}',
      ]) {
        expect(
          () => AcademicService.parseLectures(html.parse(page)),
          throwsA(isA<SessionExpiredException>()),
        );
      }
    });

    test(
      'normal re-login navigation link does not invalidate an empty table',
      () {
        expect(
          AcademicService.parseLectures(
            html.parse('<a href="/login.aspx">重新登录</a>${_table(_headers)}'),
          ),
          isEmpty,
        );
      },
    );

    test('official alert text remains an error even alongside a table', () {
      expect(
        () => AcademicService.parseLectures(
          html.parse(
            '<script>window.alert("系统维护，请稍后查询");</script>${_table(_headers)}',
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('系统维护，请稍后查询'),
          ),
        ),
      );
    });

    test(
      'skips short, blank and nested rows while retaining valid records',
      () {
        final lectures = AcademicService.parseLectures(
          html.parse(
            _table('''
          $_headers
          <tr><td>损坏的记录</td><td>只有两列</td></tr>
          <tr><td colspan="7"><table><tr>
            <td>内部</td><td>99</td><td>内嵌说明</td><td>说明</td>
            <td>2026-11-05 12:00</td><td>说明</td><td>说明</td>
          </tr></table></td></tr>
          <tr><td>文化</td><td>20</td><td>有效讲座</td><td>王老师</td>
            <td>2026-11-05 18:00</td><td>报告厅</td><td>未听取</td></tr>
        '''),
          ),
        );
        expect(lectures.map((lecture) => lecture.title), ['有效讲座']);
      },
    );

    test(
      'bad and missing dates preserve records without inventing epoch zero',
      () {
        for (final date in ['', '待定', '2026-02-30 19:00']) {
          final lecture = AcademicService.parseLectures(
            html.parse(
              _table('''
            <tr><td>文化</td><td>待定</td><td>时间待确认的讲座</td><td></td>
              <td>$date</td><td></td><td>已报名</td></tr>
          '''),
            ),
          ).single;
          expect(lecture.issueNumber, isNull);
          expect(lecture.startTime, isNull);
          expect(lecture.beijingStartTime, isNull);
          expect(lecture.rawDateTime, date);
          expect(lecture.attendanceStatus, '已报名');
        }
      },
    );
  });

  group('AcademicService.parseLectureDateTime', () {
    test('UTC+8 conversion crosses the previous date/year correctly', () {
      expect(
        AcademicService.parseLectureDateTime('2026-01-01　00：05'),
        DateTime.utc(2025, 12, 31, 16, 5),
      );
      expect(
        AcademicService.parseLectureDateTime('2024-02-29 19:00'),
        DateTime.utc(2024, 2, 29, 11),
      );
    });

    test('rejects impossible dates, overflowing times and trailing data', () {
      for (final raw in [
        '',
        '待定',
        '2026-02-29 19:00',
        '2026-04-31 19:00',
        '2026-00-05 19:00',
        '2026-13-05 19:00',
        '2026-11-00 19:00',
        '2026-11-05 24:00',
        '2026-11-05 19:60',
        '2026-11-05 19:00:60',
        '0000-11-05 19:00',
        '2026-11-05',
        '2026-11-05 19:00 garbage',
      ]) {
        expect(AcademicService.parseLectureDateTime(raw), isNull, reason: raw);
      }
    });
  });
}
