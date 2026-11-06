import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/common/utils/html_utils.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/credit.dart';
import 'package:fzu_assistant/model/empty_room.dart';
import 'package:fzu_assistant/model/evaluation.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/model/gpa.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/lecture.dart';
import 'package:fzu_assistant/model/mark.dart';
import 'package:fzu_assistant/model/notice.dart';
import 'package:fzu_assistant/model/unified_exam.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/api/html_helper.dart';
import 'package:fzu_assistant/service/api/session_expired_exception.dart';
import 'package:fzu_assistant/service/api/user_service.dart';

class AcademicService {
  static const cultivatePlanListUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/pyfa/pyjh/pyjh_list.aspx';
  static const lecturesUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/glbm/lecture/jxjt_cszt.aspx';

  /// Match the user's cohort/college/major using the official WebForms page.
  Future<String> getCultivatePlan() async {
    final student = await UserService().getUserInfo();
    final doc = await _fetch(cultivatePlanListUrl);
    String? option(Document page, String name, bool Function(String) match) =>
        page
            .querySelectorAll('select[id\$="$name"] option')
            .where((e) => match(e.text.trim()))
            .map((e) => e.attributes['value'])
            .whereType<String>()
            .firstOrNull;
    final college = option(
      doc,
      'xymcdpl',
      (name) =>
          name == student.college ||
          (student.college.contains('数学与计算机') &&
              (name.contains('计算机与大数据') || name.contains('数学与统计'))),
    );
    final selected = await _post(cultivatePlanListUrl, {
      for (final input in doc.querySelectorAll('input[type="hidden"][name]'))
        input.attributes['name']!: input.attributes['value'] ?? '',
      '__EVENTTARGET': college == null ? '' : 'ctl00\$njdpl',
      '__EVENTARGUMENT': '',
      'ctl00\$njdpl': student.grade,
      'ctl00\$xymcdpl': ?college,
      'ctl00\$dldpl': college == null ? '【全部】' : '<-全部->',
      'ctl00\$zymcdpl': college == null ? '【全部】' : '<-全部->',
      'ctl00\$zylbdpl': '本专业',
      'ctl00\$ContentPlaceHolder1\$DDL_syxw': college == null
          ? '【全部】'
          : '<-全部->',
      'ctl00\$ContentPlaceHolder1\$BT_submit': '确定',
    });
    final major = option(selected, 'zymcdpl', (name) => name == student.major);
    if (college != null && major != null) {
      return Uri.parse(cultivatePlanListUrl)
          .resolve('pyfa_bzy.aspx')
          .replace(
            queryParameters: {
              'nj': student.grade,
              'xyh': college,
              'zyh': major,
              'zylb': '本专业',
              ..._idParam,
            },
          )
          .toString();
    }
    final fallback = college == null
        ? selected
        : await _post(cultivatePlanListUrl, {
            for (final input in selected.querySelectorAll(
              'input[type="hidden"][name]',
            ))
              input.attributes['name']!: input.attributes['value'] ?? '',
            '__EVENTTARGET': '',
            '__EVENTARGUMENT': '',
            'ctl00\$njdpl': student.grade,
            'ctl00\$dldpl': '【全部】',
            'ctl00\$zymcdpl': '【全部】',
            'ctl00\$zylbdpl': '本专业',
            'ctl00\$ContentPlaceHolder1\$DDL_syxw': '【全部】',
            'ctl00\$ContentPlaceHolder1\$BT_submit': '确定',
          });
    final fallbackUrl = Uri.parse(
      parseCultivatePlanLink(fallback, student.major),
    );
    return fallbackUrl
        .replace(queryParameters: {...fallbackUrl.queryParameters, ..._idParam})
        .toString();
  }

  static String parseCultivatePlanLink(Document doc, String major) {
    if (major.isEmpty) throw Exception('教务处未返回专业，请在教务页面手动选择培养计划');
    for (final row in doc.querySelectorAll('tr')) {
      final matches = row
          .querySelectorAll('td')
          .any(
            (cell) =>
                cell.text.trim().replaceFirst(RegExp(r'^[（(].*?[）)]'), '') ==
                major,
          );
      if (!matches) continue;
      for (final link in row.querySelectorAll('a[href]')) {
        var href = link.attributes['href']!;
        if (href.startsWith('javascript:')) {
          href = RegExp(r"pop1\('([^']+)'\)").firstMatch(href)?.group(1) ?? '';
        }
        if (!href.contains('pyfa')) continue;
        final uri = Uri.parse(cultivatePlanListUrl).resolve(href);
        if (uri.origin == Uri.parse(cultivatePlanListUrl).origin &&
            uri.path.startsWith('/pyfa/')) {
          return uri.toString();
        }
      }
    }
    throw Exception('未找到当前年级和专业的培养计划，可在教务页面手动选择');
  }

  static const _gpaUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/xyzk/jdpm/GPA_sheet.aspx';
  static const _marksUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/xyzk/cjyl/score_sheet.aspx';
  static const _cetUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/glbm/cet/cet_cszt.aspx';
  static const _jsUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/glbm/computer/jsj_cszt.aspx';
  static const _creditUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/xyzk/xftj/CreditStatistics.aspx';
  static const _calendarUrl = 'https://jwcjwxt2.fzu.edu.cn:82/xl.asp';
  static const _emptyRoomUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/kkgl/kbcx/kbcx_kjs.aspx';
  static const _noticeUrl = 'https://jwch.fzu.edu.cn/jxtz.htm';
  static const _evalBaseUrl = 'https://jwcjwxt2.fzu.edu.cn:81';
  static const _evalTeacherListUrl = '$_evalBaseUrl/student/jscp/TeaList.aspx';
  static const _evalTeacherUrl =
      '$_evalBaseUrl/student/jscp/TeaEvaluation.aspx';
  static const _evalCaptchaUrl = '$_evalBaseUrl/student/jscp/ValidNums.aspx';

  // ─── 工具 ───

  Map<String, dynamic> get _idParam => {'id': ApiClient.instance.userId};

  /// 教务处偶尔用 `window.alert('…')` 代替页面内容（例如欠费不能查成绩），
  /// 命中时必须把提示原文透出，否则用户只会看到"未找到成绩表格"。
  static final _alertPattern = RegExp(
    r"""window\.alert\s*\(\s*['"]([^'"]*)['"]\s*\)""",
  );

  /// 从页面里取出 `window.alert` 的提示原文，没有则返回 null。
  static String? extractAlertMessage(Document doc) {
    for (final script in doc.querySelectorAll('script')) {
      final match = _alertPattern.firstMatch(script.text);
      if (match == null) continue;
      final message = match.group(1)!.trim();
      if (message.isNotEmpty) return message;
    }
    return null;
  }

  Future<Document> _fetch(String url, {bool allowGbkFallback = false}) async {
    final doc = await HtmlHelper.fetchHtml(url, queryParameters: _idParam);
    if (allowGbkFallback && doc.outerHtml.contains('\uFFFD')) {
      // ASP.NET normally serves UTF-8; older deployments may still send GBK.
      // Keep the shared session-expiry and evaluation checks on both paths.
      final (gbkDoc, _) = await HtmlHelper.fetchHtmlGbk(
        url,
        queryParameters: _idParam,
      );
      return gbkDoc;
    }
    return doc;
  }

  Future<Document> _post(String url, Map<String, dynamic> data) {
    return HtmlHelper.postHtml(url, data: data, queryParameters: _idParam);
  }

  // ─── 嘉锡讲坛：已报名讲座 ───

  Future<List<Lecture>> getLectures() async {
    if (ApiClient.instance.usingCachedSession.value) {
      throw Exception('当前为缓存模式，请重新登录后查询已报名讲座');
    }
    if (ApiClient.instance.userId == null) throw Exception('未登录');
    final doc = await _fetch(lecturesUrl, allowGbkFallback: true);
    return parseLectures(doc);
  }

  /// Parse the official seven-column table without relying on inline styles or
  /// an exact number of spacer/title rows. A missing table is a failed query,
  /// whereas a present table with no registrations is a valid empty result.
  static List<Lecture> parseLectures(Document doc) {
    if (SessionExpiryDetector.isHtml(doc.outerHtml) ||
        doc.querySelector('input[type="password"]') != null) {
      throw const SessionExpiredException();
    }
    final alertMessage = extractAlertMessage(doc);
    if (alertMessage != null) throw Exception(alertMessage);
    final table = doc.getElementById('ContentPlaceHolder1_DataList_xxk');
    if (table == null) {
      throw Exception('未找到已报名讲座表格，请在教务页面手动查看');
    }

    final lectures = <Lecture>[];
    for (final row in table.querySelectorAll('tr')) {
      var owner = row.parent;
      while (owner != null && owner.localName != 'table') {
        owner = owner.parent;
      }
      if (owner != table) continue;
      final cells = row.children
          .where((cell) => cell.localName == 'td' || cell.localName == 'th')
          .toList();
      if (cells.length < 7 || cells.any((cell) => cell.localName == 'th')) {
        continue;
      }
      final values = cells.map((cell) => _lectureText(cell.text)).toList();
      if (values.every((value) => value.isEmpty)) continue;
      if (values[1].contains('期') &&
          (values[0].contains('类别') ||
              values[0].contains('分类') ||
              (values[2].contains('题目') && values[3].contains('主讲')))) {
        continue;
      }
      lectures.add(
        Lecture(
          category: values[0],
          issueNumber: int.tryParse(values[1]),
          title: values[2],
          speaker: values[3],
          startTime: parseLectureDateTime(values[4]),
          rawDateTime: values[4],
          location: values[5],
          attendanceStatus: values[6],
        ),
      );
    }
    return lectures;
  }

  static String _lectureText(String text) =>
      text.replaceAll(RegExp(r'[\s\u00a0\u3000]+'), ' ').trim();

  /// Server dates have no zone suffix and always mean UTC+8. Validate every
  /// component because DateTime otherwise normalizes dates such as February 30.
  static DateTime? parseLectureDateTime(String raw) {
    final match = RegExp(
      r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})[ T]+'
      r'(\d{1,2})[:：](\d{2})(?:[:：](\d{2}))?$',
    ).firstMatch(_lectureText(raw));
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final hour = int.parse(match[4]!);
    final minute = int.parse(match[5]!);
    final second = int.parse(match[6] ?? '0');
    if (year < 1 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    final wallClock = DateTime.utc(year, month, day, hour, minute, second);
    if (wallClock.year != year ||
        wallClock.month != month ||
        wallClock.day != day) {
      return null;
    }
    return wallClock.subtract(const Duration(hours: 8));
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

    final alertMessage = extractAlertMessage(doc);
    if (alertMessage != null) throw Exception(alertMessage);

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

  List<String> _cachedExamTerms = [];

  /// 最近一次 getExamRooms 内部获取的学期列表。
  List<String> get cachedExamTerms => _cachedExamTerms;

  Future<bool> hasCachedExamRooms(String term) async {
    final map = await CacheHelper.loadMap(SpKeys.cacheExamRoomsMap);
    return map.containsKey(term);
  }

  Future<(String, List<ExamRoomInfo>)> getExamRoomsForPreferredTerm(
    String preferredTerm, {
    bool useCache = true,
  }) async {
    if (ApiClient.instance.usingCachedSession.value) {
      final map = await CacheHelper.loadMap(SpKeys.cacheExamRoomsMap);
      final target = preferredTerm.isNotEmpty
          ? preferredTerm
          : (map.keys.toList()..sort()).lastOrNull ?? '';
      final cached = await _loadCachedExamRooms(target);
      if (cached != null) return (target, cached);
      throw Exception('当前为缓存模式，该学期暂无考场缓存');
    }
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

    final termInfo = await CourseService().getTerms();
    _cachedExamTerms = termInfo.terms;
    return termInfo;
  }

  Future<List<ExamRoomInfo>> getExamRooms(
    String term, {
    bool useCache = true,
  }) async {
    if (term.isEmpty) return [];

    // 先尝试缓存
    if (useCache || ApiClient.instance.usingCachedSession.value) {
      final cached = await _loadCachedExamRooms(term);
      if (cached != null) return cached;
    }
    if (ApiClient.instance.usingCachedSession.value) {
      throw Exception('当前为缓存模式，该学期暂无考场缓存');
    }

    final termInfo = await _fetchExamTermInfo();
    return _fetchExamRooms(term, termInfo);
  }

  Future<List<ExamRoomInfo>> _fetchExamRooms(
    String term,
    TermInfo termInfo,
  ) async {
    if (!termInfo.terms.contains(term)) return [];

    final account = ApiClient.instance.studentId;
    final courses = await CourseService().getCourses(
      term,
      useCache: false,
      persistCache: false,
      termInfo: termInfo,
    );
    if (account != ApiClient.instance.studentId) {
      throw const SessionExpiredException();
    }
    final rooms = courses.map(ExamRoomInfo.fromCourse).toList();

    // 写入缓存
    await CacheHelper.saveForKey(
      SpKeys.cacheExamRoomsMap,
      term,
      rooms.map((r) => r.toJson()).toList(),
    );

    return rooms;
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
    if (useCache || ApiClient.instance.usingCachedSession.value) {
      final map = await CacheHelper.loadMap(SpKeys.cacheSchoolCalendar);
      if (map.isNotEmpty) return SchoolCalendar.fromJson(map);
    }
    if (ApiClient.instance.usingCachedSession.value) {
      throw Exception('当前为缓存模式，暂无校历缓存');
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

  /// 从缓存加载指定学期的校历事件，缓存未命中时走网络并写入缓存。
  Future<CalTermEvents> loadOrFetchTermEvents(
    String termId, {
    bool useCache = true,
  }) async {
    if (useCache || ApiClient.instance.usingCachedSession.value) {
      final cached = await CacheHelper.loadForKey<CalTermEvents>(
        SpKeys.cacheTermEventsMap,
        termId,
        (json) =>
            CalTermEvents.fromJson(Map<String, dynamic>.from(json as Map)),
      );
      if (cached != null) return cached;
    }
    if (ApiClient.instance.usingCachedSession.value) {
      throw Exception('当前为缓存模式，暂无校历事件缓存');
    }

    final result = await getTermEvents(termId);
    await CacheHelper.saveForKey(
      SpKeys.cacheTermEventsMap,
      termId,
      result.toJson(),
    );
    return result;
  }

  /// 从教务系统获取指定学期的校历事件。
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

  /// `#xqdpl` 里可能带一个"请选择…"占位项，它不是有效校区。
  static final _campusPlaceholderPattern = RegExp(r'请选择|^-+$|^全部$');

  /// 空教室页面提供的校区下拉项。
  ///
  /// 校区列表是随教务系统变化的（例如泉港校区、厦门工艺美院），
  /// 硬编码会漏掉或给出无效值，这里直接以页面为准。
  Future<List<String>> getEmptyRoomCampuses() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    return parseEmptyRoomCampuses(await _fetch(_emptyRoomUrl));
  }

  /// 解析 `#xqdpl` 的校区选项。
  static List<String> parseEmptyRoomCampuses(Document doc) {
    return doc
        .querySelectorAll('#xqdpl option')
        .map((option) => option.text.trim())
        .where((name) => name.isNotEmpty)
        .where((name) => !_campusPlaceholderPattern.hasMatch(name))
        .toList();
  }

  Future<List<EmptyRoom>> getEmptyRooms(
    String date,
    String startPeriod,
    String endPeriod,
    String campus,
  ) async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final getDoc = await _fetch(_emptyRoomUrl);
    final baseFields = <String, String>{
      'ctl00\$TB_rq': date,
      'ctl00\$qsjdpl': startPeriod,
      'ctl00\$zzjdpl': endPeriod,
      'ctl00\$xqdpl': campus,
      'ctl00\$xz1': '>=',
      'ctl00\$jsrldpl': '0',
      'ctl00\$xz2': '>=',
      'ctl00\$ksrldpl': '0',
      'ctl00\$ContentPlaceHolder1\$BT_search': '查询',
    };
    Map<String, String> state(Document doc) => {
      '__VIEWSTATE':
          doc.getElementById('__VIEWSTATE')?.attributes['value'] ?? '',
      '__EVENTVALIDATION':
          doc.getElementById('__EVENTVALIDATION')?.attributes['value'] ?? '',
    };

    // 旗山按教学楼查询，避免不指定楼栋时遗漏教室（与 jwch 一致）。
    final buildings = campus.contains('旗山')
        ? <String>[
            '公共教学楼东1',
            '公共教学楼东2',
            '公共教学楼东3',
            '公共教学楼文科楼',
            '公共教学楼西1',
            '公共教学楼西2',
            '公共教学楼西3',
            '公共教学楼中楼',
          ]
        : <String>[''];
    final names = <String>{};
    for (final building in buildings) {
      final fields = {
        ...baseFields,
        if (building.isNotEmpty) 'ctl00\$jxldpl': building,
      };
      final typeDoc = await _post(_emptyRoomUrl, {...state(getDoc), ...fields});
      final roomTypes = typeDoc
          .querySelectorAll('#jslxdpl option')
          .map((e) => e.text.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      for (final roomType in roomTypes) {
        final roomDoc = await _post(_emptyRoomUrl, {
          ...state(typeDoc),
          ...fields,
          'ctl00\$jslxdpl': roomType,
        });
        for (final opt in roomDoc.querySelectorAll('#jsdpl option')) {
          final name = opt.text.trim();
          if (name.isNotEmpty) names.add(name);
        }
      }
    }
    return names.map((name) => EmptyRoom(name: name)).toList();
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

  // ─── 一键评议 ───

  /// 获取待评议的教师列表。
  /// [type] 为 'xqxk'（学期选课）或 'score'（成绩查询）。
  Future<List<EvaluationTeacher>> getEvaluationTeachers(String type) async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final doc = await HtmlHelper.fetchHtml(
      _evalTeacherListUrl,
      queryParameters: {..._idParam, 'bj': type},
    );

    final anchors = doc.querySelectorAll('a[href^="TeaEvaluation.aspx"]');
    final teachers = <EvaluationTeacher>[];

    for (final a in anchors) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      final uri = Uri.parse('$_evalBaseUrl/student/jscp/$href');
      final params = uri.queryParameters;
      teachers.add(
        EvaluationTeacher(
          courseName: params['kcmc'] ?? '',
          teacherName: params['jsxm'] ?? '',
          params: params,
        ),
      );
    }

    return teachers;
  }

  /// 获取评议验证码图片。
  Future<Uint8List> getEvaluationCaptcha() async {
    final resp = await ApiClient.instance.dio.get<List<int>>(
      _evalCaptchaUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(resp.data!);
  }

  /// 提交单个教师的评议。
  /// 返回 true 表示成功，false 表示验证码错误。
  Future<bool> submitEvaluation(
    Map<String, String> teacherParams,
    String score,
    String comment,
    String captcha,
  ) async {
    // Step 1: GET 获取 ASP.NET 表单令牌
    final params = {...teacherParams, ..._idParam};
    final getDoc = await HtmlHelper.fetchHtml(
      _evalTeacherUrl,
      queryParameters: params,
    );

    final viewState =
        getDoc.getElementById('__VIEWSTATE')?.attributes['value'] ?? '';
    final viewStateGenerator =
        getDoc.getElementById('__VIEWSTATEGENERATOR')?.attributes['value'] ??
        '';
    final eventValidation =
        getDoc.getElementById('__EVENTVALIDATION')?.attributes['value'] ?? '';
    if (viewState.isEmpty || eventValidation.isEmpty) {
      final message = _extractEvaluationError(getDoc);
      throw Exception(message ?? '未获取到评议表单，请刷新待评议课程后重试');
    }

    // Step 2: POST 提交评议
    final resp = await ApiClient.instance.dio.post<List<int>>(
      _evalTeacherUrl,
      queryParameters: {...teacherParams, ..._idParam},
      data: {
        '__VIEWSTATE': viewState,
        '__VIEWSTATEGENERATOR': viewStateGenerator,
        '__EVENTVALIDATION': eventValidation,
        'ctl00\$ContentPlaceHolder1\$TB_zf': score,
        'ctl00\$ContentPlaceHolder1\$TB_pj': comment,
        'ctl00\$ContentPlaceHolder1\$verifycode': captcha,
        'ctl00\$ContentPlaceHolder1\$Button_xk': '确定',
      },
      options: Options(responseType: ResponseType.bytes),
    );

    if (resp.statusCode != 200 && resp.statusCode != 302) {
      throw Exception('评议提交失败（HTTP ${resp.statusCode}）');
    }
    final body = utf8.decode(resp.data ?? [], allowMalformed: true);
    final message = _extractEvaluationError(html_parser.parse(body));
    if (message == null) return true;
    if (message.contains('验证码校验错误')) return false;
    throw Exception(message);
  }

  static String? _extractEvaluationError(Document doc) {
    final pattern = RegExp(
      r'''(?:window\.)?alert\s*\(\s*['"]([^'"]*)['"]\s*\)''',
    );
    for (final script in doc.querySelectorAll('script')) {
      final message = pattern.firstMatch(script.text)?.group(1)?.trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }
}
