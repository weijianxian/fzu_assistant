class ClassroomOccupancy {
  const ClassroomOccupancy({
    required this.start,
    required this.end,
    required this.event,
    required this.occupant,
  });

  final int start, end;
  final String event, occupant;
}

class ClassroomUsage {
  const ClassroomUsage({
    required this.name,
    required this.capacity,
    required this.type,
    required this.occupancies,
  });

  final String name, capacity, type;
  final List<ClassroomOccupancy> occupancies;

  bool occupied(int section) =>
      occupancies.any((item) => item.start <= section && section <= item.end);
}

class ClassroomChoice {
  const ClassroomChoice(this.value, this.label);
  final String value, label;
}
