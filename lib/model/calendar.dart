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

  const SchoolCalendar({
    required this.currentTerm,
    required this.terms,
  });
}
