import 'dart:convert';
import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/credit.dart';
import 'package:fzu_assistant/model/empty_room.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/model/gpa.dart';
import 'package:fzu_assistant/model/mark.dart';
import 'package:fzu_assistant/model/notice.dart';
import 'package:fzu_assistant/model/unified_exam.dart';
import 'package:fzu_assistant/service/api/api_client.dart';

class AcademicService {
  static const _gpaUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/xyzk/jdpm/GPA_sheet.aspx';
  static const _marksUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/xyzk/cjyl/score_sheet.aspx';
  static const _cetUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/glbm/cet/cet_cszt.aspx';
  static const _jsUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/glbm/computer/jsj_cszt.aspx';
  static const _examRoomUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/xkjg/examination/exam_list.aspx';
  static const _creditUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/xyzk/xftj/CreditStatistics.aspx';
  static const _calendarUrl = 'https://jwcjwxt2.fzu.edu.cn:82/xl.asp';
  static const _emptyRoomUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/kkgl/kbcx/kbcx_kjs.aspx';
  static const _noticeUrl = 'https://jwch.fzu.edu.cn/jxtz.htm';

  Dio get _dio => ApiClient.instance.dio;

  Future<GPABean> getGPA() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final resp = await _dio.get<List<int>>(
      _gpaUrl,
      queryParameters: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );

    final html = utf8.decode(resp.data!, allowMalformed: true);
    final doc = html_parser.parse(html);

    // 更新时间
    final timeEl = doc.getElementById('ContentPlaceHolder1_Label1');
    final time = timeEl?.text.trim() ?? '';

    // GPA 表格
    final table = doc.getElementById('ContentPlaceHolder1_DataList_xxk');
    if (table == null) throw Exception('未找到绩点表格');

    // 表头行（有特定 background style）
    final titleRow = table.querySelector('tr[style*="background:#efefef"]');
    if (titleRow == null) throw Exception('未找到表头行');

    final headerCells = titleRow.querySelectorAll('td[align="center"]');
    final width = headerCells.length;
    final headers = headerCells.map((e) => e.text.trim()).toList();

    // 所有 align=center 的 td
    final allCells = table.querySelectorAll('td[align="center"]');
    if (allCells.isEmpty) throw Exception('未找到绩点数据');

    final height = allCells.length ~/ width - 1;
    final data = <GPAData>[];

    for (var h = 1; h <= height; h++) {
      for (var w = 0; w < width; w++) {
        data.add(
          GPAData(type: headers[w], value: allCells[width * h + w].text.trim()),
        );
      }
    }

    return GPABean(time: time, data: data);
  }

  Future<List<Mark>> getMarks() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final resp = await _dio.get<List<int>>(
      _marksUrl,
      queryParameters: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );

    final html = utf8.decode(resp.data!, allowMalformed: true);
    final doc = html_parser.parse(html);

    final table = doc.getElementById('ContentPlaceHolder1_DataList_xxk');
    if (table == null) throw Exception('未找到成绩表格');

    final rows = table.querySelectorAll('tbody > tr');
    if (rows.length <= 2) return [];

    final marks = <Mark>[];
    for (var i = 2; i < rows.length; i++) {
      final row = rows[i];
      if ((row.attributes['style'] ?? '').isEmpty) continue;

      final cells = row.querySelectorAll('td');
      if (cells.length < 12) continue;

      marks.add(
        Mark(
          type: cells[0].text.trim(),
          semester: cells[1].text.trim(),
          name: cells[2].text.trim(),
          credits: _extractFromTag(cells[3], 'span'),
          score: _extractFromTag(cells[4], 'font'),
          gpa: cells[5].text.trim(),
          earnedCredits: cells[6].text.trim(),
          electiveType: _chineseOnly(cells[7].text.trim()),
          examType: _chineseOnly(cells[8].text.trim()),
          teacher: cells[9].text.trim(),
          classroom: cells[10].text.trim(),
          examTime: cells[11].text.trim(),
        ),
      );
    }
    return marks;
  }

  static String _extractFromTag(Element el, String tag) {
    return el.querySelector(tag)?.text.trim() ?? el.text.trim();
  }

  static String _chineseOnly(String s) {
    return s.replaceAll(RegExp(r'[^一-龥0-9]'), '');
  }

  // ─── 统考成绩（CET / 省计算机） ───

  Future<List<UnifiedExam>> getCET() => _getUnifiedExam(_cetUrl);
  Future<List<UnifiedExam>> getJS() => _getUnifiedExam(_jsUrl);

  Future<List<UnifiedExam>> _getUnifiedExam(String url) async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final resp = await _dio.get<List<int>>(
      url,
      queryParameters: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );

    final html = utf8.decode(resp.data!, allowMalformed: true);
    final doc = html_parser.parse(html);

    final table = doc.getElementById('ContentPlaceHolder1_DataList_xxk');
    if (table == null) return [];

    final rows = table.querySelectorAll('tr[onmouseover]');
    final exams = <UnifiedExam>[];
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 3) continue;
      exams.add(
        UnifiedExam(
          name: cells[0].text.trim(),
          term: cells[1].text.trim(),
          score: cells[2].text.trim(),
        ),
      );
    }
    return exams;
  }

  // ─── 考场查询 ───

  Future<List<ExamRoomInfo>> getExamRooms() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    // 先 GET 拿 __VIEWSTATE / __EVENTVALIDATION
    final getResp = await _dio.get<List<int>>(
      _examRoomUrl,
      queryParameters: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );
    final getHtml = utf8.decode(getResp.data!, allowMalformed: true);
    final getDoc = html_parser.parse(getHtml);

    final viewState =
        getDoc.getElementById('__VIEWSTATE')?.attributes['value'] ?? '';
    final eventValidation =
        getDoc.getElementById('__EVENTVALIDATION')?.attributes['value'] ?? '';

    // POST 查询
    final postResp = await _dio.post<List<int>>(
      _examRoomUrl,
      queryParameters: {'id': id},
      data: {
        '__VIEWSTATE': viewState,
        '__EVENTVALIDATION': eventValidation,
        'ctl00\$ContentPlaceHolder1\$BT_submit': '确定',
      },
      options: Options(responseType: ResponseType.bytes),
    );
    final postHtml = utf8.decode(postResp.data!, allowMalformed: true);
    final postDoc = html_parser.parse(postHtml);

    final table = postDoc.getElementById('ContentPlaceHolder1_DataList_xxk');
    if (table == null) return [];

    final rows = table.querySelectorAll('tr[onmouseover]');
    final rooms = <ExamRoomInfo>[];
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 4) continue;

      final raw = cells[3].text.trim();
      final (date, time, location) = _parseDateAndLocation(raw);

      rooms.add(
        ExamRoomInfo(
          courseName: cells[0].text.trim(),
          credit: cells[1].text.trim(),
          teacher: cells[2].text.trim(),
          date: date,
          time: time,
          location: location,
        ),
      );
    }
    return rooms;
  }

  static (String, String, String) _parseDateAndLocation(String raw) {
    if (raw.isEmpty) return ('', '', '暂无考场数据');
    final parts = raw.split(RegExp(r'\s+'));
    if (parts.length < 3) return (raw, '', '');
    return (parts[0], parts[1], parts[2]);
  }

  // ─── 学分统计 ───

  Future<List<CreditStatistics>> getCredit() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final resp = await _dio.get<List<int>>(
      _creditUrl,
      queryParameters: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );

    final html = utf8.decode(resp.data!, allowMalformed: true);
    final doc = html_parser.parse(html);

    final spanNode = doc.getElementById('ContentPlaceHolder1_LB_kb');
    if (spanNode == null) throw Exception('未找到学分统计');

    final tables = spanNode.querySelectorAll('table');
    if (tables.isEmpty) throw Exception('未找到学分表格');

    final result = <CreditStatistics>[];
    // 去掉最后一个表格
    final validTables = tables.sublist(0, tables.length - 1);

    for (final table in validTables) {
      final rows = table.querySelectorAll('tr');
      // 临时存储三列数据
      final temp = <List<String>>[[], [], []];

      for (var i = 0; i < rows.length; i++) {
        final cells = rows[i].querySelectorAll('td');
        for (final cell in cells) {
          final text = cell.text.trim();
          if (text != '查') {
            temp[i].add(text);
          }
        }
      }

      // 构建 CreditStatistics
      for (var i = 0; i < temp[0].length; i++) {
        if (temp[0][i].isNotEmpty && !temp[0][i].contains('情况')) {
          result.add(
            CreditStatistics(
              type: temp[0][i],
              total: temp[1][i],
              gain: temp[2][i],
            ),
          );
        }
      }
    }

    return result;
  }

  // ─── 校历 ───

  Future<SchoolCalendar> getSchoolCalendar() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final resp = await _dio.get<List<int>>(
      _calendarUrl,
      queryParameters: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );

    var html = gbk.decode(resp.data!, allowMalformed: true);
    final doc = html_parser.parse(html);

    // 当前学期
    final curTermMatch = RegExp(r'当前学期：(\d{6})').firstMatch(html);
    final currentTerm = curTermMatch?.group(1) ?? '';

    // 学期列表
    final options = doc.querySelectorAll('select[name="xq"] option');
    final terms = <CalTerm>[];
    for (final opt in options) {
      final raw = opt.attributes['value'] ?? '';
      if (raw.length < 22) continue;
      if (terms.length >= 16) break;

      final startDate =
          '${raw.substring(6, 8)}-${raw.substring(8, 10)}-${raw.substring(10, 12)}';
      final endDate =
          '${raw.substring(14, 16)}-${raw.substring(16, 18)}-${raw.substring(18, 20)}';

      terms.add(
        CalTerm(
          termId: raw,
          schoolYear: raw.substring(0, 4),
          term: raw.substring(0, 6),
          startDate: '${raw.substring(0, 4)}-$startDate',
          endDate: '${raw.substring(0, 4)}-$endDate',
        ),
      );
    }

    return SchoolCalendar(currentTerm: currentTerm, terms: terms);
  }

  Future<CalTermEvents> getTermEvents(String termId) async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final resp = await _dio.post<List<int>>(
      _calendarUrl,
      queryParameters: {'id': id},
      data: {'xq': termId, 'submit': '提交'},
      options: Options(responseType: ResponseType.bytes),
    );

    var html = gbk.decode(resp.data!, allowMalformed: true);
    final doc = html_parser.parse(html);

    final table = doc.querySelectorAll('table');
    if (table.length < 2) {
      return CalTermEvents(termId: termId, events: []);
    }

    final tr = table[1].querySelector('tbody > tr');
    if (tr == null) {
      return CalTermEvents(termId: termId, events: []);
    }

    final raw = tr.text.replaceAll(' ', ' ');
    final parts = raw.split('；');
    final events = <CalTermEvent>[];

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final splitted = trimmed.split('为');
      if (splitted.length < 2) {
        events.add(CalTermEvent(name: trimmed, startDate: '', endDate: ''));
        continue;
      }

      final dateStr = splitted[0].trim();
      final name = splitted.sublist(1).join('为').trim();
      final dateParts = dateStr.split('至');

      if (dateParts.length >= 2) {
        events.add(
          CalTermEvent(
            name: name,
            startDate: dateParts[0].trim(),
            endDate: dateParts[1].trim(),
          ),
        );
      } else {
        final date = dateParts[0].trim();
        events.add(CalTermEvent(name: name, startDate: date, endDate: date));
      }
    }

    return CalTermEvents(termId: termId, events: events);
  }

  // ─── 空教室查询 ───

  Future<List<EmptyRoom>> getEmptyRooms(
    String date,
    String startPeriod,
    String endPeriod,
    String campus,
  ) async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    // Step 1: GET 拿 __VIEWSTATE / __EVENTVALIDATION
    final getResp = await _dio.get<List<int>>(
      _emptyRoomUrl,
      queryParameters: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );
    final getHtml = utf8.decode(getResp.data!, allowMalformed: true);
    final getDoc = html_parser.parse(getHtml);

    final viewState =
        getDoc.getElementById('__VIEWSTATE')?.attributes['value'] ?? '';
    final eventValidation =
        getDoc.getElementById('__EVENTVALIDATION')?.attributes['value'] ?? '';

    // Step 2: POST 查询教室类型
    final typeResp = await _dio.post<List<int>>(
      _emptyRoomUrl,
      queryParameters: {'id': id},
      data: {
        '__VIEWSTATE': viewState,
        '__EVENTVALIDATION': eventValidation,
        'ctl00\$TB_rq': date,
        'ctl00\$qsjdpl': startPeriod,
        'ctl00\$zzjdpl': endPeriod,
        'ctl00\$xqdpl': campus,
        'ctl00\$xz1': '>=',
        'ctl00\$jsrldpl': '0',
        'ctl00\$xz2': '>=',
        'ctl00\$ksrldpl': '0',
        'ctl00\$ContentPlaceHolder1\$BT_search': '查询',
      },
      options: Options(responseType: ResponseType.bytes),
    );
    final typeHtml = utf8.decode(typeResp.data!, allowMalformed: true);
    final typeDoc = html_parser.parse(typeHtml);

    // 获取教室类型列表
    final roomTypeOptions = typeDoc.querySelectorAll('#jslxdpl option');
    final roomTypes = roomTypeOptions
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // 获取更新后的 state
    final vs2 =
        typeDoc.getElementById('__VIEWSTATE')?.attributes['value'] ?? '';
    final ev2 =
        typeDoc.getElementById('__EVENTVALIDATION')?.attributes['value'] ?? '';

    // Step 3: 按教室类型逐个查询
    final allRooms = <EmptyRoom>[];
    for (final roomType in roomTypes) {
      final roomResp = await _dio.post<List<int>>(
        _emptyRoomUrl,
        queryParameters: {'id': id},
        data: {
          '__VIEWSTATE': vs2,
          '__EVENTVALIDATION': ev2,
          'ctl00\$TB_rq': date,
          'ctl00\$qsjdpl': startPeriod,
          'ctl00\$zzjdpl': endPeriod,
          'ctl00\$jslxdpl': roomType,
          'ctl00\$xqdpl': campus,
          'ctl00\$xz1': '>=',
          'ctl00\$jsrldpl': '0',
          'ctl00\$xz2': '>=',
          'ctl00\$ksrldpl': '0',
          'ctl00\$ContentPlaceHolder1\$BT_search': '查询',
        },
        options: Options(responseType: ResponseType.bytes),
      );
      final roomHtml = utf8.decode(roomResp.data!, allowMalformed: true);
      final roomDoc = html_parser.parse(roomHtml);

      final roomOptions = roomDoc.querySelectorAll('#jsdpl option');
      for (final opt in roomOptions) {
        final name = opt.text.trim();
        if (name.isNotEmpty) {
          allRooms.add(EmptyRoom(name: name));
        }
      }
    }

    return allRooms;
  }

  // ─── 教务通知 ───

  int? _cachedNoticeTotalPages;

  Future<(List<NoticeInfo>, int)> getNotices(int pageNum) async {
    // 网站分页是反序的：jxtz.htm=最新，jxtz/1.htm=最旧
    // 用户视角：pageNum 1=最新，pageNum N=最旧
    // pageNum 1 直接爬取首页（最新），pageNum > 1 用反向公式

    if (pageNum == 1) {
      final resp = await _dio.get<List<int>>(
        _noticeUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final html = utf8.decode(resp.data!, allowMalformed: true);
      final doc = html_parser.parse(html);

      // 首次加载时获取总页数
      _cachedNoticeTotalPages ??= _parseTotalPages(doc);
      return (_parseNoticeList(doc), _cachedNoticeTotalPages!);
    }

    _cachedNoticeTotalPages ??= await _fetchNoticeTotalPages();
    final totalPages = _cachedNoticeTotalPages!;

    final websitePage = totalPages - pageNum + 1;
    if (websitePage < 1) return (<NoticeInfo>[], totalPages);

    final resp = await _dio.get<List<int>>(
      'https://jwch.fzu.edu.cn/jxtz/$websitePage.htm',
      options: Options(responseType: ResponseType.bytes),
    );
    final html = utf8.decode(resp.data!, allowMalformed: true);
    final doc = html_parser.parse(html);

    return (_parseNoticeList(doc), totalPages);
  }

  /// 从页面中解析总页数（用户视角，含 jxtz.htm 这一页）
  int _parseTotalPages(Document doc) {
    int maxWebsitePage = 0;
    for (final el in doc.querySelectorAll('.p_pages a, span.p_pages a')) {
      final n = int.tryParse(el.text.trim());
      if (n != null && n > maxWebsitePage) maxWebsitePage = n;
    }
    if (maxWebsitePage == 0) {
      for (final el in doc.querySelectorAll('.p_pages, span.p_pages')) {
        for (final m in RegExp(r'\d+').allMatches(el.text)) {
          final n = int.tryParse(m.group(0)!);
          if (n != null && n > maxWebsitePage) maxWebsitePage = n;
        }
      }
    }
    return maxWebsitePage > 0 ? maxWebsitePage : 1;
  }

  Future<int> _fetchNoticeTotalPages() async {
    for (final tryPage in [2, 3, 1]) {
      final url = 'https://jwch.fzu.edu.cn/jxtz/$tryPage.htm';
      try {
        final resp = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final html = utf8.decode(resp.data!, allowMalformed: true);
        final doc = html_parser.parse(html);

        int maxWebsitePage = 0;
        // 策略1: p_pages 链接文字
        final pagesSpans = doc.querySelectorAll(
          '.p_pages, span.p_pages, div.p_pages',
        );
        for (final span in pagesSpans) {
          for (final link in span.querySelectorAll('a')) {
            final n = int.tryParse(link.text.trim());
            if (n != null && n > maxWebsitePage) maxWebsitePage = n;
          }
        }
        // 策略2: href 中的 jxtz/{n}.htm
        if (maxWebsitePage == 0) {
          for (final a in doc.querySelectorAll('a[href]')) {
            final href = a.attributes['href'] ?? '';
            final m = RegExp(r'jxtz/(\d+)\.htm').firstMatch(href);
            if (m != null) {
              final n = int.tryParse(m.group(1)!);
              if (n != null && n > maxWebsitePage) maxWebsitePage = n;
            }
          }
        }
        if (maxWebsitePage > 0) return maxWebsitePage;
      } catch (_) {}
    }
    return 2;
  }

  List<NoticeInfo> _parseNoticeList(Document doc) {
    final container = doc.querySelector('div.box-gl.clearfix');
    if (container == null) return [];

    final items = container.querySelectorAll('ul.list-gl li');
    final notices = <NoticeInfo>[];

    for (final item in items) {
      final dateEl = item.querySelector('span.doclist_time');
      final linkEl = item.querySelector('a');
      if (dateEl == null || linkEl == null) continue;

      final date = dateEl.text.trim();
      final title = (linkEl.attributes['title'] ?? '').trim();
      final rawHref = (linkEl.attributes['href'] ?? '').trim();

      // 部门信息在 </span> 和 <a> 之间的文本节点，格式为 【xxx】
      String department = '';
      for (final node in item.nodes) {
        if (node.nodeType == 3) {
          final text = node.text?.trim() ?? '';
          final m = RegExp(r'【(.+?)】').firstMatch(text);
          if (m != null) {
            department = m.group(1)!;
            break;
          }
        }
      }

      final (convertedUrl, wbTreeId, wbNewsId) = _convertNoticeUrl(rawHref);

      notices.add(
        NoticeInfo(
          title: title,
          url: convertedUrl,
          date: date,
          department: department,
          wbTreeId: wbTreeId,
          wbNewsId: wbNewsId,
        ),
      );
    }

    return notices;
  }

  static (String, String, String) _convertNoticeUrl(String raw) {
    var cleaned = raw.replaceAll('../', '');
    if (!cleaned.startsWith('http')) {
      cleaned = 'https://jwch.fzu.edu.cn/$cleaned';
    }

    // info/TREE/NEWS.htm 格式
    final match = RegExp(r'info/(\d+)/(\d+)\.htm').firstMatch(cleaned);
    if (match != null) {
      final treeId = match.group(1)!;
      final newsId = match.group(2)!;
      final url =
          'https://jwch.fzu.edu.cn/content.jsp?urltype=news.NewsContentUrl&wbtreeid=$treeId&wbnewsid=$newsId';
      return (url, treeId, newsId);
    }

    // 已经是 content.jsp 格式
    final treeMatch = RegExp(r'wbtreeid=(\d+)').firstMatch(cleaned);
    final newsMatch = RegExp(r'wbnewsid=(\d+)').firstMatch(cleaned);
    if (treeMatch != null && newsMatch != null) {
      return (cleaned, treeMatch.group(1)!, newsMatch.group(1)!);
    }

    return (cleaned, '', '');
  }
}
