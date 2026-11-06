import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/calendar_export.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarExportSource {
  const CalendarExportSource({
    required this.account,
    required this.term,
    required this.courses,
    this.updatedAt,
  });
  final String account;
  final CalTerm term;
  final List<Course> courses;
  final DateTime? updatedAt;
}

class CalendarExportService {
  CalendarExportService({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directory;

  Future<CalendarExportSource> load({
    required String account,
    required String preferredTerm,
    required bool useWest2Adjustments,
  }) async {
    if (account.isEmpty) throw StateError('请先登录教务账号');
    final calendar = await CacheHelper.loadMap(SpKeys.cacheSchoolCalendar);
    final caches = await CacheHelper.loadMap(SpKeys.cacheCoursesMap);
    if (calendar.isEmpty) throw StateError('请先在首页刷新校历和课表');
    final terms = SchoolCalendar.fromJson(calendar).terms;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final term = terms
        .where(
          (term) => preferredTerm.isNotEmpty
              ? term.term == preferredTerm
              : term.startDate.compareTo(today) <= 0 &&
                    term.endDate.compareTo(today) >= 0,
        )
        .firstOrNull;
    if (term == null) throw StateError('未找到所选学期的有效校历，请刷新校历');
    final cached = caches[term.term];
    if (cached is! Map || cached['courses'] is! List) {
      throw StateError('该学期暂无课表缓存，请先在首页刷新');
    }
    var courses = (cached['courses'] as List)
        .map((row) => Course.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
    if (useWest2Adjustments) {
      final holidays = await CacheHelper.loadMap(
        SpKeys.cacheHolidayAdjustmentsMap,
      );
      courses = CourseService.applyHolidayAdjustments(
        courses,
        (holidays[term.term] as List?) ?? [],
      );
    }
    final rawCustom = (await SharedPreferences.getInstance()).getString(
      CustomCourseStore.storageKey,
    );
    final custom = rawCustom == null
        ? <CustomCourse>[]
        : CustomCourse.parseList(jsonDecode(rawCustom));
    if (ApiClient.instance.studentId != account) {
      throw StateError('账号已变化，请重新打开导出页面');
    }
    return CalendarExportSource(
      account: account,
      term: term,
      courses: [
        ...courses,
        ...custom
            .where(
              (entry) => entry.account == account && entry.term == term.term,
            )
            .map((entry) => entry.toCourse()),
      ],
      updatedAt: cached['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(
              cached['updatedAt'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  Future<File> save(CalendarExport result, CalendarExportSource source) async {
    if (ApiClient.instance.studentId != source.account) {
      throw StateError('账号已变化，请重新导出');
    }
    final base = await _directory();
    final directory = await Directory(
      '${base.path}${Platform.pathSeparator}calendar_exports',
    ).create(recursive: true);
    if (ApiClient.instance.studentId != source.account) {
      throw StateError('账号已变化，请重新导出');
    }
    final digest = sha256
        .convert(utf8.encode(result.content))
        .toString()
        .substring(0, 16);
    final file = File(
      '${directory.path}${Platform.pathSeparator}fzu-schedule-$digest.ics',
    );
    await file.writeAsString(result.content, encoding: utf8, flush: true);
    return file;
  }
}
