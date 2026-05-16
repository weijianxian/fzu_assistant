// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'FZU Assistant';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get navToolbox => 'Tools';

  @override
  String get navMy => 'Profile';

  @override
  String get retry => 'Retry';

  @override
  String loadingFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String get noData => 'No data';

  @override
  String dataUpdatedAt(String time) {
    return 'Updated at $time';
  }

  @override
  String get studentId => 'Student ID';

  @override
  String get password => 'Password';

  @override
  String get captcha => 'Captcha';

  @override
  String get getCaptcha => 'Get captcha';

  @override
  String get login => 'Login';

  @override
  String get loginValidationError =>
      'Please enter student ID, password and captcha';

  @override
  String captchaFetchFailed(String error) {
    return 'Failed to get captcha: $error';
  }

  @override
  String weekN(int week) {
    return 'Week $week';
  }

  @override
  String get thisWeek => 'This week';

  @override
  String get noScheduleData => 'No schedule data';

  @override
  String get monday => 'Mon';

  @override
  String get tuesday => 'Tue';

  @override
  String get wednesday => 'Wed';

  @override
  String get thursday => 'Thu';

  @override
  String get friday => 'Fri';

  @override
  String get saturday => 'Sat';

  @override
  String get sunday => 'Sun';

  @override
  String get college => 'College';

  @override
  String get major => 'Major';

  @override
  String get grade => 'Grade';

  @override
  String get calendar => 'Calendar';

  @override
  String get themeSettings => 'Theme';

  @override
  String get about => 'About';

  @override
  String get logout => 'Log out';

  @override
  String get language => 'Language';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get academics => 'Academics';

  @override
  String get gpaInfo => 'GPA';

  @override
  String get gpaInfoSubtitle => 'View GPA ranking data';

  @override
  String get marksQuery => 'Grades';

  @override
  String get marksQuerySubtitle => 'View all course grades';

  @override
  String get unifiedExam => 'Exam Scores';

  @override
  String get unifiedExamSubtitle => 'CET / Provincial Computer Exam';

  @override
  String get examRoom => 'Exam Rooms';

  @override
  String get examRoomSubtitle => 'View exam schedule and room info';

  @override
  String get creditStats => 'Credits';

  @override
  String get creditStatsSubtitle => 'View credit completion progress';

  @override
  String get noGpaData => 'No GPA data';

  @override
  String get dataParseError => 'Data parse error';

  @override
  String get noMarksData => 'No grade data';

  @override
  String get unknownSemester => 'Unknown semester';

  @override
  String courseCount(int count) {
    return '$count courses';
  }

  @override
  String creditsTag(String credits) {
    return 'Credits $credits';
  }

  @override
  String gpaTag(String gpa) {
    return 'GPA $gpa';
  }

  @override
  String get noUnifiedExamData => 'No exam scores';

  @override
  String get cetScores => 'CET Scores';

  @override
  String get provincialComputerScores => 'Provincial Computer Exam';

  @override
  String get noExamRoomInfo => 'No exam room info';

  @override
  String get examTaken => 'Taken';

  @override
  String creditSuffix(String credit) {
    return '$credit credits';
  }

  @override
  String get noCreditData => 'No credit data';

  @override
  String get appearance => 'Appearance';

  @override
  String get followSystem => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get themeColor => 'Theme Color';

  @override
  String get themeDeepPurple => 'Deep Purple';

  @override
  String get themeBlue => 'Blue';

  @override
  String get themeTeal => 'Teal';

  @override
  String get themeGreen => 'Green';

  @override
  String get themeOrange => 'Orange';

  @override
  String get themeRed => 'Red';

  @override
  String get themePink => 'Pink';

  @override
  String get themeIndigo => 'Indigo';

  @override
  String get themeBrown => 'Brown';

  @override
  String get devTools => 'Dev Tools';

  @override
  String get collapse => 'Collapse';

  @override
  String get expandAll => 'Expand all';

  @override
  String get noCalendarData => 'No calendar data';

  @override
  String academicYearTerm(String startYear, String endYear, String term) {
    return '$startYear-$endYear  Term $term';
  }

  @override
  String get current => 'Current';

  @override
  String get noScheduleEvents => 'No events';

  @override
  String get appDescription =>
      'Fuzhou University all-in-one campus assistant — schedule, grades, exams, calendar, out of the box.';

  @override
  String get openSourceUrl => 'Source Code';

  @override
  String get contributors => 'Contributors';

  @override
  String commitCount(int count) {
    return '$count commits';
  }
}
