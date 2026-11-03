import 'dart:math';

import 'package:fzu_assistant/model/course.dart';

/// A local timetable entry, owned by one stable academic account and term.
class CustomCourse {
  CustomCourse({
    required this.id,
    required this.account,
    required this.term,
    required this.name,
    this.teacher = '',
    this.location = '',
    required this.startClass,
    required this.endClass,
    required this.startWeek,
    required this.endWeek,
    required this.weekday,
    this.single = true,
    this.double = true,
    this.remark = '',
    this.color = 0xff83b6b1,
  }) {
    validate();
  }

  static const maxWeek = 19;
  static const maxPeriod = 11;
  final String id, account, term, name, teacher, location, remark;
  final int startClass, endClass, startWeek, endWeek, weekday, color;
  final bool single, double;

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(0x100000000).toRadixString(36)}';

  String get key => '$account/$term/$id';
  String get courseType => 'custom:$key';

  void validate() {
    if (id.isEmpty ||
        id.length > 100 ||
        account.trim().isEmpty ||
        account.length > 100 ||
        !RegExp(r'^\d{6}$').hasMatch(term) ||
        name.trim().isEmpty ||
        name.length > 60 ||
        teacher.length > 100 ||
        location.length > 200 ||
        remark.length > 1000 ||
        startClass < 1 ||
        endClass < startClass ||
        endClass > maxPeriod ||
        startWeek < 1 ||
        endWeek < startWeek ||
        endWeek > maxWeek ||
        weekday < 1 ||
        weekday > 7 ||
        !single && !double ||
        color < 0xff000000 ||
        color > 0xffffffff) {
      throw const FormatException('自定义课程数据无效');
    }
  }

  Course toCourse() => Course(
    type: courseType,
    name: name,
    credits: '',
    electiveType: '',
    examType: '',
    teacher: teacher,
    scheduleRules: [
      CourseScheduleRule(
        location: location,
        startClass: startClass,
        endClass: endClass,
        startWeek: startWeek,
        endWeek: endWeek,
        weekday: weekday,
        single: single,
        double: double,
      ),
    ],
    adjustRules: const [],
    rawExamTime: '',
    remark: remark,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'account': account,
    'term': term,
    'name': name,
    'teacher': teacher,
    'location': location,
    'startClass': startClass,
    'endClass': endClass,
    'startWeek': startWeek,
    'endWeek': endWeek,
    'weekday': weekday,
    'single': single,
    'double': double,
    'remark': remark,
    'color': color,
  };

  factory CustomCourse.fromJson(Map<String, dynamic> data) {
    try {
      return CustomCourse(
        id: data['id'] as String,
        account: data['account'] as String,
        term: data['term'] as String,
        name: data['name'] as String,
        teacher: data['teacher'] as String,
        location: data['location'] as String,
        startClass: data['startClass'] as int,
        endClass: data['endClass'] as int,
        startWeek: data['startWeek'] as int,
        endWeek: data['endWeek'] as int,
        weekday: data['weekday'] as int,
        single: data['single'] as bool,
        double: data['double'] as bool,
        remark: data['remark'] as String,
        color: data['color'] as int,
      );
    } on TypeError {
      throw const FormatException('自定义课程字段类型无效');
    }
  }

  /// Imports are strict: invalid rows or duplicate identities reject the file.
  static List<CustomCourse> parseList(Object? data) {
    if (data is! List || data.length > 10000) {
      throw const FormatException('自定义课程列表无效');
    }
    final result = <CustomCourse>[];
    final keys = <String>{};
    for (final row in data) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('自定义课程记录无效');
      }
      final course = CustomCourse.fromJson(row);
      if (!keys.add(course.key)) {
        throw const FormatException('自定义课程记录重复');
      }
      result.add(course);
    }
    return result;
  }
}
