class Mark {
  final String type;          // 修读类别
  final String semester;      // 开课学期
  final String name;          // 课程名称
  final String credits;       // 计划学分
  final String score;         // 得分
  final String gpa;           // 绩点
  final String earnedCredits; // 得到学分
  final String electiveType;  // 选课类型
  final String examType;      // 考试类别
  final String teacher;       // 任课教师
  final String classroom;     // 上课时间地点
  final String examTime;      // 考试时间地点

  const Mark({
    required this.type,
    required this.semester,
    required this.name,
    required this.credits,
    required this.score,
    required this.gpa,
    required this.earnedCredits,
    required this.electiveType,
    required this.examType,
    required this.teacher,
    required this.classroom,
    required this.examTime,
  });
}
