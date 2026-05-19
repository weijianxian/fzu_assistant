class ExamRoomInfo {
  final String courseName;
  final String credit;
  final String teacher;
  final String date; // 2024年11月17日
  final String time; // 12:30-17:30
  final String location; // 旗山数计3-404

  const ExamRoomInfo({
    required this.courseName,
    required this.credit,
    required this.teacher,
    required this.date,
    required this.time,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
    'courseName': courseName,
    'credit': credit,
    'teacher': teacher,
    'date': date,
    'time': time,
    'location': location,
  };

  factory ExamRoomInfo.fromJson(Map<String, dynamic> json) => ExamRoomInfo(
    courseName: json['courseName'] ?? '',
    credit: json['credit'] ?? '',
    teacher: json['teacher'] ?? '',
    date: json['date'] ?? '',
    time: json['time'] ?? '',
    location: json['location'] ?? '',
  );
}
