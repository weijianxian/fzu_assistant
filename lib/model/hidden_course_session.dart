import 'dart:convert';

import 'package:fzu_assistant/model/course.dart';

/// 本地隐藏的单次课程，以账号、学期、周次、星期和节次区分。
class HiddenCourseSession {
  final String account;
  final String term;
  final String courseKey;
  final String name;
  final String teacher;
  final String location;
  final int week;
  final int weekday;
  final int startClass;
  final int endClass;

  const HiddenCourseSession({
    required this.account,
    required this.term,
    required this.courseKey,
    required this.name,
    required this.teacher,
    required this.location,
    required this.week,
    required this.weekday,
    required this.startClass,
    required this.endClass,
  });

  static String keyForCourse(Course course) => jsonEncode([
    course.name,
    course.teacher,
    course.type,
    course.electiveType,
  ]);

  String get key => jsonEncode([
    account,
    term,
    courseKey,
    week,
    weekday,
    startClass,
    endClass,
  ]);

  Map<String, dynamic> toJson() => {
    'account': account,
    'term': term,
    'courseKey': courseKey,
    'name': name,
    'teacher': teacher,
    'location': location,
    'week': week,
    'weekday': weekday,
    'startClass': startClass,
    'endClass': endClass,
  };

  factory HiddenCourseSession.fromJson(Map<String, dynamic> json) {
    final session = HiddenCourseSession(
      account: json['account'] as String,
      term: json['term'] as String,
      courseKey: json['courseKey'] as String,
      name: json['name'] as String,
      teacher: json['teacher'] as String,
      location: json['location'] as String,
      week: json['week'] as int,
      weekday: json['weekday'] as int,
      startClass: json['startClass'] as int,
      endClass: json['endClass'] as int,
    );
    if (session.account.isEmpty ||
        session.term.isEmpty ||
        session.week < 1 ||
        session.weekday < 1 ||
        session.weekday > 7 ||
        session.startClass < 1 ||
        session.endClass < session.startClass) {
      throw const FormatException('隐藏课程记录无效');
    }
    return session;
  }
}
