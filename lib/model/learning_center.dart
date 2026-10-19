/// Beijing calendar fields; use only for date/time display and calendar selection.
DateTime learningBeijingTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));

/// Server timestamps without an offset are always Beijing time.
DateTime? parseLearningDateTime(String value) => DateTime.tryParse(
  RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(value)
      ? value
      : '$value+08:00',
);

String learningSeatName(String name) => switch (name) {
  '796-1' => '797',
  '799-1' => '800',
  _ => name,
};

class LearningSeat {
  const LearningSeat({
    required this.id,
    required this.name,
    required this.floor,
    required this.status,
  });
  final String id;
  final String name;
  final String floor;
  final int status;
  bool get available => status == 0;
  factory LearningSeat.fromJson(Map<String, dynamic> json) => LearningSeat(
    id: '${json['id'] ?? ''}',
    name: learningSeatName('${json['spaceName'] ?? ''}'),
    floor: '${json['floor'] ?? ''}',
    status: int.tryParse('${json['spaceStatus']}') ?? -1,
  );
}

enum LearningAppointmentStatus {
  upcoming,
  pending,
  signedIn,
  missed,
  cancelled,
  completed,
  unknown,
}

class LearningAppointment {
  LearningAppointment.fromJson(Map<String, dynamic> json)
    : id = '${json['id'] ?? ''}',
      seatName = learningSeatName('${json['spaceName'] ?? ''}'),
      floor = '${json['floor'] ?? ''}',
      date = '${json['date'] ?? ''}'.split('T').first.split(' ').first,
      beginTime = '${json['beginTime'] ?? ''}',
      endTime = '${json['endTime'] ?? ''}',
      auditStatus = int.tryParse('${json['auditStatus']}') ?? 0,
      signedIn =
          json['sign'] == true || json['sign'] == 1 || json['sign'] == 'true';
  final String id, seatName, floor, date, beginTime, endTime;
  final int auditStatus;
  final bool signedIn;

  DateTime? _dateTime(String time) => parseLearningDateTime(
    time.contains('T') || time.contains(' ') ? time : '${date}T$time',
  );

  /// Newest appointment first; malformed timestamps stay at the bottom.
  static int compareNewestFirst(LearningAppointment a, LearningAppointment b) {
    final startA = a._dateTime(a.beginTime);
    final startB = b._dateTime(b.beginTime);
    if (startA == null && startB != null) return 1;
    if (startA != null && startB == null) return -1;
    final byStart = startA == null ? 0 : startB!.compareTo(startA);
    if (byStart != 0) return byStart;
    return b.id.compareTo(a.id);
  }

  LearningAppointmentStatus statusAt(DateTime now) {
    if (auditStatus == 3) return LearningAppointmentStatus.cancelled;
    if (auditStatus == 4) return LearningAppointmentStatus.completed;
    if (auditStatus != 2) return LearningAppointmentStatus.unknown;
    if (signedIn) return LearningAppointmentStatus.signedIn;
    final begin = _dateTime(beginTime);
    final end = _dateTime(endTime);
    if (begin == null || end == null) return LearningAppointmentStatus.unknown;
    if (now.isBefore(begin.subtract(const Duration(minutes: 15)))) {
      return LearningAppointmentStatus.upcoming;
    }
    if (!now.isBefore(end)) return LearningAppointmentStatus.missed;
    return LearningAppointmentStatus.pending;
  }
}

class LearningTimeSlot {
  LearningTimeSlot.fromJson(Map<String, dynamic> json)
    : text = '${json['timeText'] ?? ''}',
      available = '${json['occupy']}' == '0';
  final String text;
  final bool available;
}

/// Only accept the current on-site QR code, as in the reference client.
bool validLearningQrCode(String raw, DateTime now) {
  final parts = raw.split('@');
  if (parts.length != 3 || parts[0] != 'seatSignInCode') return false;
  final begin = parseLearningDateTime(parts[1]);
  final end = parseLearningDateTime(parts[2]);
  if (begin == null || end == null) return false;
  final seconds = end.difference(begin).inSeconds;
  return seconds >= 54 &&
      seconds <= 66 &&
      !now.isBefore(begin) &&
      !now.isAfter(end);
}

String learningDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Shared by the reservation UI and the API debug page.
void validateLearningPeriod(
  String date,
  String begin,
  String end, {
  DateTime? now,
}) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
      !RegExp(r'^(0[89]|1\d|2[0-2]):(00|30)$').hasMatch(begin) ||
      !RegExp(r'^(0[89]|1\d|2[0-2]):(00|30)$').hasMatch(end)) {
    throw Exception('请选择有效日期及 08:00–22:30 的整点或半点');
  }
  final start = parseLearningDateTime('${date}T$begin');
  final finish = parseLearningDateTime('${date}T$end');
  if (start == null ||
      finish == null ||
      learningDate(learningBeijingTime(start)) != date ||
      !finish.isAfter(start) ||
      finish.difference(start) > const Duration(hours: 4)) {
    throw Exception('预约结束时间须晚于开始时间，且不超过 4 小时');
  }
  final current = now ?? DateTime.now();
  final beijing = learningBeijingTime(current);
  final today = DateTime.utc(
    beijing.year,
    beijing.month,
    beijing.day,
  ).subtract(const Duration(hours: 8));
  if (!start.isAfter(current) ||
      !start.isBefore(today.add(const Duration(days: 7)))) {
    throw Exception('请选择未来七天内尚未开始的时段');
  }
}
