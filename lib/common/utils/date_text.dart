class DateText {
  static final _chineseDatePattern = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日');

  DateText._();

  static DateTime? parseChineseDate(String value) {
    final match = _chineseDatePattern.firstMatch(value);
    if (match == null) return null;

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static DateTime parseChineseDateOrEpoch(String value) {
    return parseChineseDate(value) ?? DateTime(1970);
  }
}
