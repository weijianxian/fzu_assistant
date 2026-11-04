/// A lecture registered by the current academic account.
class Lecture {
  const Lecture({
    required this.category,
    required this.issueNumber,
    required this.title,
    required this.speaker,
    required this.startTime,
    required this.rawDateTime,
    required this.location,
    required this.attendanceStatus,
  });

  final String category;
  final int? issueNumber;
  final String title;
  final String speaker;

  /// UTC instant parsed from the official page's Beijing wall clock.
  /// Null means the page did not supply a valid date; retain [rawDateTime].
  final DateTime? startTime;
  final String rawDateTime;
  final String location;
  final String attendanceStatus;

  /// Beijing wall-clock components, independent of the device's time zone.
  DateTime? get beijingStartTime =>
      startTime?.toUtc().add(const Duration(hours: 8));
}
