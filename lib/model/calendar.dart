class CalTerm {
  final String termId;
  final String schoolYear;
  final String term;
  final String startDate;
  final String endDate;

  const CalTerm({
    required this.termId,
    required this.schoolYear,
    required this.term,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toJson() => {
    'termId': termId,
    'schoolYear': schoolYear,
    'term': term,
    'startDate': startDate,
    'endDate': endDate,
  };

  factory CalTerm.fromJson(Map<String, dynamic> json) => CalTerm(
    termId: json['termId'] as String,
    schoolYear: json['schoolYear'] as String,
    term: json['term'] as String,
    startDate: json['startDate'] as String,
    endDate: json['endDate'] as String,
  );
}

class CalTermEvent {
  final String name;
  final String startDate;
  final String endDate;

  const CalTermEvent({
    required this.name,
    required this.startDate,
    required this.endDate,
  });
}

class CalTermEvents {
  final String termId;
  final List<CalTermEvent> events;

  const CalTermEvents({required this.termId, required this.events});
}

class SchoolCalendar {
  final String currentTerm;
  final List<CalTerm> terms;

  const SchoolCalendar({required this.currentTerm, required this.terms});

  Map<String, dynamic> toJson() => {
    'currentTerm': currentTerm,
    'terms': terms.map((t) => t.toJson()).toList(),
  };

  factory SchoolCalendar.fromJson(Map<String, dynamic> json) => SchoolCalendar(
    currentTerm: json['currentTerm'] as String,
    terms: (json['terms'] as List).map((t) => CalTerm.fromJson(t)).toList(),
  );
}
