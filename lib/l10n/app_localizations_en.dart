// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get themeSettingsSubtitle => 'Light/dark mode and theme color';

  @override
  String get settings => 'Settings';

  @override
  String get homeSettings => 'Timetable settings';

  @override
  String get homeSettingsSubtitle =>
      'Manage semesters, timetable display and custom courses.';

  @override
  String get generalSettings => 'General Settings';

  @override
  String get generalSettingsSubtitle => 'Language and web enhancement';

  @override
  String get advancedSettings => 'Advanced Settings';

  @override
  String get advancedSettingsSubtitle => 'Network proxy and advanced options';

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
      'Inject custom CSS/JS to improve web page appearance';

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
      'Get university-wide adjustments from west2 online and confirm them against official notices.';

  @override
  String get autoAdjustCourse => 'Auto adjust courses';

  @override
  String get autoAdjustCourseDescription =>
      'Adjust the timetable using official course change records.';

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
      'Show faded courses from other weeks in free timetable slots.';

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
      'Restore individual sessions hidden from the timetable.';

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
      'Daily reminder of tomorrow’s first class or a day off. ';

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
      'View permission purposes and access status, then tap to manage them in system settings.';

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
      'Manage lock-screen visibility, sounds and banners for course reminders.';

  @override
  String get permissionPurposeNotifications =>
      'Send course and scheduled-task notifications';

  @override
  String get permissionPurposeAlarms =>
      'Run background tasks at scheduled times';

  @override
  String get permissionPurposeCamera =>
      'Scan learning center check-in QR codes';

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
      'Choose whether to hide, ask about or enable each west2 online service.';

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
      'Get past-paper listings and download links from west2 online.';

  @override
  String get campusServices => 'Campus services';

  @override
  String get campusServicesDescription =>
      'Use official campus services with your SSO account.';

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
      'Manage custom courses for each term of the current account.';

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
      'Sync on launch or return to the app, with manual selection when both sides change.';

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
      'Sync settings and course records through WebDAV without login details or caches.';

  @override
  String get webdavDirectory => 'WebDAV directory URL';

  @override
  String get webdavDirectoryHint =>
      'Enter a sync directory URL; missing folders are created when uploading.';

  @override
  String get webdavUsername => 'WebDAV username';

  @override
  String get webdavSave => 'Save configuration';

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
}
