/// 课程时间段常量（1-based index，period 1 = 第 0 项）
const timeSlots = [
  ('8:20', '9:05'),
  ('9:15', '10:00'),
  ('10:20', '11:05'),
  ('11:15', '12:00'),
  ('14:00', '14:45'),
  ('14:55', '15:40'),
  ('15:50', '16:35'),
  ('16:45', '17:30'),
  ('19:00', '19:45'),
  ('19:55', '20:40'),
  ('20:50', '21:35'),
];

/// 将 period（1-based）解析为 [hour, minute]
(List<int>, int) parsePeriodTime(int period, {required bool isEnd}) {
  final slot = timeSlots[period - 1];
  final time = isEnd ? slot.$2 : slot.$1;
  final parts = time.split(':');
  return ([int.parse(parts[0]), int.parse(parts[1])], period);
}
