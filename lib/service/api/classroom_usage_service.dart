import 'package:html/dom.dart';
import 'package:fzu_assistant/model/classroom_usage.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/html_helper.dart';

/// Official teaching-office WebForms queries; no third-party service.
class ClassroomUsageService {
  static const url = 'https://jwcjwxt2.fzu.edu.cn:81/kkgl/kbcx/kbcx_zb.aspx';

  static String text(Element cell) {
    final copy = cell.clone(true);
    for (final br in copy.querySelectorAll('br')) {
      br.replaceWith(Text(' '));
    }
    return copy.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<ClassroomChoice> choices(Document doc, String id) => [
    for (final option in doc.querySelectorAll('#$id option'))
      if ((option.attributes['value'] ?? '').isNotEmpty &&
          !RegExp(r'请选择|^-+$').hasMatch(option.text.trim()))
        ClassroomChoice(option.attributes['value']!, option.text.trim()),
  ];

  Future<Document> _query({
    required String date,
    String? campus,
    String? building,
  }) async {
    final session = ApiClient.instance.captureSession();
    if (session.identifier == null) throw StateError('未登录');
    final query = {'id': session.identifier};
    var doc = await HtmlHelper.fetchHtml(url, queryParameters: query);
    session.check();
    Future<void> post(String? selectedBuilding) async {
      final term =
          doc.querySelector('#xnxqdpl option[selected]') ??
          doc.querySelector('#xnxqdpl option');
      if (term == null) throw const FormatException('教务处未返回学期');
      doc = await HtmlHelper.postHtml(
        url,
        queryParameters: query,
        data: {
          for (final field in doc.querySelectorAll(
            'input[type="hidden"][name]',
          ))
            field.attributes['name']!: field.attributes['value'] ?? '',
          'ctl00\$TB_rq': date,
          'ctl00\$xnxqdpl': term.attributes['value'] ?? '',
          'ctl00\$xqdpl': ?campus,
          'ctl00\$jxldpl': ?selectedBuilding,
          'ctl00\$qszdpl': '',
          'ctl00\$qsxqdpl': '',
          'ctl00\$qsjdpl': '',
          'ctl00\$zzjdpl': '',
          if (doc.querySelector('#jsdpl option[value=""]') != null)
            'ctl00\$jsdpl': '',
          'ctl00\$ContentPlaceHolder1\$BT_search': '查询',
        },
      );
      session.check();
    }

    if (campus != null) await post(null);
    if (building != null) await post(building);
    return doc;
  }

  Future<List<ClassroomChoice>> campuses(String date) async =>
      choices(await _query(date: date), 'xqdpl');

  Future<List<ClassroomChoice>> buildings(String date, String campus) async =>
      choices(await _query(date: date, campus: campus), 'jxldpl');

  Future<List<ClassroomUsage>> usage(
    String date,
    String campus,
    String building,
  ) async {
    final doc = await _query(date: date, campus: campus, building: building);
    if (choices(doc, 'jsdpl').isEmpty) {
      if (doc.querySelector('#jsdpl') == null) {
        throw const FormatException('教务处未返回教室列表');
      }
      return [];
    }
    return parse(doc, DateTime.parse(date).weekday);
  }

  /// Expand and validate all 78 columns before interpreting any empty slot.
  /// A missing/truncated response must never imply an available classroom.
  static List<ClassroomUsage> parse(Document doc, int weekday) {
    if (weekday < 1 || weekday > 7) throw ArgumentError.value(weekday);
    final table = doc.querySelector('#ContentPlaceHolder1_LB_kb > table');
    if (table == null) throw const FormatException('教室使用表缺失');
    final rows = table.children
        .expand((child) => child.localName == 'tr' ? [child] : child.children)
        .where((child) => child.localName == 'tr')
        .toList();
    if (rows.length < 3 || rows.length > 10000) {
      throw const FormatException('教室使用表不完整');
    }
    final grid = List.generate(
      rows.length,
      (_) => List<Element?>.filled(78, null),
    );
    for (var r = 0; r < rows.length; r++) {
      var c = 0;
      for (final cell in rows[r].children.where(
        (cell) => cell.localName == 'td' || cell.localName == 'th',
      )) {
        while (c < 78 && grid[r][c] != null) {
          c++;
        }
        final height = int.tryParse(cell.attributes['rowspan'] ?? '1') ?? 0;
        final width = int.tryParse(cell.attributes['colspan'] ?? '1') ?? 0;
        if (height < 1 ||
            width < 1 ||
            r + height > rows.length ||
            c + width > 78) {
          throw const FormatException('教室使用表跨度无效');
        }
        for (var y = r; y < r + height; y++) {
          for (var x = c; x < c + width; x++) {
            if (grid[y][x] != null) {
              throw const FormatException('教室使用表单元格重叠');
            }
            grid[y][x] = cell;
          }
        }
        c += width;
      }
      if (grid[r].any((cell) => cell == null)) {
        throw const FormatException('教室使用表被截断');
      }
    }
    for (var day = 1; day <= 7; day++) {
      for (var section = 1; section <= 11; section++) {
        final column = (day - 1) * 11 + section;
        if (text(grid[0][column]!) != '周$day' ||
            text(grid[2][column]!) != '$section') {
          throw const FormatException('教室使用表表头不匹配');
        }
      }
    }
    final metadata = <String, (String, String)>{};
    for (final option in choices(doc, 'jsdpl')) {
      final fields = option.label.split(RegExp(r'\s+'));
      if (fields.length < 3 ||
          fields.first != option.value ||
          metadata.containsKey(option.value)) {
        throw const FormatException('教室信息无效');
      }
      metadata[option.value] = (
        fields[1].split('(').first,
        fields.skip(2).join(' '),
      );
    }
    final result = <ClassroomUsage>[];
    final seen = <String>{};
    for (var r = 3; r < rows.length;) {
      final label = grid[r][0]!;
      final name = text(label).split(' ').first;
      final info = metadata[name];
      final span = int.tryParse(label.attributes['rowspan'] ?? '1') ?? 0;
      if (info == null ||
          !seen.add(name) ||
          span < 1 ||
          r + span > rows.length) {
        throw const FormatException('教室使用表与教室列表不匹配');
      }
      final items = <ClassroomOccupancy>[];
      for (var offset = 0; offset < span; offset += 2) {
        String? previousRaw;
        for (var section = 1; section <= 11; section++) {
          final column = (weekday - 1) * 11 + section;
          final raw = text(grid[r + offset][column]!);
          final occupant = offset + 1 < span
              ? text(grid[r + offset + 1][column]!)
              : '';
          if (raw.isEmpty && occupant.isEmpty) {
            previousRaw = null;
            continue;
          }
          if (previousRaw == raw &&
              items.isNotEmpty &&
              (occupant.isEmpty || occupant == items.last.occupant)) {
            final old = items.removeLast();
            items.add(
              ClassroomOccupancy(
                start: old.start,
                end: section,
                event: old.event,
                occupant: old.occupant,
              ),
            );
          } else {
            items.add(
              ClassroomOccupancy(
                start: section,
                end: section,
                event: raw.isEmpty ? occupant : raw,
                occupant: occupant,
              ),
            );
          }
          previousRaw = raw;
        }
      }
      result.add(
        ClassroomUsage(
          name: name,
          capacity: info.$1,
          type: info.$2,
          occupancies: items,
        ),
      );
      r += span;
    }
    if (seen.length != metadata.length) {
      throw const FormatException('教室使用表缺少部分教室');
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }
}
