/// Beijing calendar fields for display only; [instant] remains a real instant.
DateTime jobFairBeijingTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));

/// A calendar month in Beijing, independent of the device time zone.
class JobFairMonth {
  factory JobFairMonth(int year, int month) {
    if (year < 1 || year > 9999 || month < 1 || month > 12) {
      throw const FormatException('招聘活动月份无效');
    }
    return JobFairMonth._(year, month);
  }

  const JobFairMonth._(this.year, this.month);

  factory JobFairMonth.fromInstant(DateTime instant) {
    final date = jobFairBeijingTime(instant);
    return JobFairMonth(date.year, date.month);
  }

  final int year;
  final int month;

  /// Calendar fields, not the instant at which this month begins.
  DateTime get calendarDate => DateTime.utc(year, month);

  String get apiValue =>
      '${year.toString().padLeft(4, '0')}/${month.toString().padLeft(2, '0')}';

  JobFairMonth shift(int months) {
    final date = DateTime.utc(year, month + months);
    return JobFairMonth(date.year, date.month);
  }

  bool contains(DateTime instant) {
    final date = jobFairBeijingTime(instant);
    return date.year == year && date.month == month;
  }

  @override
  bool operator ==(Object other) =>
      other is JobFairMonth && year == other.year && month == other.month;

  @override
  int get hashCode => Object.hash(year, month);
}

enum JobFairType { recruitment, careerTalk }

class JobFair {
  const JobFair({
    required this.id,
    required this.title,
    required this.place,
    required this.startsAt,
    required this.type,
  });

  factory JobFair.fromJson(Map<String, dynamic> json) {
    final id = _sourceString(json['id']).trim();
    if (!_validId(id)) throw const FormatException('招聘活动标识无效');
    return JobFair(
      id: id,
      title: _sourceString(json['title']).trim(),
      place: _sourceString(json['place']).trim(),
      startsAt: _parseStart(
        _sourceString(json['start_time']).trim(),
        _sourceString(json['time']).trim(),
      ),
      type: _sourceString(json['zphval']).trim() == '3'
          ? JobFairType.careerTalk
          : JobFairType.recruitment,
    );
  }

  static const officialHost = 'fjrclh.fzu.edu.cn';
  static const _detailPaths = {'/cms/zphdetail.html', '/cms/xjhdetail.html'};

  final String id;
  final String title;
  final String place;

  /// Absolute instant; source timestamps are interpreted as UTC+8.
  final DateTime startsAt;
  final JobFairType type;

  DateTime get beijingStart => jobFairBeijingTime(startsAt);

  bool isUpcomingAt(DateTime now) => startsAt.isAfter(now);

  Uri? get detailUri {
    if (!_validId(id)) return null;
    return Uri(
      scheme: 'http',
      host: officialHost,
      path: type == JobFairType.careerTalk
          ? '/cms/xjhdetail.html'
          : '/cms/zphdetail.html',
      queryParameters: {'id': id},
    );
  }

  /// Only the official details pages with one opaque ID may be opened.
  static bool isOfficialDetailUri(Uri uri) {
    if (!{'http', 'https'}.contains(uri.scheme) ||
        uri.host != officialHost ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !_detailPaths.contains(uri.path)) {
      return false;
    }
    try {
      final query = uri.queryParametersAll;
      final ids = query['id'];
      return query.length == 1 &&
          ids != null &&
          ids.length == 1 &&
          _validId(ids.single);
    } on FormatException {
      return false;
    }
  }

  static bool _validId(String id) =>
      id.trim().isNotEmpty &&
      id.length <= 512 &&
      !id.contains(RegExp(r'[\x00-\x1f\x7f]'));

  static String _sourceString(Object? value) => switch (value) {
    null => '',
    String value => value,
    int value => value.toString(),
    _ => throw const FormatException('招聘活动字段格式无效'),
  };

  static DateTime _parseStart(String date, String time) {
    final day = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(date);
    final clock = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(time);
    if (day == null || clock == null) {
      throw const FormatException('招聘活动开始时间无效');
    }
    final year = int.parse(day.group(1)!);
    final month = int.parse(day.group(2)!);
    final dateOfMonth = int.parse(day.group(3)!);
    final hour = int.parse(clock.group(1)!);
    final minute = int.parse(clock.group(2)!);
    final second = int.parse(clock.group(3) ?? '0');
    final calendar = DateTime.utc(
      year,
      month,
      dateOfMonth,
      hour,
      minute,
      second,
    );
    // DateTime normalizes impossible dates; reject them instead of moving events.
    if (year < 1 ||
        calendar.year != year ||
        calendar.month != month ||
        calendar.day != dateOfMonth ||
        calendar.hour != hour ||
        calendar.minute != minute ||
        calendar.second != second) {
      throw const FormatException('招聘活动开始时间无效');
    }
    return calendar.subtract(const Duration(hours: 8));
  }
}

class JobFairMonthData {
  JobFairMonthData({
    required this.month,
    required List<JobFair> events,
    this.skippedCount = 0,
  }) : events = List.unmodifiable(events);

  final JobFairMonth month;
  final List<JobFair> events;
  final int skippedCount;

  /// The source has no end time: past means already started, not ended.
  ({List<JobFair> upcoming, List<JobFair> past}) groupsAt(DateTime now) {
    final upcoming = <JobFair>[];
    final past = <JobFair>[];
    for (final event in events) {
      (event.isUpcomingAt(now) ? upcoming : past).add(event);
    }
    int compare(JobFair a, JobFair b) {
      final byStart = a.startsAt.compareTo(b.startsAt);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    }

    upcoming.sort(compare);
    past.sort((a, b) => compare(b, a));
    return (upcoming: upcoming, past: past);
  }
}
