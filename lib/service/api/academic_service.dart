import 'package:html/dom.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/common/utils/html_utils.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/credit.dart';
import 'package:fzu_assistant/model/empty_room.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/model/gpa.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/mark.dart';
import 'package:fzu_assistant/model/notice.dart';
import 'package:fzu_assistant/model/unified_exam.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/html_helper.dart';

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

  // ─── 工具 ───

  Map<String, dynamic> get _idParam => {'id': ApiClient.instance.userId};

  Future<Document> _fetch(String url) {
    return HtmlHelper.fetchHtml(url, queryParameters: _idParam);
  }

  Future<Document> _post(String url, Map<String, dynamic> data) {
    return HtmlHelper.postHtml(url, data: data, queryParameters: _idParam);
  }

  // ─── GPA ───

  Future<GPABean> getGPA() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final doc = await _fetch(_gpaUrl);

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

  // ─── 成绩 ───

  Future<List<Mark>> getMarks() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final doc = await _fetch(_marksUrl);

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
          credits: extractText(cells[3], 'span'),
          score: extractText(cells[4], 'font'),
          gpa: cells[5].text.trim(),
          earnedCredits: cells[6].text.trim(),
          electiveType: chineseOnly(cells[7].text.trim()),
          examType: chineseOnly(cells[8].text.trim()),
          teacher: cells[9].text.trim(),
          classroom: cells[10].text.trim(),
          examTime: cells[11].text.trim(),
        ),
      );
    }
    return marks;
  }

  // ─── 统考成绩（CET / 省计算机） ───

  Future<List<UnifiedExam>> getCET() => _getUnifiedExam(_cetUrl);
  Future<List<UnifiedExam>> getJS() => _getUnifiedExam(_jsUrl);

  Future<List<UnifiedExam>> _getUnifiedExam(String url) async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final doc = await _fetch(url);

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

  // ─── 考场 ───

  TermInfo? _cachedExamTermInfo;

  /// 最近一次 getExamRooms 内部获取的学期列表。
  List<String> get cachedExamTerms => _cachedExamTermInfo?.terms ?? [];

  Future<bool> hasCachedExamRooms(String term) async {
    final map = await CacheHelper.loadMap(SpKeys.cacheExamRoomsMap);
    return map.containsKey(term);
  }

  Future<List<String>> getExamTerms({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedExamTermInfo != null) {
      return _cachedExamTermInfo!.terms;
    }
    final termInfo = await _fetchExamTermInfo();
    return termInfo.terms;
  }

  Future<(String, List<ExamRoomInfo>)> getExamRoomsForPreferredTerm(
    String preferredTerm, {
    bool useCache = true,
  }) async {
    final termInfo = await _fetchExamTermInfo();
    final targetTerm =
        preferredTerm.isNotEmpty && termInfo.terms.contains(preferredTerm)
        ? preferredTerm
        : termInfo.terms.firstOrNull ?? '';

    if (targetTerm.isEmpty) return ('', <ExamRoomInfo>[]);

    if (useCache) {
      final cached = await _loadCachedExamRooms(targetTerm);
      if (cached != null) return (targetTerm, cached);
    }

    final rooms = await _fetchExamRooms(targetTerm, termInfo);
    return (targetTerm, rooms);
  }

  Future<List<ExamRoomInfo>?> _loadCachedExamRooms(String term) {
    return CacheHelper.loadForKey<List<ExamRoomInfo>>(
      SpKeys.cacheExamRoomsMap,
      term,
      (json) => (json as List).map((r) => ExamRoomInfo.fromJson(r)).toList(),
    );
  }

  Future<TermInfo> _fetchExamTermInfo() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final doc = await _fetch(_examRoomUrl);

    final viewState =
        doc.getElementById('__VIEWSTATE')?.attributes['value'] ?? '';
    final eventValidation =
        doc.getElementById('__EVENTVALIDATION')?.attributes['value'] ?? '';

    final options = doc.querySelectorAll(
      '#ContentPlaceHolder1_DDL_xnxq option',
    );
    final terms = options
        .map((o) => o.attributes['value'] ?? '')
        .where((v) => v.isNotEmpty)
        .toList();

    if (terms.isEmpty) throw Exception('无可用学期');

    final termInfo = TermInfo(
      terms: terms,
      viewState: viewState,
      eventValidation: eventValidation,
    );
    _cachedExamTermInfo = termInfo;
    return termInfo;
  }

  Future<List<ExamRoomInfo>> getExamRooms(
    String term, {
    bool useCache = true,
  }) async {
    if (term.isEmpty) return [];

    // 先尝试缓存
    if (useCache) {
      final cached = await _loadCachedExamRooms(term);
      if (cached != null) return cached;
    }

    final termInfo = await _fetchExamTermInfo();
    return _fetchExamRooms(term, termInfo);
  }

  Future<List<ExamRoomInfo>> _fetchExamRooms(
    String term,
    TermInfo termInfo,
  ) async {
    if (!termInfo.terms.contains(term)) return [];

    // POST 查询
    final postDoc = await _post(_examRoomUrl, {
      '__VIEWSTATE': termInfo.viewState,
      '__EVENTVALIDATION': termInfo.eventValidation,
      'ctl00\$ContentPlaceHolder1\$DDL_xnxq': term,
      'ctl00\$ContentPlaceHolder1\$BT_submit': '确定',
    });

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

    // 写入缓存
    CacheHelper.saveForKey(
      SpKeys.cacheExamRoomsMap,
      term,
      rooms.map((r) => r.toJson()).toList(),
    );

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

    final doc = await _fetch(_creditUrl);

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

  /// 从缓存加载校历，缓存未命中时走网络并写入缓存。
  Future<SchoolCalendar> loadOrFetchCalendar({bool useCache = true}) async {
    if (useCache) {
      final map = await CacheHelper.loadMap(SpKeys.cacheSchoolCalendar);
      if (map.isNotEmpty) return SchoolCalendar.fromJson(map);
    }
    final cal = await getSchoolCalendar();
    await CacheHelper.saveMap(SpKeys.cacheSchoolCalendar, cal.toJson());
    return cal;
  }

  /// 根据校历推算当前学期：找 startDate <= today <= endDate 的学期。
  static String getCurrentTermFromCalendar(SchoolCalendar cal) {
    final today = DateTime.now();
    for (final t in cal.terms) {
      final start = DateTime.tryParse(t.startDate);
      final end = DateTime.tryParse(t.endDate);
      if (start == null || end == null) continue;
      if (!today.isBefore(start) && !today.isAfter(end)) return t.term;
    }
    // 没有匹配则返回 startDate 最大的学期
    CalTerm? latest;
    for (final t in cal.terms) {
      if (latest == null || t.startDate.compareTo(latest.startDate) > 0) {
        latest = t;
      }
    }
    return latest?.term ?? '';
  }

  Future<SchoolCalendar> getSchoolCalendar() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final (doc, html) = await HtmlHelper.fetchHtmlGbk(
      _calendarUrl,
      queryParameters: _idParam,
    );

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

      final startRaw = raw.substring(6, 14); // YYYYMMDD
      final endRaw = raw.substring(14, 22); // YYYYMMDD

      terms.add(
        CalTerm(
          termId: raw,
          schoolYear: raw.substring(0, 4),
          term: raw.substring(0, 6),
          startDate:
              '${startRaw.substring(0, 4)}-${startRaw.substring(4, 6)}-${startRaw.substring(6, 8)}',
          endDate:
              '${endRaw.substring(0, 4)}-${endRaw.substring(4, 6)}-${endRaw.substring(6, 8)}',
        ),
      );
    }

    return SchoolCalendar(currentTerm: currentTerm, terms: terms);
  }

  Future<CalTermEvents> getTermEvents(String termId) async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final (doc, _) = await HtmlHelper.postHtmlGbk(
      _calendarUrl,
      data: {'xq': termId, 'submit': '提交'},
      queryParameters: _idParam,
    );

    final table = doc.querySelectorAll('table');
    if (table.length < 2) {
      return CalTermEvents(termId: termId, events: []);
    }

    final tr = table[1].querySelector('tbody > tr');
    if (tr == null) {
      return CalTermEvents(termId: termId, events: []);
    }

    final raw = tr.text.replaceAll(' ', ' ');
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
    final getDoc = await _fetch(_emptyRoomUrl);

    final viewState =
        getDoc.getElementById('__VIEWSTATE')?.attributes['value'] ?? '';
    final eventValidation =
        getDoc.getElementById('__EVENTVALIDATION')?.attributes['value'] ?? '';

    // Step 2: POST 查询教室类型
    final typeDoc = await _post(_emptyRoomUrl, {
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
    });

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
      final roomDoc = await _post(_emptyRoomUrl, {
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
      });

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
      final doc = await HtmlHelper.fetchHtml(_noticeUrl);

      // 首次加载时获取总页数
      _cachedNoticeTotalPages ??= _parseTotalPages(doc);
      return (_parseNoticeList(doc), _cachedNoticeTotalPages!);
    }

    _cachedNoticeTotalPages ??= await _fetchNoticeTotalPages();
    final totalPages = _cachedNoticeTotalPages!;

    final websitePage = totalPages - pageNum + 1;
    if (websitePage < 1) return (<NoticeInfo>[], totalPages);

    final doc = await HtmlHelper.fetchHtml(
      'https://jwch.fzu.edu.cn/jxtz/$websitePage.htm',
    );

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
        final doc = await HtmlHelper.fetchHtml(url);

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
