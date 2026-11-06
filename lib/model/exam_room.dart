import 'package:fzu_assistant/model/course.dart';

class ExamRoomInfo {
  final String courseName;
  final String credit;
  final String teacher;
  final String date; // 2024年11月17日
  final String time; // 12:30-17:30
  final String location; // 旗山数计3-404
  final String rawExamTime;

  const ExamRoomInfo({
    required this.courseName,
    required this.credit,
    required this.teacher,
    required this.date,
    required this.time,
    required this.location,
    this.rawExamTime = '',
  });

  factory ExamRoomInfo.fromCourse(Course course) {
    final raw = course.rawExamTime.trim();
    final match = RegExp(
      r'^(\d{4})[年/-](\d{1,2})[月/-](\d{1,2})日?\s*'
      r'(\d{1,2})[:：](\d{2})\s*[-–—~至]\s*'
      r'(\d{1,2})[:：](\d{2})\s*(.*)$',
    ).firstMatch(raw.replaceAll(RegExp(r'\s+'), ' '));
    String date = '', time = '', location = '';
    if (match != null) {
      final values = [for (var i = 1; i <= 7; i++) int.parse(match[i]!)];
      final [year, month, day, startHour, startMinute, endHour, endMinute] =
          values;
      final parsedDate = DateTime.utc(year, month, day);
      if (parsedDate.year == year &&
          parsedDate.month == month &&
          parsedDate.day == day &&
          startHour < 24 &&
          endHour < 24 &&
          startMinute < 60 &&
          endMinute < 60 &&
          endHour * 60 + endMinute > startHour * 60 + startMinute) {
        date = '$year年$month月$day日';
        String pad(int value) => value.toString().padLeft(2, '0');
        time =
            '${pad(startHour)}:${pad(startMinute)}-'
            '${pad(endHour)}:${pad(endMinute)}';
        location = match[8]!.trim();
      }
    }
    return ExamRoomInfo(
      courseName: course.name,
      credit: course.credits,
      teacher: course.teacher,
      date: date,
      time: time,
      location: location,
      rawExamTime: raw,
    );
  }

  /// Official dates and times are Beijing wall time, independent of device zone.
  DateTime? _instant({required bool end}) {
    final dateMatch = RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日$')
        .firstMatch(date);
    final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$')
        .firstMatch(time);
    if (dateMatch == null || timeMatch == null) return null;
    final year = int.parse(dateMatch[1]!);
    final month = int.parse(dateMatch[2]!);
    final day = int.parse(dateMatch[3]!);
    final hour = int.parse(timeMatch[end ? 3 : 1]!);
    final minute = int.parse(timeMatch[end ? 4 : 2]!);
    final value = DateTime.utc(year, month, day, hour, minute);
    if (value.year != year ||
        value.month != month ||
        value.day != day ||
        hour > 23 ||
        minute > 59) {
      return null;
    }
    return value.subtract(const Duration(hours: 8));
  }

  DateTime? get startTime => _instant(end: false);
  DateTime? get endTime {
    final start = startTime, end = _instant(end: true);
    return start != null && end != null && end.isAfter(start) ? end : null;
  }

  bool hasFinished(DateTime now) => endTime?.isAfter(now.toUtc()) == false;

  static List<ExamRoomInfo> sorted(
    Iterable<ExamRoomInfo> rooms,
    DateTime now,
  ) => rooms.toList()
    ..sort((a, b) {
      final aStart = a.startTime, bStart = b.startTime;
      if (aStart == null || bStart == null) {
        if (aStart != null) return -1;
        if (bStart != null) return 1;
      } else {
        final aPast = a.hasFinished(now), bPast = b.hasFinished(now);
        if (aPast != bPast) return aPast ? 1 : -1;
        final order = aPast
            ? bStart.compareTo(aStart)
            : aStart.compareTo(bStart);
        if (order != 0) return order;
      }
      return a.courseName.compareTo(b.courseName);
    });

  Map<String, dynamic> toJson() => {
    'courseName': courseName,
    'credit': credit,
    'teacher': teacher,
    'date': date,
    'time': time,
    'location': location,
    'rawExamTime': rawExamTime,
  };

  factory ExamRoomInfo.fromJson(Map<String, dynamic> json) => ExamRoomInfo(
    courseName: json['courseName'] ?? '',
    credit: json['credit'] ?? '',
    teacher: json['teacher'] ?? '',
    date: json['date'] ?? '',
    time: json['time'] ?? '',
    location: json['location'] ?? '',
    rawExamTime: json['rawExamTime'] ?? '',
  );
}
