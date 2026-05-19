class TermInfo {
  final List<String> terms;
  final String viewState;
  final String eventValidation;

  const TermInfo({
    required this.terms,
    required this.viewState,
    required this.eventValidation,
  });
}

class CourseScheduleRule {
  final String location;
  final int startClass;
  final int endClass;
  final int startWeek;
  final int endWeek;
  final int weekday;
  final bool single;
  final bool double;
  final bool adjust;
  final bool fromFullWeek;

  const CourseScheduleRule({
    required this.location,
    required this.startClass,
    required this.endClass,
    required this.startWeek,
    required this.endWeek,
    required this.weekday,
    required this.single,
    required this.double,
    this.adjust = false,
    this.fromFullWeek = false,
  });

  Map<String, dynamic> toJson() => {
    'location': location,
    'startClass': startClass,
    'endClass': endClass,
    'startWeek': startWeek,
    'endWeek': endWeek,
    'weekday': weekday,
    'single': single,
    'double': double,
    'adjust': adjust,
    'fromFullWeek': fromFullWeek,
  };

  factory CourseScheduleRule.fromJson(Map<String, dynamic> json) =>
      CourseScheduleRule(
        location: json['location'] ?? '',
        startClass: json['startClass'] ?? 0,
        endClass: json['endClass'] ?? 0,
        startWeek: json['startWeek'] ?? 0,
        endWeek: json['endWeek'] ?? 0,
        weekday: json['weekday'] ?? 0,
        single: json['single'] ?? true,
        double: json['double'] ?? true,
        adjust: json['adjust'] ?? false,
        fromFullWeek: json['fromFullWeek'] ?? false,
      );
}

class CourseAdjustRule {
  final int oldWeek;
  final int oldWeekday;
  final int oldStartClass;
  final int oldEndClass;
  final bool canceled;
  final int newWeek;
  final int newWeekday;
  final int newStartClass;
  final int newEndClass;
  final String newLocation;

  const CourseAdjustRule({
    required this.oldWeek,
    required this.oldWeekday,
    required this.oldStartClass,
    required this.oldEndClass,
    this.canceled = false,
    required this.newWeek,
    required this.newWeekday,
    required this.newStartClass,
    required this.newEndClass,
    required this.newLocation,
  });

  Map<String, dynamic> toJson() => {
    'oldWeek': oldWeek,
    'oldWeekday': oldWeekday,
    'oldStartClass': oldStartClass,
    'oldEndClass': oldEndClass,
    'canceled': canceled,
    'newWeek': newWeek,
    'newWeekday': newWeekday,
    'newStartClass': newStartClass,
    'newEndClass': newEndClass,
    'newLocation': newLocation,
  };

  factory CourseAdjustRule.fromJson(Map<String, dynamic> json) =>
      CourseAdjustRule(
        oldWeek: json['oldWeek'] ?? 0,
        oldWeekday: json['oldWeekday'] ?? 0,
        oldStartClass: json['oldStartClass'] ?? 0,
        oldEndClass: json['oldEndClass'] ?? 0,
        canceled: json['canceled'] ?? false,
        newWeek: json['newWeek'] ?? 0,
        newWeekday: json['newWeekday'] ?? 0,
        newStartClass: json['newStartClass'] ?? 0,
        newEndClass: json['newEndClass'] ?? 0,
        newLocation: json['newLocation'] ?? '',
      );
}

class Course {
  final String type;
  final String name;
  final String credits;
  final String electiveType;
  final String examType;
  final String teacher;
  final List<CourseScheduleRule> scheduleRules;
  final List<CourseAdjustRule> adjustRules;
  final String rawExamTime;
  final String remark;

  const Course({
    required this.type,
    required this.name,
    required this.credits,
    required this.electiveType,
    required this.examType,
    required this.teacher,
    required this.scheduleRules,
    required this.adjustRules,
    required this.rawExamTime,
    required this.remark,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'credits': credits,
    'electiveType': electiveType,
    'examType': examType,
    'teacher': teacher,
    'scheduleRules': scheduleRules.map((r) => r.toJson()).toList(),
    'adjustRules': adjustRules.map((r) => r.toJson()).toList(),
    'rawExamTime': rawExamTime,
    'remark': remark,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    type: json['type'] ?? '',
    name: json['name'] ?? '',
    credits: json['credits'] ?? '',
    electiveType: json['electiveType'] ?? '',
    examType: json['examType'] ?? '',
    teacher: json['teacher'] ?? '',
    scheduleRules:
        (json['scheduleRules'] as List?)
            ?.map((r) => CourseScheduleRule.fromJson(r))
            .toList() ??
        [],
    adjustRules:
        (json['adjustRules'] as List?)
            ?.map((r) => CourseAdjustRule.fromJson(r))
            .toList() ??
        [],
    rawExamTime: json['rawExamTime'] ?? '',
    remark: json['remark'] ?? '',
  );
}
