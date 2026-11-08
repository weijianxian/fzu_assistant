// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get webdavSchemaVersion => 'Data schema version';

  @override
  String get webdavAppVersion => 'App version that created the backup';

  @override
  String get webdavAppVersionUnknown => 'Not recorded in this backup';

  @override
  String get webdavHistory => 'Snapshot history';

  @override
  String get webdavHistoryDescription =>
      'Browse sync snapshots, preview one and restore it to this device';

  @override
  String get webdavHistoryEmpty => 'No snapshots yet';

  @override
  String get webdavHistoryRestore => 'Restore this snapshot';

  @override
  String get webdavHistoryRestoreDescription =>
      'Restore local settings and every account’s course records from this snapshot? A local recovery point will be saved first. The current remote sync file stays as it is; upload manually to publish the restored data.';

  @override
  String get webdavLocalRecovery => 'Local recovery point';

  @override
  String get webdavLocalRecoveryDescription =>
      'Local settings and course records saved before the last restore';

  @override
  String get webdavHistorySaved => 'Saved sync snapshot';

  @override
  String get webdavHistoryPrevious =>
      'Remote snapshot saved before replacement';

  @override
  String get webdavHistoryRecordedAt => 'Snapshot saved';

  @override
  String get windowsNotifications => 'Course notifications';

  @override
  String get windowsNotificationsDescription =>
      'Tomorrow’s courses, classes, next classes and session endings';

  @override
  String get windowsNotificationsHelp =>
      'Keep the app running to receive reminders; enable “Keep running after closing the window” for tray delivery. Exiting stops reminders';

  @override
  String get windowsNotificationsSystemHint =>
      'Windows notification settings and Do not disturb control banners and sounds';

  @override
  String get windowsCourseStages => 'Course stage reminders';

  @override
  String get windowsCourseStagesDescription =>
      'Remind five minutes before class, at class start, between classes and when the session ends';

  @override
  String get windowsNotificationsSystemSettings =>
      'Windows notification settings';

  @override
  String get windowsNotificationsRefresh => 'Refresh reminder plans';

  @override
  String get windowsNotificationsNext => 'Next tomorrow-course reminder';

  @override
  String get windowsBackground => 'Background activity';

  @override
  String get windowsBackgroundDescription =>
      'Keep running in the tray, restore the window or quit';

  @override
  String get windowsBackgroundCloseToTray =>
      'Keep running after closing the window';

  @override
  String get windowsBackgroundCloseToTrayDescription =>
      'Keep the tray icon and course notifications active';

  @override
  String get windowsBackgroundHelp =>
      'Click the tray icon to restore the window, or right-click it to show the window or quit';

  @override
  String get windowsBackgroundReady =>
      'Tray ready; closing the window keeps the app running';

  @override
  String get windowsBackgroundDisabled => 'Closing the window quits the app';

  @override
  String get windowsBackgroundFailed =>
      'The tray or settings are unavailable; the window stays visible and closing it quits the app';

  @override
  String get windowsBackgroundUnsupported =>
      'The background tray is only available on Windows';

  @override
  String get windowsBackgroundRestore => 'Show window';

  @override
  String get windowsBackgroundExit => 'Quit';

  @override
  String get settingsAppSection => 'Application';

  @override
  String get settingsPlatformSection => 'Platform features';

  @override
  String get settingsCoursesSection => 'Courses';

  @override
  String get settingsSemesterSection => 'Semester';

  @override
  String get settingsDisplaySection => 'Display';

  @override
  String get settingsGeneralSection => 'General';

  @override
  String get settingsSyncSection => 'Sync settings';

  @override
  String get settingsSyncStatusSection => 'Sync status';

  @override
  String get settingsDataSection => 'Data management';

  @override
  String get settingsConnectionSection => 'Connection';

  @override
  String get settingsPermissionsSection => 'System permissions';

  @override
  String get settingsRefreshSection => 'Timetable updates';

  @override
  String get settingsAutoSyncSection => 'Automatic sync';

  @override
  String get settingsManualSyncSection => 'Manual sync';

  @override
  String get settingsExportSection => 'Export settings';

  @override
  String get settingsReminderSection => 'Reminder settings';

  @override
  String get scheduleSync => 'Nightly timetable updates';

  @override
  String get scheduleSyncDescription =>
      'Update your timetable, home screen widgets and system calendar when calendar sync is on';

  @override
  String get scheduleSyncAutomaticDescription =>
      'Update your timetable and widgets daily, plus the calendar if sync is enabled';

  @override
  String get scheduleSyncAlarmPurpose =>
      'Required for automatic sync; manual sync works without it';

  @override
  String get scheduleSyncUpdated =>
      'Timetable and widgets updated, including the system calendar when sync is on.';

  @override
  String get scheduleSyncUnsupported =>
      'Nightly timetable updates are only available on Android.';

  @override
  String get hiddenCourseManagement => 'Hidden course management';

  @override
  String get customCourseManagement => 'Custom course management';

  @override
  String get academicCachedSession =>
      'The academic connection failed, so cached data is shown until you reconnect.';

  @override
  String get accountManagement => 'Accounts';

  @override
  String get accountAcademic => 'Academic affairs';

  @override
  String get accountSso => 'Single sign-on (SSO)';

  @override
  String get accountSignedOut => 'Signed out';

  @override
  String get accountSsoDescription =>
      'Manage SSO, campus codes and learning center sessions';

  @override
  String get accountAcademicLogoutDescription =>
      'Sign out of academic affairs and clear this account\'s SSO, campus code and learning center sessions.';

  @override
  String get campusSwipeHint => 'Swipe up or down to switch codes';

  @override
  String get campusCode => 'Campus code';

  @override
  String get campusPayCode => 'Payment';

  @override
  String get campusLibraryCode => 'Library';

  @override
  String get campusLibraryCodeHint =>
      'Scan the QR code or barcode at the library entrance.';

  @override
  String get appName => 'FZU Assistant';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get navToolbox => 'Tools';

  @override
  String get toolboxEmptyRoomTitle => 'Empty rooms';

  @override
  String get toolboxJobFairTitle => 'Job fairs';

  @override
  String get toolboxClassroomUsageTitle => 'Room usage';

  @override
  String get toolboxAcademicShortcutsTitle => 'Academics';

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
  String get themeSettings => 'Appearance';

  @override
  String get themeSettingsSubtitle =>
      'Interface style, light/dark mode and custom themes';

  @override
  String get settings => 'Settings';

  @override
  String get homeSettings => 'Timetable settings';

  @override
  String get homeSettingsSubtitle =>
      'Manage semesters, timetable display and custom courses';

  @override
  String get generalSettings => 'General Settings';

  @override
  String get generalSettingsSubtitle => 'Language and web enhancement';

  @override
  String get advancedSettings => 'Advanced Settings';

  @override
  String get advancedSettingsSubtitle => 'GitHub download proxy settings';

  @override
  String get githubProxy => 'GitHub Proxy';

  @override
  String get githubProxyEnabled => 'Enable GitHub Proxy';

  @override
  String get githubProxyDescription =>
      'Update packages and GitHub resource downloads use the proxy';

  @override
  String get githubProxyBaseUrl => 'Proxy URL';

  @override
  String get githubProxyBaseUrlDescription =>
      'Enter a GitHub download proxy such as https://gh-proxy.org/.';

  @override
  String get webEnhancement => 'Web Enhancement';

  @override
  String get siteInjection => 'Inject Web Styles';

  @override
  String get siteInjectionDescription =>
      'Improve page layout and readability in the in-app browser';

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
  String get gradesAndCredits => 'Grades & Credits';

  @override
  String get examsAndRooms => 'Exams & Rooms';

  @override
  String get campusInfo => 'Campus Info';

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
  String get interfaceStyle => 'Interface style';

  @override
  String get interfaceStyleClassic => 'Classic list';

  @override
  String get interfaceStyleClassicDescription => 'A simple, compact list';

  @override
  String get interfaceStyleCards => 'Card groups';

  @override
  String get interfaceStyleCardsDescription =>
      'Related settings grouped with small gaps between rows';

  @override
  String get interfaceStyleContinuousCards => 'Continuous cards';

  @override
  String get interfaceStyleContinuousCardsDescription =>
      'One card per group, with no gaps or dividers between rows';

  @override
  String get themeDynamic => 'Dynamic Color';

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

  @override
  String get emptyClassroom => 'Empty Rooms';

  @override
  String get emptyClassroomSubtitle => 'Find available classrooms';

  @override
  String get noEmptyRoomData => 'No available rooms';

  @override
  String get selectDate => 'Select date';

  @override
  String get selectCampus => 'Select campus';

  @override
  String get startPeriod => 'Start period';

  @override
  String get endPeriod => 'End period';

  @override
  String get query => 'Search';

  @override
  String get officeNotice => 'Office Notices';

  @override
  String get officeNoticeSubtitle => 'View academic office notices';

  @override
  String get noNoticeData => 'No notices';

  @override
  String pageN(int page) {
    return 'Page $page';
  }

  @override
  String totalPages(int total) {
    return '$total pages total';
  }

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get webView => 'Web View';

  @override
  String get sslWarning =>
      'SSL certificate verification bypassed, please stay alert';

  @override
  String get refresh => 'Refresh';

  @override
  String get reset => 'Reset';

  @override
  String get copyLink => 'Copy Link';

  @override
  String get copied => 'Copied';

  @override
  String get clearCookies => 'Clear Cookies';

  @override
  String get selectSemester => 'Select semester';

  @override
  String get autoSemester => 'Auto (current semester)';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get newVersionAvailable => 'New Version Available';

  @override
  String get releaseNotes => 'Release Notes';

  @override
  String get skipThisVersion => 'Skip This Version';

  @override
  String get skipUpdatesPermanently => 'Skip Permanently';

  @override
  String get downloadUpdate => 'Download';

  @override
  String get installUpdate => 'Download & Install';

  @override
  String get updateNoCompatiblePackage =>
      'No compatible package was found, so the download page will open.';

  @override
  String get updateInstallPermissionRequired =>
      'Allow installing unknown apps, then tap Download & Install again.';

  @override
  String get updateDownloadFailed => 'Failed to download update';

  @override
  String get updateInstallFailed => 'Failed to open installer';

  @override
  String get updateOpeningInstaller => 'Opening installer';

  @override
  String get alreadyLatest => 'You are on the latest version';

  @override
  String get updateCheckFailed => 'Failed to check for updates';

  @override
  String get showExamOnSchedule => 'Show exams on schedule';

  @override
  String get showExamOnScheduleDescription =>
      'Show exam arrangements on their corresponding schedule dates';

  @override
  String get west2AdjustmentsEnabled => 'Get course adjustments from west2';

  @override
  String get west2AdjustmentsDescription =>
      'Get university-wide adjustments from west2 online and confirm them against official notices';

  @override
  String get autoAdjustCourse => 'Auto adjust courses';

  @override
  String get autoAdjustCourseDescription =>
      'Adjust the timetable using official course change records';

  @override
  String get evaluation => 'One-Key Evaluation';

  @override
  String get evaluationSubtitle => 'Batch evaluate your teachers';

  @override
  String get noEvaluationData => 'No courses to evaluate';

  @override
  String get evalTabXqxk => 'Course Selection';

  @override
  String get evalTabScore => 'Grade Query';

  @override
  String get evalScoreHint => 'Score (0-100)';

  @override
  String get evalSelectComment => 'Select comment';

  @override
  String get evalCustomComment => 'Custom';

  @override
  String get evalCustomHint => 'Write your own comment';

  @override
  String get evalSubmit => 'Submit';

  @override
  String get evalSubmitAll => 'Submit All';

  @override
  String get evalFillCaptcha => 'Enter Captcha';

  @override
  String get evalCaptchaRequired => 'Captcha cannot be empty';

  @override
  String get evalCaptchaError => 'Incorrect captcha';

  @override
  String get evalSuccess => 'Evaluation submitted!';

  @override
  String evalScoreRequired(String course) {
    return 'Score not filled for $course';
  }

  @override
  String evalCommentRequired(String course) {
    return 'Comment not filled for $course';
  }

  @override
  String get evalRefreshCaptcha => 'Refresh captcha';

  @override
  String get evalNotAvailable => 'There are no courses awaiting evaluation.';

  @override
  String get evalNoFilled => 'Please fill in evaluation content first';

  @override
  String evalSubmitFailed(String error) {
    return 'Evaluation failed: $error';
  }

  @override
  String classPeriod(int period) {
    return 'Period $period';
  }

  @override
  String classPeriodRange(int start, int end) {
    return 'Periods $start-$end';
  }

  @override
  String get adjustedMark => '[Adjusted] ';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore window';

  @override
  String get windowClose => 'Close window';

  @override
  String get profileInfo => 'Profile';

  @override
  String get scheduleMorning => 'Morning';

  @override
  String get scheduleAfternoon => 'Afternoon';

  @override
  String get scheduleEvening => 'Evening';

  @override
  String get scheduleExamMark => '[Exam] ';

  @override
  String get schedulePreviousWeek => 'Previous week';

  @override
  String get scheduleNextWeek => 'Next week';

  @override
  String get showNonCurrentWeekCourses => 'Show courses from other weeks';

  @override
  String get showNonCurrentWeekCoursesDescription =>
      'Show faded courses from other weeks in free timetable slots';

  @override
  String get nonCurrentWeekMark => '[Other week]';

  @override
  String get academicShortcuts => 'Academic shortcuts';

  @override
  String get academicShortcutsSubtitle =>
      'Course selection, applications and Jiaxi lectures';

  @override
  String get courseSelection => 'Course selection';

  @override
  String get campusElectiveSelection => 'University electives';

  @override
  String get retakeSelection => 'Retake courses';

  @override
  String get minorSelection => 'Minor courses';

  @override
  String get academicApplications => 'Academic applications';

  @override
  String get majorTransferApplication => 'Change major';

  @override
  String get examDeferralApplication => 'Defer an exam';

  @override
  String get courseExemptionApplication => 'Course exemption';

  @override
  String get minorApplication => 'Apply for a minor';

  @override
  String get classroomApplication => 'Request a classroom';

  @override
  String get creditRecognition => 'Credit recognition';

  @override
  String get majorAllocation => 'Major allocation';

  @override
  String get electiveCreditConversion => 'Convert elective credits';

  @override
  String get jiaxiLectures => 'Jiaxi lectures';

  @override
  String get skipCourseSession => 'I don\'t want to attend';

  @override
  String get skipCourseSessionDescription =>
      'Hide this session for the current week and restore it in Timetable settings.';

  @override
  String get hiddenCourseSessions => 'Hidden classes';

  @override
  String get hiddenCourseSessionsDescription =>
      'Restore individual sessions hidden from the timetable';

  @override
  String get noHiddenCourseSessions => 'No hidden classes';

  @override
  String get restoreCourseSession => 'Show class again';

  @override
  String get restoreAllCourseSessions => 'Restore all';

  @override
  String get learningCenter => 'Learning center';

  @override
  String get ssoLogin => 'SSO login';

  @override
  String get ssoLoginDescription =>
      'Sign in to campus services with your separate SSO account without saving its password.';

  @override
  String get ssoSmsVerification => 'SMS verification';

  @override
  String get ssoSendSms => 'Send code';

  @override
  String get ssoSmsSent => 'Code sent';

  @override
  String get ssoLogout => 'Sign out of SSO';

  @override
  String get ssoLogoutDescription =>
      'Sign out of SSO, campus codes and the learning center while keeping your academic session.';

  @override
  String get ssoSessionExpired => 'Sign in again to continue.';

  @override
  String get learningReserve => 'Reserve a seat';

  @override
  String get learningReserveSubtitle =>
      'Find available seats and reserve study time';

  @override
  String get learningAppointments => 'My reservations';

  @override
  String get learningInstructions =>
      'Reserve a seat on floors 4–5 of Jinjiang Building, scan to check in and check out before leaving.';

  @override
  String get learningCancel => 'Cancel';

  @override
  String get learningConfirm => 'Confirm';

  @override
  String get learningSelectPeriod =>
      'Choose date, time and floor (08:00–22:30, up to 4 hours)';

  @override
  String get learningBegin => 'Start time';

  @override
  String get learningEnd => 'End time';

  @override
  String learningFloor(String floor) {
    return 'Floor $floor';
  }

  @override
  String learningSeatLabel(String floor, String seat) {
    return 'Floor $floor · Seat $seat';
  }

  @override
  String get learningAvailable => 'Available';

  @override
  String get learningOccupied => 'Occupied';

  @override
  String get learningSeatTimes => 'Daily seat availability';

  @override
  String get learningReserved => 'View your reservation and check in on time.';

  @override
  String get learningSeatList => 'Seats';

  @override
  String learningSeatArea(String area) {
    return 'Area $area';
  }

  @override
  String get learningOtherArea => 'Other';

  @override
  String get learningSeatGuide => 'Seat guide';

  @override
  String get learningSingleSeat => 'Single seats';

  @override
  String get learningSharedSeat => 'Shared seats';

  @override
  String get learningSofaSeat => 'Sofa seats';

  @override
  String get learningSharedAndSofaSeat => 'Shared and sofa seats';

  @override
  String learningAreaSummary(int available, int occupied) {
    return 'Available $available · Occupied $occupied';
  }

  @override
  String get learningNoSeats => 'Try another time to find available seats.';

  @override
  String get learningSeatLegend =>
      'Select an available seat or tap an occupied one for its daily availability.';

  @override
  String get learningSignOut => 'Check out';

  @override
  String get learningCancelAppointment => 'Cancel reservation';

  @override
  String get learningActionSucceeded => 'Operation succeeded';

  @override
  String get learningUpcoming => 'Upcoming';

  @override
  String get learningPending => 'Awaiting check-in';

  @override
  String get learningSignedIn => 'Checked in';

  @override
  String get learningMissed => 'Missed check-in';

  @override
  String get learningCancelled => 'Cancelled';

  @override
  String get learningCompleted => 'Completed';

  @override
  String get learningUnknown => 'Unknown';

  @override
  String learningAppointmentTitle(String floor, String seat) {
    return 'Floor $floor · $seat';
  }

  @override
  String get learningNoAppointments => 'No reservations';

  @override
  String get learningLoadMore => 'Load more';

  @override
  String get learningScanSignIn => 'Scan to check in';

  @override
  String get learningScannerUnsupported =>
      'On-site scanning requires Android, iOS or macOS.';

  @override
  String get learningCameraError =>
      'Check camera access and reopen the scanner.';

  @override
  String get learningInvalidQr => 'Scan a valid on-site check-in code.';

  @override
  String get learningScanHint => 'Scan the on-site check-in code';

  @override
  String get courseReminderTitle => 'Tomorrow’s classes';

  @override
  String get courseReminderDescription =>
      'Daily reminder of tomorrow’s first class or a day off';

  @override
  String get courseReminderUnknown =>
      'Refresh the timetable and academic calendar to view tomorrow’s classes.';

  @override
  String get courseReminderRest =>
      'No classes tomorrow, so enjoy your day off!';

  @override
  String courseReminderCourse(String time, String course, String location) {
    return 'First class tomorrow: $time · $course · $location';
  }

  @override
  String get reminderTime => 'Reminder time';

  @override
  String reminderBeijingTime(String time) {
    return '$time Beijing time (UTC+8)';
  }

  @override
  String get reminderPermissionsRequired =>
      'Allow notifications and exact alarms before enabling reminders.';

  @override
  String get reminderNotificationPermission => 'Notifications';

  @override
  String get reminderExactPermission => 'Exact alarms';

  @override
  String get reminderPermissionGranted =>
      'Allowed; tap to manage in system settings.';

  @override
  String get reminderPermissionDenied =>
      'Not allowed; tap to open system settings.';

  @override
  String get reminderPermissionLoading => 'Checking permission';

  @override
  String get reminderFailed => 'Check permissions and retry reminder setup.';

  @override
  String get permissionManagement => 'Permission management';

  @override
  String get permissionManagementSubtitle =>
      'View required permissions and current access';

  @override
  String get permissionManagementDescription =>
      'View permission purposes and status, and manage app access';

  @override
  String get appPermissionSettings => 'App system settings';

  @override
  String get permissionSettingsFailed => 'Could not open system settings.';

  @override
  String get permissionLoadFailed => 'Could not load app permissions.';

  @override
  String get permissionAllowed => 'Allowed';

  @override
  String get permissionNotAllowed => 'Not allowed';

  @override
  String get permissionSpecial => 'Special access';

  @override
  String get permissionRuntime => 'Runtime permission';

  @override
  String get permissionInstall => 'Install-time permission';

  @override
  String get reminderNotificationStyle => 'Lock screen and notification style';

  @override
  String get reminderNotificationStyleDescription =>
      'Manage lock-screen visibility, sounds and banners for course reminders';

  @override
  String get permissionPurposeNotifications =>
      'Send course and scheduled-task notifications';

  @override
  String get permissionPurposeLiveUpdates =>
      'Show ongoing courses prominently in the status bar and on the lock screen';

  @override
  String get permissionPurposeAlarms =>
      'Run background tasks at scheduled times';

  @override
  String get permissionPurposeCamera =>
      'Scan learning center check-in QR codes';

  @override
  String get permissionPurposeLocation =>
      'Provide your current location to verify the attendance area';

  @override
  String get permissionNameCoarseLocation => 'Approximate location';

  @override
  String get permissionNameFineLocation => 'Precise location';

  @override
  String get permissionPurposeInstall => 'Install app updates';

  @override
  String get permissionPurposeInternet =>
      'Connect to fetch timetables, grades and campus services';

  @override
  String get permissionPurposeWake =>
      'Keep the device awake while a background task runs';

  @override
  String get permissionPurposeBoot =>
      'Restore scheduled tasks after device restart';

  @override
  String get courseReminderSettings => 'First class reminder';

  @override
  String get courseReminderSettingsSubtitle =>
      'An evening reminder of tomorrow’s first class';

  @override
  String get permissionNameNotifications => 'Notifications';

  @override
  String get permissionNameLiveUpdates => 'Live Updates';

  @override
  String get permissionNameAlarms => 'Exact alarms';

  @override
  String get permissionNameCamera => 'Camera';

  @override
  String get permissionNameInstall => 'Install apps';

  @override
  String get permissionNameInternet => 'Internet access';

  @override
  String get permissionNameWake => 'Keep awake';

  @override
  String get permissionNameBoot => 'Device restart';

  @override
  String get thirdPartyServices => 'Third-party services';

  @override
  String get thirdPartyDescription =>
      'Manage west2 online schedule adjustments and past-paper access';

  @override
  String get thirdPartyDisabled =>
      'Enable this feature in third-party services.';

  @override
  String get accessTip => 'Ask';

  @override
  String get accessAllow => 'Enable';

  @override
  String get accessHide => 'Hide';

  @override
  String get pastPapers => 'Past papers';

  @override
  String get pastPapersDescription =>
      'Get past-paper listings and download links from west2 online';

  @override
  String get campusServices => 'Campus services';

  @override
  String get campusServicesDescription =>
      'Open official university services when needed; services requiring sign-in reuse university SSO.';

  @override
  String get campusDormRepair => 'Dorm repairs';

  @override
  String get campusReservations => 'Campus reservations';

  @override
  String get campusLibraryReservation => 'Library reservations';

  @override
  String get campusLostAndFound => 'Lost and found';

  @override
  String get campusAttendance => 'Evening attendance';

  @override
  String get campusElectricBike => 'Electric bike management';

  @override
  String get campusYiban => 'Yiban campus services';

  @override
  String get webViewLoadError => 'Could not load webpage';

  @override
  String get customCourses => 'Custom courses';

  @override
  String get customCoursesDescription =>
      'Manage custom courses for each term of the current account';

  @override
  String get customCoursesEmpty => 'No custom courses for this term';

  @override
  String get customCourseAdd => 'Add course';

  @override
  String get customCourseEdit => 'Edit course';

  @override
  String get customCourseDelete => 'Delete course';

  @override
  String get customCourseSave => 'Save course';

  @override
  String get customCourseName => 'Course name';

  @override
  String get customCourseTeacher => 'Teacher (optional)';

  @override
  String get customCourseLocation => 'Location (optional)';

  @override
  String get customCourseRemark => 'Notes (optional)';

  @override
  String get customCourseWeekday => 'Day of week';

  @override
  String get customCourseStartWeek => 'First week';

  @override
  String get customCourseEndWeek => 'Last week';

  @override
  String get customCourseRepeat => 'Repeat';

  @override
  String get customCourseEveryWeek => 'Every week';

  @override
  String get customCourseOddWeeks => 'Odd weeks';

  @override
  String get customCourseEvenWeeks => 'Even weeks';

  @override
  String get customCourseColor => 'Course color';

  @override
  String get customCourseNameRequired => 'Enter a course name';

  @override
  String get customCourseTermHint => 'Six-digit term ID, for example 202601';

  @override
  String get customCourseTermInvalid => 'Enter a six-digit term ID';

  @override
  String get customCourseRangeInvalid =>
      'The ending week and period must not precede the start';

  @override
  String get customCourseLoginRequired =>
      'Sign in to your academic account to manage courses';

  @override
  String get webdavAutoSync => 'Sync automatically on open';

  @override
  String get webdavAutoSyncDescription =>
      'Sync automatically on launch or return to the app, with manual selection when both sides change';

  @override
  String get webdavAutoSyncConflict =>
      'Data differs on both sides; open WebDAV to choose upload or download.';

  @override
  String get webdavAutoSyncManualUpload =>
      'This server cannot protect against conflicting uploads; upload manually in WebDAV.';

  @override
  String get webdavAutoSyncFailed =>
      'Automatic sync failed; check the connection in WebDAV settings.';

  @override
  String get webdavTestConnection => 'Test connection';

  @override
  String get webdavTestDescription =>
      'The test creates missing folders and temporarily writes, reads and deletes a file.';

  @override
  String get webdavConnectionValid =>
      'Connection verified; the directory is readable and writable and the test file was removed.';

  @override
  String get webdavSync => 'WebDAV sync';

  @override
  String get webdavDescription =>
      'Sync settings and course records through WebDAV without login details or caches';

  @override
  String get webdavDirectory => 'WebDAV directory URL';

  @override
  String get webdavDirectoryHint =>
      'Enter a sync directory URL; missing folders are created when uploading.';

  @override
  String get webdavUsername => 'WebDAV username';

  @override
  String get webdavSave => 'Test and save';

  @override
  String get webdavSaved => 'WebDAV configuration saved';

  @override
  String get webdavUpload => 'Upload to WebDAV';

  @override
  String get webdavDownload => 'Download and replace local data';

  @override
  String get webdavUploaded => 'Sync data uploaded';

  @override
  String get webdavDownloaded => 'Settings and course records restored';

  @override
  String get webdavCreateDescription =>
      'Upload current settings and course records to this directory?';

  @override
  String get webdavUploadDescription =>
      'Replace the remote backup with this device’s current data?';

  @override
  String get webdavDownloadDescription =>
      'Replace local settings and every account’s custom and hidden course records with this backup while keeping login sessions?';

  @override
  String get webdavRemoteUpdated => 'Backup time';

  @override
  String get webdavCustomCourses => 'Custom courses';

  @override
  String get webdavHiddenCourses => 'Hidden course records';

  @override
  String get webdavNotFound =>
      'Upload a backup to create the remote sync file.';

  @override
  String get webdavCancel => 'Cancel';

  @override
  String get webdavConfirm => 'Confirm';

  @override
  String get cultivatePlan => 'Curriculum plan';

  @override
  String get cultivatePlanDescription =>
      'Find the official plan for your cohort, college and major';

  @override
  String get selectPlanManually => 'Select a plan on the academic website';

  @override
  String get studentCardServices => 'Student card services';

  @override
  String get replaceStudentCard => 'Replace student card';

  @override
  String get replaceSupplementaryCard => 'Replace supplementary card';

  @override
  String get changeTravelRoute => 'Change travel route';

  @override
  String get graduationProject => 'Graduation project / thesis';

  @override
  String get papersHidden => 'Past papers are hidden';

  @override
  String get papersSearch => 'Search this folder';

  @override
  String get papersRoot => 'Paper library';

  @override
  String get papersParent => 'Go to parent folder';

  @override
  String get papersEmpty => 'No matching papers or folders';

  @override
  String get papersOpenDescription =>
      'View or download the paper in your browser, or copy its link.';

  @override
  String get papersOpenFailed =>
      'Copy the link and open it manually in your browser.';

  @override
  String get utilityPayment => 'Utility payments';

  @override
  String get utilityDescription =>
      'Choose a campus to view and pay dormitory utility bills in the CCB app.';

  @override
  String get utilityMobileRequired =>
      'Dormitory utility payments require the China Construction Bank app on an Android phone or iPhone.';

  @override
  String get utilityCampusQishan => 'Qishan campus';

  @override
  String get utilityCampusTongpan => 'Tongpan campus';

  @override
  String get utilityCampusJinjiang => 'Jinjiang campus';

  @override
  String get utilityCampusYishan => 'Yishan campus';

  @override
  String get utilityOpenFailed => 'Cannot open the CCB app';

  @override
  String get utilityInstallDescription =>
      'Install the CCB app or copy the payment link to try again.';

  @override
  String get utilityClose => 'Close';

  @override
  String get utilityCopyLink => 'Copy payment link';

  @override
  String get utilityCopied => 'Payment link copied';

  @override
  String get utilityInstall => 'Get the CCB app';

  @override
  String get utilityDownloadFailed =>
      'Search your app store for China Construction Bank.';

  @override
  String get reminderXiaomiNotice => 'System restriction notice';

  @override
  String get reminderXiaomiDescription =>
      'MIUI / HyperOS restricts background local notifications, so this feature is unavailable and you may try unlocking the restriction after rooting your device.';

  @override
  String get gradesSummaryTitle => 'Semester summary';

  @override
  String get gradesSummaryTotalCredits => 'Total credits';

  @override
  String get gradesSummaryHighestScore => 'Highest grade';

  @override
  String get gradesSummaryEstimatedGpa => 'Estimated GPA';

  @override
  String get gradesSummaryMissingValue => 'Missing';

  @override
  String get gradesSummaryNoGpa => 'No eligible courses';

  @override
  String get gradesSummaryIncompleteGpa =>
      'Some course credits or GPAs are missing. An estimate is unavailable.';

  @override
  String get gradesSummaryIncompleteCredits =>
      'Some course credits are missing. Total credits includes known values only.';

  @override
  String get gradesSummaryGpaNote =>
      'Credit-weighted estimate for reference. Official academic records take precedence.';

  @override
  String get gradesSummaryRules =>
      'Graded make-up exams replace original records; each course counts once. Excluded categories, second majors and pass/fail courses do not contribute to GPA.';

  @override
  String get gradesMissingGpa => 'GPA missing';

  @override
  String get campusServicesLife => 'Living and housing';

  @override
  String get campusServicesBookings => 'Spaces and reservations';

  @override
  String get campusServicesGrowth => 'Learning and activities';

  @override
  String get campusServicesOffice => 'Information and services';

  @override
  String get campusServicesNetwork => 'Maps and campus network';

  @override
  String get campusDormRepairDescription =>
      'Report dorm facility problems and check repair progress.';

  @override
  String get campusReservationsDescription =>
      'Make reservations through the university booking platform.';

  @override
  String get campusLibraryReservationDescription =>
      'Find and reserve library seats.';

  @override
  String get campusLostAndFoundDescription =>
      'Post and browse lost and found items on campus.';

  @override
  String get campusAttendanceDescription =>
      'Check in through the evening attendance service.';

  @override
  String get campusElectricBikeDescription =>
      'Access campus electric bike management services.';

  @override
  String get campusYibanDescription => 'Open university services on Yiban.';

  @override
  String get campusMailbox => 'FZU email';

  @override
  String get campusMailboxDescription =>
      'Activate and access your university email account.';

  @override
  String get campusQuickResponse => 'Campus feedback';

  @override
  String get campusQuickResponseDescription =>
      'Submit campus requests, feedback and suggestions.';

  @override
  String get campusTrustedDocuments => 'Trusted electronic documents';

  @override
  String get campusTrustedDocumentsDescription =>
      'Access the university trusted document service.';

  @override
  String get campusOfficialNotices => 'University notices and documents';

  @override
  String get campusOfficialNoticesDescription =>
      'Browse official university notices and documents.';

  @override
  String get campusYouthLeague => 'Youth League services';

  @override
  String get campusYouthLeagueDescription =>
      'Access the university Youth League service platform.';

  @override
  String get campusStudentAffairs => 'One-stop student affairs';

  @override
  String get campusStudentAffairsDescription =>
      'Access student affairs and support services.';

  @override
  String get campusLectureReports => 'Lectures and talks';

  @override
  String get campusLectureReportsDescription =>
      'Browse public university lectures and talks.';

  @override
  String get campusCertifications => 'Certification information';

  @override
  String get campusCertificationsDescription =>
      'Find information on certification and qualification exams.';

  @override
  String get campusElectricBikeRegistration => 'Electric bike registration';

  @override
  String get campusElectricBikeRegistrationDescription =>
      'Open the university electric bike registration service.';

  @override
  String get campusUnifiedPayment => 'University payments';

  @override
  String get campusUnifiedPaymentDescription =>
      'Make payments through the university payment platform.';

  @override
  String get campusCardServices => 'Campus card services';

  @override
  String get campusCardServicesDescription =>
      'Access the official university campus card platform.';

  @override
  String get campusForms => 'University forms';

  @override
  String get campusFormsDescription =>
      'Complete forms through the university form platform.';

  @override
  String get campusResume => 'Personal resume';

  @override
  String get campusResumeDescription =>
      'View and maintain your resume in campus services.';

  @override
  String get campusVenueReservation => 'Venue reservations';

  @override
  String get campusVenueReservationDescription =>
      'Find and reserve available university venues.';

  @override
  String get campusNewStudentServices => 'New student services';

  @override
  String get campusNewStudentServicesDescription =>
      'Access arrival and registration services for new students.';

  @override
  String get campusIdentityVerification => 'Identity verification';

  @override
  String get campusIdentityVerificationDescription =>
      'Open the university identity verification service.';

  @override
  String get campusMap => 'Campus map';

  @override
  String get campusMapDescription =>
      'Explore the campus map and find university locations.';

  @override
  String get campusActivities => 'Campus activities';

  @override
  String get campusActivitiesDescription =>
      'Browse campus activities and their details.';

  @override
  String get campusSavedActivities => 'Saved campus activities';

  @override
  String get campusSavedActivitiesDescription =>
      'View your saved campus activities.';

  @override
  String get campusNetworkRepair => 'Campus network repairs';

  @override
  String get campusNetworkRepairDescription =>
      'Report campus network problems.';

  @override
  String get campusNetworkGuide => 'Campus network access guide';

  @override
  String get campusNetworkGuideDescription =>
      'Read instructions for connecting to the campus network.';

  @override
  String get campusReturnReservation => 'Group return reservations';

  @override
  String get campusReturnReservationDescription =>
      'Arrange reservations for a group return to campus.';

  @override
  String get campusPartyTraining => 'Party member training';

  @override
  String get campusPartyTrainingDescription =>
      'Access the university party member training platform.';

  @override
  String get campusAccommodation => 'Accommodation applications';

  @override
  String get campusAccommodationDescription =>
      'Submit applications for accommodation services.';

  @override
  String get jobFairTitle => 'Job fairs & career talks';

  @override
  String get jobFairDescription =>
      'Recruiting events published by FZU, with all times in Beijing time.';

  @override
  String get jobFairPreviousMonth => 'Previous month';

  @override
  String get jobFairNextMonth => 'Next month';

  @override
  String get jobFairCurrentMonth => 'This month';

  @override
  String get jobFairSelectMonth => 'Select month';

  @override
  String get jobFairUpcoming => 'Upcoming';

  @override
  String get jobFairPast => 'Past events';

  @override
  String get jobFairRecruitment => 'Job fair';

  @override
  String get jobFairKeynote => 'Career talk';

  @override
  String get jobFairNoEvents => 'No job fairs or career talks this month';

  @override
  String get jobFairUnknownTitle => 'Event title not announced';

  @override
  String get jobFairUnknownPlace => 'Venue to be announced';

  @override
  String get jobFairLoadFailed =>
      'Could not load recruiting events. Please retry.';

  @override
  String get jobFairRefreshFailed =>
      'Could not refresh. Previously loaded events are still shown.';

  @override
  String get jobFairInvalidDetails =>
      'This event has an invalid official details address.';

  @override
  String get jobFairShowingPreviousMonth =>
      'Could not load the selected month. The last successfully loaded month is still shown.';

  @override
  String get jobFairPartialData =>
      'Some events could not be read and were skipped. Please check official announcements.';

  @override
  String get lecturesDescription =>
      'View registered lectures and attendance; register on the official academic website.';

  @override
  String get lecturesEmpty => 'No registered lectures';

  @override
  String get lecturesOpenOfficial => 'Register / view on official website';

  @override
  String get lectureCategory => 'Category';

  @override
  String get lectureIssueNumber => 'Issue';

  @override
  String get lectureSpeaker => 'Speaker';

  @override
  String get lectureDateTime => 'Time (Beijing)';

  @override
  String get lectureLocation => 'Location';

  @override
  String get lectureAttendance => 'Attendance';

  @override
  String get lectureUnknown => 'To be announced';

  @override
  String get lectureUntitled => 'Untitled lecture';

  @override
  String get papersDownloadDescription =>
      'Download to the app folder, then open or share the file.';

  @override
  String get papersDownloadLocal => 'Download file';

  @override
  String get papersDownloadPreparing => 'Getting download link';

  @override
  String get papersDownloading => 'Downloading';

  @override
  String get papersDownloadComplete => 'Download complete';

  @override
  String get papersDownloadCancelled => 'Download cancelled';

  @override
  String get papersDownloadFailed =>
      'Download failed. Retry or open in your browser.';

  @override
  String get papersDownloadInvalidFile => 'Invalid paper path or file name';

  @override
  String get papersDownloadIncomplete =>
      'The file is incomplete. Please download it again.';

  @override
  String get papersDownloadCleanupFailed =>
      'Unable to remove the unfinished file. Check app storage and retry.';

  @override
  String get papersOpenFile => 'Open file';

  @override
  String get papersShareFile => 'Share file';

  @override
  String get papersOpenFolder => 'Open containing folder';

  @override
  String get papersCopyLocalPath => 'Copy local path';

  @override
  String get papersLocalOpenFailed =>
      'Unable to open the file. Share it or open it in your browser.';

  @override
  String get papersShareFailed =>
      'File sharing is unavailable. Copy the local path or open it in your browser.';

  @override
  String get papersByteUnit => 'B';

  @override
  String get papersKibibyteUnit => 'KiB';

  @override
  String get papersMebibyteUnit => 'MiB';

  @override
  String get papersGibibyteUnit => 'GiB';

  @override
  String papersDownloadBytes(String received) {
    return '$received downloaded';
  }

  @override
  String papersDownloadProgress(String received, String total, String percent) {
    return '$received / $total · $percent';
  }

  @override
  String get nextCourseWidgetSettings => 'Home screen widgets';

  @override
  String get nextCourseWidgetDescription =>
      'See your next class or weekly timetable on the home screen';

  @override
  String get nextCourseWidgetAdd => 'Add to home screen';

  @override
  String get nextCourseWidgetAddDescription =>
      'Add the selected course widget to your home screen';

  @override
  String get nextCourseWidgetPinGuidance =>
      'Confirm the addition in your launcher\'s system prompt. If no prompt appears, long-press the home screen and add it from the widget list.';

  @override
  String get nextCourseWidgetPinPermissionHint =>
      'If MIUI / HyperOS blocks adding widgets, check the home screen shortcuts permission in App info, if available.';

  @override
  String get nextCourseWidgetPinSettings => 'Open App info';

  @override
  String get nextCourseWidgetPinRequested =>
      'The add request was sent to your launcher. Confirm it in the system prompt. If no prompt appears, long-press the home screen and add it from the widget list.';

  @override
  String get nextCourseWidgetPinFailed =>
      'Could not request a widget. Try again or add it from your launcher\'s widget list.';

  @override
  String get nextCourseWidgetPinUnavailable =>
      'This launcher cannot add widgets directly. Long-press the home screen and add it from the widget list.';

  @override
  String get nextCourseWidgetRefresh => 'Refresh from academic services';

  @override
  String get nextCourseWidgetRefreshDescription =>
      'Sign in and refresh your cached calendar, timetable and all widgets.';

  @override
  String get nextCourseWidgetUpdated => 'Widget updated';

  @override
  String get nextCourseWidgetFailed =>
      'Could not update the widget. Try again.';

  @override
  String get nextCourseWidgetPrivacy =>
      'Class names, times and locations are visible on the home screen. Signing out of your academic account clears them.';

  @override
  String get nextCourseWidgetMissing =>
      'Refresh your calendar and current term timetable first.';

  @override
  String get nextCourseWidgetUnsupported =>
      'Home screen widgets are currently available on Android.';

  @override
  String get widgetVariantCompact => '2×1';

  @override
  String get widgetVariantSquare => '2×2';

  @override
  String get widgetVariantTimetable => 'Weekly 4×4';

  @override
  String get widgetPreview => 'Widget preview';

  @override
  String get widgetNextClass => 'Next class';

  @override
  String get widgetInProgress => 'In class';

  @override
  String get widgetWeeklyTimetable => 'This week';

  @override
  String widgetAddVariant(String variant) {
    return 'Add $variant widget';
  }

  @override
  String get widgetSyncEnabled => 'Automatic nightly refresh';

  @override
  String get widgetSyncDescription =>
      'Sign in daily to update your cached timetable and home screen widgets.';

  @override
  String get widgetSyncTime => 'Automatic refresh time';

  @override
  String get widgetSyncLastSuccess => 'Last successful refresh';

  @override
  String get widgetSyncNever => 'No successful online refresh yet';

  @override
  String get widgetSyncNext => 'Next automatic refresh';

  @override
  String get widgetSyncFailed =>
      'Online refresh failed. Your existing cache is still available; try again.';

  @override
  String get calendarSync => 'Calendar sync';

  @override
  String get calendarSyncDescription =>
      'Write your timetable to the system calendar';

  @override
  String get calendarSyncScope =>
      'Includes current and upcoming terms, custom courses, schedule changes, and optional exams. Hidden sessions are excluded.';

  @override
  String get calendarSyncEnabled => 'Sync to system calendar';

  @override
  String get calendarSyncPausedHint =>
      'Turning this off keeps events already synced.';

  @override
  String get calendarSyncPermission => 'Calendar access';

  @override
  String get calendarSyncPermissionRequired =>
      'Allow calendar read and write access first.';

  @override
  String get calendarSyncTime => 'Daily sync time';

  @override
  String get calendarSyncNow => 'Sync now';

  @override
  String get calendarSyncBusy => 'Syncing…';

  @override
  String get calendarSyncLastSuccess => 'Last successful sync';

  @override
  String get calendarSyncFailed =>
      'Sync didn\'t finish. Check your connection and calendar access, then retry.';

  @override
  String calendarSyncResult(int inserted, int updated, int deleted) {
    return 'Added $inserted · Updated $updated · Deleted $deleted';
  }

  @override
  String get calendarSyncReadPermission => 'Read calendar';

  @override
  String get calendarSyncWritePermission => 'Write calendar';

  @override
  String get calendarSyncReadPurpose =>
      'Compare previously synced course events';

  @override
  String get calendarSyncWritePurpose =>
      'Add, update and remove courses and exams in the dedicated calendar';

  @override
  String get calendarSyncClear => 'Delete all app events';

  @override
  String get calendarSyncClearHint =>
      'Delete courses and exams created by FZU Assistant for all accounts on this device and turn off calendar sync. Independently added events and other calendars are kept.';

  @override
  String get calendarSyncCleared =>
      'App events deleted and calendar sync turned off.';

  @override
  String get calendarSyncClearFailed =>
      'Event cleanup did not finish. Check calendar access and retry.';

  @override
  String get calendarSyncStartHint =>
      'Write your timetable to the system calendar when enabled.';

  @override
  String get calendarSyncNever => 'Not synced yet';

  @override
  String get calendarSyncOff => 'Sync is off';

  @override
  String get calendarSyncPending => 'Changes waiting to sync';

  @override
  String get calendarSyncSaved => 'Saved. Changes apply at the next sync.';

  @override
  String get calendarSyncSaving => 'Saving settings…';

  @override
  String get calendarSyncSaveFailed => 'Couldn\'t save settings. Try again.';

  @override
  String get calendarSyncLoadFailed => 'Couldn\'t read sync status. Try again.';

  @override
  String get calendarSyncScheduleFailed =>
      'Automatic sync isn\'t scheduled yet. Try again.';

  @override
  String calendarSyncOccurrences(int count) {
    return 'Covers $count class sessions and exams';
  }

  @override
  String get calendarSyncNoChanges => 'No changes in this sync';

  @override
  String get calendarSyncSharedTime => 'Time shared with home screen widgets';

  @override
  String get calendarSyncPermissions => 'System permissions';

  @override
  String get calendarSyncPermissionsReady =>
      'Calendar access and scheduled sync allowed';

  @override
  String get calendarSyncCalendarNeeded => 'Calendar access needed';

  @override
  String get calendarSyncAlarmNeeded => 'Scheduled sync needs permission';

  @override
  String get calendarSyncAlarmHint =>
      'Allow exact alarms to run automatic sync on time.';

  @override
  String get calendarSyncGrantCalendar => 'Allow calendar access';

  @override
  String get calendarSyncGrantAlarm => 'Allow scheduled sync';

  @override
  String get calendarSyncAllowed => 'Allowed';

  @override
  String get calendarSyncNotAllowed => 'Not allowed';

  @override
  String get calendarSyncCalendarPurpose =>
      'Read and update events created by this app';

  @override
  String get calendarSyncAlarmPurpose =>
      'Run automatic sync at the selected time';

  @override
  String get calendarSyncHelp => 'About calendar sync';

  @override
  String get calendarSyncRecurrenceHint =>
      'Regular classes use recurring events. Changes, cancellations, and hidden sessions affect only the relevant occurrence. Syncing again doesn\'t add duplicates.';

  @override
  String get calendarSyncPauseHelp =>
      'Turning off sync or signing out stops updates and keeps existing events. Use the action at the bottom of this page to remove all events created by the app.';

  @override
  String get calendarSyncClearSummary =>
      'Remove synced events for all accounts and turn off sync';

  @override
  String get calendarSyncClearConfirm => 'Delete events';

  @override
  String get calendarSyncClearing => 'Deleting events…';

  @override
  String get calendarExport => 'Export to calendar';

  @override
  String get calendarExportDescription =>
      'Export cached courses and exams as a calendar file';

  @override
  String get calendarExportSnapshot =>
      'Uses Beijing time and includes your custom courses, adjustments and hidden sessions. Export again after timetable changes.';

  @override
  String get calendarExportMissingData =>
      'Refresh your calendar and timetable on the Home tab first.';

  @override
  String get calendarExportIncludeExams => 'Include exams';

  @override
  String get calendarExportReminder => 'Event reminder';

  @override
  String get calendarExportNoReminder => 'No reminder';

  @override
  String calendarExportReminderMinutes(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String calendarExportEventCount(int count) {
    return '$count events';
  }

  @override
  String calendarExportSkippedExams(int count) {
    return '$count exams could not be parsed and were skipped.';
  }

  @override
  String get calendarExportSave => 'Export calendar file';

  @override
  String get calendarExportBusy => 'Exporting…';

  @override
  String get calendarExportSaved => 'Calendar file exported';

  @override
  String get academicChanges => 'Academic updates';

  @override
  String get academicChangesSubtitle =>
      'View grade and exam changes found after queries.';

  @override
  String get academicChangesDescription =>
      'Records the latest 100 grade and exam changes after the first query; tap an entry to mark it read.';

  @override
  String get academicChangesEmpty =>
      'No changes yet. Query your grades or exams first.';

  @override
  String get academicChangesMarkRead => 'Mark all as read';

  @override
  String get academicChangeGradeAdded => 'New grade';

  @override
  String get academicChangeGradeChanged => 'Grade changed';

  @override
  String get academicChangeExamAdded => 'Exam scheduled';

  @override
  String get academicChangeExamChanged => 'Exam arrangement changed';

  @override
  String get academicChangeExamRemoved => 'Exam arrangement withdrawn';

  @override
  String academicChangeCount(int count) {
    return '$count unread academic updates';
  }

  @override
  String academicChangeFromTo(String before, String after) {
    return '$before → $after';
  }

  @override
  String get themeMyThemes => 'My themes';

  @override
  String get themeCreate => 'Create theme';

  @override
  String get themeImport => 'Import theme';

  @override
  String get themeExport => 'Export theme';

  @override
  String get themeShare => 'Share theme';

  @override
  String get themeDuplicate => 'Duplicate theme';

  @override
  String get themeCopy => 'Copy';

  @override
  String get themeDelete => 'Delete theme';

  @override
  String get themeDeleteMessage =>
      'This theme will be removed. If it is active, the preset palette will be restored.';

  @override
  String get themeUntitled => 'New theme';

  @override
  String get themeEmpty => 'Create your own palette or import a shared theme.';

  @override
  String get themeImportHelp =>
      'Import theme packages with background images or theme JSON files';

  @override
  String get themeImported => 'Theme imported. Tap it to apply.';

  @override
  String get themeExported => 'Theme package exported';

  @override
  String get themePackageHelp =>
      'The package contains both palettes, styles and background images';

  @override
  String get themeEdit => 'Edit theme';

  @override
  String get themeBasicInfo => 'Basic information';

  @override
  String get themeName => 'Theme name';

  @override
  String get themeBasePalette => 'Base palette';

  @override
  String get themeCustomPalette => 'Custom';

  @override
  String get themeColorSource => 'Theme colors';

  @override
  String get themeSourceSystem => 'Phone wallpaper colors';

  @override
  String get themeSourceSystemHelp =>
      'Use dynamic colors provided by the system';

  @override
  String get themeSourceSystemUnavailable =>
      'Dynamic colors are unavailable on this system';

  @override
  String get themeSourceImage => 'App wallpaper colors';

  @override
  String get themeSourceSeed => 'Choose theme color';

  @override
  String get themeCustomSeed => 'Custom color';

  @override
  String get themeReplacePalette => 'Regenerate colors?';

  @override
  String themeReplacePaletteMessage(String appearance) {
    return 'Replace the $appearance theme colors and keep the background and timetable styles';
  }

  @override
  String get themeBackground => 'Background image';

  @override
  String get themeChooseImage => 'Choose image';

  @override
  String get themeRemoveImage => 'Remove image';

  @override
  String get themeBackgroundDim => 'Background dimming';

  @override
  String get themeBackgroundBlur => 'Background blur';

  @override
  String get themeSurfaceOpacity => 'Panel opacity';

  @override
  String get themeCourseStyle => 'Timetable and cards';

  @override
  String get themeCoursePalette => 'Course card palette';

  @override
  String get themeCoursePaletteCustom => 'Custom';

  @override
  String get themeCoursePaletteEdit => 'Edit palette';

  @override
  String get themeCoursePaletteAdd => 'Add color';

  @override
  String get themeCoursePaletteFromWallpaper => 'Generate from wallpaper';

  @override
  String themeCoursePaletteRemove(int index) {
    return 'Remove color $index';
  }

  @override
  String themeCoursePaletteCount(int count) {
    return '$count colors';
  }

  @override
  String themeCoursePaletteColor(int index) {
    return 'Color $index';
  }

  @override
  String get themeCourseOpacity => 'Course card opacity';

  @override
  String get themeCardRadius => 'Interface card radius';

  @override
  String get themeCourseRadius => 'Course card radius';

  @override
  String get themeDividerWidth => 'Divider width';

  @override
  String get themeScheduleColors => 'Timetable colors';

  @override
  String get themeResetColor => 'Reset to default';

  @override
  String get themeColorHex => 'Color value';

  @override
  String get themeColorHexHelp => 'Enter #RRGGBB or #AARRGGBB';

  @override
  String get themePreview => 'Preview';

  @override
  String get themeSaveApply => 'Save and apply';

  @override
  String get themeUnsavedTitle => 'Discard changes?';

  @override
  String get themeUnsavedMessage => 'Your unsaved theme changes will be lost.';

  @override
  String get themeDiscard => 'Discard changes';

  @override
  String get themeKeepEditing => 'Keep editing';

  @override
  String get themeSaved => 'Theme saved and applied';

  @override
  String get themeNameRequired => 'Enter a theme name of 1–80 characters';

  @override
  String get themeColorInvalid => 'Enter a valid hexadecimal color';

  @override
  String get themeImageHelp =>
      'Set separate background images for light and dark modes';

  @override
  String academicChangeDetectedAt(String time) {
    return 'Detected at (Beijing time): $time';
  }

  @override
  String get classroomUsage => 'Classroom availability';

  @override
  String get classroomUsageSubtitle =>
      'View classroom availability throughout the day';

  @override
  String get usageFilters => 'Filters';

  @override
  String get usageCampus => 'Campus';

  @override
  String get usageBuilding => 'Building';

  @override
  String get usageLegend =>
      'Numbers are periods; a dot means occupied. Expand for details';

  @override
  String get usagePeriod => 'Period';

  @override
  String get usageOccupied => 'Occupied';

  @override
  String get usageFree => 'Available';

  @override
  String get usageAllFree => 'No scheduled occupancy on this day';

  @override
  String get downloadLibrary => 'Downloaded papers';

  @override
  String get downloadLibrarySubtitle =>
      'Manage, open and share downloaded papers';

  @override
  String get downloadSearch => 'Search downloaded papers';

  @override
  String get downloadEmpty => 'No downloaded papers';

  @override
  String get downloadDelete => 'Delete file';

  @override
  String get downloadDeletePrompt =>
      'You can download this paper again after deleting the local file';

  @override
  String get downloadCopyPath => 'Copy file path';

  @override
  String get downloadPathCopied => 'File path copied';

  @override
  String get downloadActionFailed => 'File action failed';

  @override
  String get courseLiveUpdates => 'Live Updates';

  @override
  String get courseLiveUpdatesSubtitle =>
      'Course progress, next class and end-of-session reminders';

  @override
  String get courseLiveUpdatesDescription =>
      'Show course progress, then the next class in the same morning, afternoon or evening';

  @override
  String get courseLiveUpdatesEnabled => 'Course Live Updates';

  @override
  String get courseLiveUpdatesRule =>
      'After the last class of the morning, afternoon or evening, send an end notification';

  @override
  String get courseLiveUpdatesFailed => 'Could not update course Live Updates';

  @override
  String get courseLiveInProgress => 'Class in progress';

  @override
  String get courseLiveEnded => 'Class ended';

  @override
  String get courseLiveNext => 'Next class';

  @override
  String get courseLiveMorningEnded => 'Morning classes finished';

  @override
  String get courseLiveAfternoonEnded => 'Afternoon classes finished';

  @override
  String get courseLiveEveningEnded => 'Evening classes finished';

  @override
  String courseLiveStartsInMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Starts in $minutes minutes',
      one: 'Starts in 1 minute',
    );
    return '$_temp0';
  }
}
