enum AcademicChangeType {
  gradeAdded,
  gradeChanged,
  examAdded,
  examChanged,
  examRemoved;

  bool get isExam => index >= AcademicChangeType.examAdded.index;
}

class AcademicChange {
  const AcademicChange({
    required this.id,
    required this.type,
    required this.course,
    required this.term,
    required this.before,
    required this.after,
    required this.detectedAt,
    this.read = false,
  });
  final String id;
  final AcademicChangeType type;
  final String course, term, before, after;
  final DateTime detectedAt;
  final bool read;

  AcademicChange markRead() => AcademicChange(
    id: id,
    type: type,
    course: course,
    term: term,
    before: before,
    after: after,
    detectedAt: detectedAt,
    read: true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'course': course,
    'term': term,
    'before': before,
    'after': after,
    'detectedAt': detectedAt.toUtc().toIso8601String(),
    'read': read,
  };
  factory AcademicChange.fromJson(Map<String, dynamic> json) => AcademicChange(
    id: json['id'] as String,
    type: AcademicChangeType.values.byName(json['type'] as String),
    course: json['course'] as String,
    term: json['term'] as String,
    before: json['before'] as String,
    after: json['after'] as String,
    detectedAt: DateTime.parse(json['detectedAt'] as String),
    read: json['read'] == true,
  );
}
