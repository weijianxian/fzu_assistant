import 'package:html/dom.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/common/utils/html_utils.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/html_helper.dart';

class CourseService {
  static const _courseUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/student/xkjg/wdxk/xkjg_list.aspx';

  TermInfo? _cachedTermInfo;

  /// 最近一次 getCourses 内部获取的学期列表（含表单状态）。
  List<String> get cachedTerms => _cachedTermInfo?.terms ?? [];

  // ─── 按学期缓存课程 ───

  Future<Map<String, dynamic>?> _loadCourseCache(String term) {
    return CacheHelper.loadForKey<Map<String, dynamic>>(
      SpKeys.cacheCoursesMap,
      term,
      (json) => Map<String, dynamic>.from(json as Map),
    );
  }

  Future<bool> hasCachedCourses(String term) async {
    final map = await CacheHelper.loadMap(SpKeys.cacheCoursesMap);
    return map.containsKey(term);
  }

  Future<void> _saveCourseCache(
    String term,
    List<Course> courses,
    String viewState,
    String eventValidation,
  ) {
    return CacheHelper.saveForKey(SpKeys.cacheCoursesMap, term, {
      'courses': courses.map((c) => c.toJson()).toList(),
      'viewState': viewState,
      'eventValidation': eventValidation,
    });
  }

  // ─── 按学期推算 firstMonday ───

  /// 从校历推算指定学期的 firstMonday（学期第一天所在的周一）。
  Future<DateTime?> getFirstMondayForTerm(String term) async {
    final cal = await AcademicService().loadOrFetchCalendar();
    final match = cal.terms.where((t) => t.term == term);
    if (match.isEmpty) return null;

    final startDate = DateTime.tryParse(match.first.startDate);
    if (startDate == null) return null;

    final offset = (startDate.weekday + 6) % 7;
    return startDate.subtract(Duration(days: offset));
  }

  /// 由 firstMonday 计算当前是第几周。
  static int getWeekFromFirstMonday(DateTime firstMonday) {
    final week =
        (DateTime.now().difference(firstMonday).inDays / 7).floor() + 1;
    return week.clamp(1, 19);
  }

  // ─── 学期列表 ───

  Future<TermInfo> getTerms() async {
    final doc = await HtmlHelper.fetchHtml(
      _courseUrl,
      queryParameters: {'id': ApiClient.instance.userId},
    );

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

    return TermInfo(
      terms: terms,
      viewState: viewState,
      eventValidation: eventValidation,
    );
  }

  // ─── 课程列表 ───

  /// 获取指定学期的课程列表。
  /// [useCache] 为 true 时优先返回缓存数据。
  Future<List<Course>> getCourses(String term, {bool useCache = true}) async {
    // 先尝试缓存
    if (useCache) {
      final cached = await _loadCourseCache(term);
      if (cached != null) {
        return (cached['courses'] as List)
            .map((c) => Course.fromJson(c))
            .toList();
      }
    }

    // 获取表单状态（并缓存供页面使用）
    final termInfo = await getTerms();
    _cachedTermInfo = termInfo;

    // 网络请求
    final doc = await HtmlHelper.postHtml(
      _courseUrl,
      queryParameters: {'id': ApiClient.instance.userId},
      data: {
        'ctl00\$ContentPlaceHolder1\$DDL_xnxq': term,
        'ctl00\$ContentPlaceHolder1\$BT_submit': '确定',
        '__VIEWSTATE': termInfo.viewState,
        '__EVENTVALIDATION': termInfo.eventValidation,
      },
    );

    final table = doc.getElementById('ContentPlaceHolder1_DataList_xxk');
    if (table == null) return [];

    final rows = table.querySelectorAll('tbody > tr');
    if (rows.length <= 2) return [];

    final courses = <Course>[];
    for (var i = 2; i < rows.length; i++) {
      final row = rows[i];
      if ((row.attributes['style'] ?? '').isEmpty) continue;

      final cells = row.querySelectorAll('td');
      if (cells.length < 12) continue;

      courses.add(_parseCourse(cells));
    }

    // 写入缓存
    _saveCourseCache(
      term,
      courses,
      termInfo.viewState,
      termInfo.eventValidation,
    );
    return courses;
  }

  Course _parseCourse(List<Element> cells) {
    final scheduleRules = _parseScheduleRules(cells[8]);
    final adjustRules = _parseAdjustRules(cells[11]);
    final links = _extractLinks(cells[2]);

    return Course(
      type: _innerText(cells[0]),
      name: _innerText(cells[1]),
      credits: extractText(cells[4], 'span'),
      electiveType: chineseOnly(_innerText(cells[5])),
      examType: chineseOnly(_innerText(cells[6])),
      teacher: _innerText(cells[7]),
      scheduleRules: scheduleRules,
      adjustRules: adjustRules,
      rawExamTime: _innerText(cells[9]).trim(),
      remark: _innerText(cells[10]).trim(),
      syllabus: links.isNotEmpty ? links[0] : '',
      lessonplan: links.length > 1 ? links[1] : '',
    );
  }

  List<String> _extractLinks(Element cell) {
    final links = <String>[];
    final anchors = cell.querySelectorAll('a');
    final regex = RegExp(r"javascript:pop1\('(.*?)&");

    for (final a in anchors) {
      final href = a.attributes['href'] ?? '';
      final match = regex.firstMatch(href);
      if (match != null) {
        final url = 'https://jwcjwxt2.fzu.edu.cn:81${match.group(1)}';
        links.add(url);
      }
    }
    return links;
  }

  List<CourseScheduleRule> _parseScheduleRules(Element cell) {
    final lines = _innerTextWithBr(cell).split('\n');
    final rules = <CourseScheduleRule>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 3) continue;

      if (parts[0].contains('周') && parts.length >= 5) {
        final startWeek = _parseInt(parts[0].replaceAll('周', ''));
        final startWeekday = _parseInt(parts[1].replaceAll('星期', ''));
        final endWeek = _parseInt(parts[3].replaceAll('周', ''));
        final endWeekday = _parseInt(parts[4].replaceAll('星期', ''));

        for (var wd = 1; wd <= 7; wd++) {
          var cs = startWeek;
          var ce = endWeek;
          if (wd < startWeekday) cs++;
          if (wd > endWeekday) ce--;
          if (cs > ce) continue;
          rules.add(
            CourseScheduleRule(
              location: '',
              startClass: 1,
              endClass: 8,
              startWeek: cs,
              endWeek: ce,
              weekday: wd,
              single: true,
              double: true,
              fromFullWeek: true,
            ),
          );
        }
        continue;
      }

      final weekInfo = parts[0].split('-');
      final dayParts = parts[1].split(':');
      if (weekInfo.length < 2 || dayParts.length < 2) continue;

      final location = parts.length > 2 ? parts[2] : '';
      final classPart = dayParts[1].split('节')[0];
      final classRange = classPart.split('-');
      if (classRange.length < 2) continue;

      final single = !dayParts[1].contains('双');
      final double = !dayParts[1].contains('单');

      rules.add(
        CourseScheduleRule(
          location: location,
          startClass: _parseInt(classRange[0]),
          endClass: _parseInt(classRange[1]),
          startWeek: _parseInt(weekInfo[0]),
          endWeek: _parseInt(weekInfo[1]),
          weekday: _parseInt(dayParts[0].replaceAll('星期', '')),
          single: single,
          double: double,
        ),
      );
    }
    return rules;
  }

  List<CourseAdjustRule> _parseAdjustRules(Element cell) {
    final lines = _innerTextWithBr(cell).split('\n');
    final rules = <CourseAdjustRule>[];
    final regex = RegExp(
      r'(\d+)\s*周\s*星期(\d):(\d+)-(\d+)节\s*调至\s*(\d+)\s*周\s*星期(\d):(\d+)-(\d+)节\s*(\S+)',
    );

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final m = regex.firstMatch(line);
      if (m == null) continue;

      rules.add(
        CourseAdjustRule(
          oldWeek: _parseInt(m.group(1)!),
          oldWeekday: _parseInt(m.group(2)!),
          oldStartClass: _parseInt(m.group(3)!),
          oldEndClass: _parseInt(m.group(4)!),
          newWeek: _parseInt(m.group(5)!),
          newWeekday: _parseInt(m.group(6)!),
          newStartClass: _parseInt(m.group(7)!),
          newEndClass: _parseInt(m.group(8)!),
          newLocation: m.group(9)!,
        ),
      );
    }
    return rules;
  }

  static String _innerText(Element el) => el.text.trim();

  static String _innerTextWithBr(Element el) {
    final buf = StringBuffer();
    _walk(el, buf);
    return buf.toString();
  }

  static void _walk(Node node, StringBuffer buf) {
    if (node is Text) {
      buf.write(node.text);
    } else if (node is Element && node.localName == 'br') {
      buf.write('\n');
    } else {
      for (final child in node.nodes) {
        _walk(child, buf);
      }
    }
  }

  static int _parseInt(String s) => int.tryParse(s.trim()) ?? 0;
}
