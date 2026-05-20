import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// appName
  ///
  /// In zh, this message translates to:
  /// **'FZU Assistant'**
  String get appName;

  /// navSchedule
  ///
  /// In zh, this message translates to:
  /// **'课程表'**
  String get navSchedule;

  /// navToolbox
  ///
  /// In zh, this message translates to:
  /// **'工具箱'**
  String get navToolbox;

  /// navMy
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navMy;

  /// Retry button text
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @loadingFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String loadingFailed(String error);

  /// noData
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @dataUpdatedAt.
  ///
  /// In zh, this message translates to:
  /// **'数据更新于 {time}'**
  String dataUpdatedAt(String time);

  /// studentId
  ///
  /// In zh, this message translates to:
  /// **'学号'**
  String get studentId;

  /// password
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// captcha
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get captcha;

  /// getCaptcha
  ///
  /// In zh, this message translates to:
  /// **'获取验证码'**
  String get getCaptcha;

  /// login
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// loginValidationError
  ///
  /// In zh, this message translates to:
  /// **'请输入学号、密码和验证码'**
  String get loginValidationError;

  /// No description provided for @captchaFetchFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取验证码失败: {error}'**
  String captchaFetchFailed(String error);

  /// No description provided for @weekN.
  ///
  /// In zh, this message translates to:
  /// **'第 {week} 周'**
  String weekN(int week);

  /// thisWeek
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get thisWeek;

  /// noScheduleData
  ///
  /// In zh, this message translates to:
  /// **'暂无课程数据'**
  String get noScheduleData;

  /// monday
  ///
  /// In zh, this message translates to:
  /// **'周一'**
  String get monday;

  /// tuesday
  ///
  /// In zh, this message translates to:
  /// **'周二'**
  String get tuesday;

  /// wednesday
  ///
  /// In zh, this message translates to:
  /// **'周三'**
  String get wednesday;

  /// thursday
  ///
  /// In zh, this message translates to:
  /// **'周四'**
  String get thursday;

  /// friday
  ///
  /// In zh, this message translates to:
  /// **'周五'**
  String get friday;

  /// saturday
  ///
  /// In zh, this message translates to:
  /// **'周六'**
  String get saturday;

  /// sunday
  ///
  /// In zh, this message translates to:
  /// **'周日'**
  String get sunday;

  /// college
  ///
  /// In zh, this message translates to:
  /// **'学院'**
  String get college;

  /// major
  ///
  /// In zh, this message translates to:
  /// **'专业'**
  String get major;

  /// grade
  ///
  /// In zh, this message translates to:
  /// **'年级'**
  String get grade;

  /// calendar
  ///
  /// In zh, this message translates to:
  /// **'校历'**
  String get calendar;

  /// themeSettings
  ///
  /// In zh, this message translates to:
  /// **'外观设置'**
  String get themeSettings;

  /// settings
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// scheduleSettings
  ///
  /// In zh, this message translates to:
  /// **'课表设置'**
  String get scheduleSettings;

  /// generalSettings
  ///
  /// In zh, this message translates to:
  /// **'一般设置'**
  String get generalSettings;

  /// webEnhancement
  ///
  /// In zh, this message translates to:
  /// **'网页增强'**
  String get webEnhancement;

  /// siteInjection
  ///
  /// In zh, this message translates to:
  /// **'注入网页样式'**
  String get siteInjection;

  /// siteInjectionDescription
  ///
  /// In zh, this message translates to:
  /// **'注入自定义 CSS/JS 以改善网页外观'**
  String get siteInjectionDescription;

  /// about
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// logout
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// language
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// chinese
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get chinese;

  /// english
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// gradesAndCredits
  ///
  /// In zh, this message translates to:
  /// **'成绩与学分'**
  String get gradesAndCredits;

  /// examsAndRooms
  ///
  /// In zh, this message translates to:
  /// **'考试与教室'**
  String get examsAndRooms;

  /// campusInfo
  ///
  /// In zh, this message translates to:
  /// **'校园信息'**
  String get campusInfo;

  /// gpaInfo
  ///
  /// In zh, this message translates to:
  /// **'绩点信息'**
  String get gpaInfo;

  /// gpaInfoSubtitle
  ///
  /// In zh, this message translates to:
  /// **'查看绩点排名数据'**
  String get gpaInfoSubtitle;

  /// marksQuery
  ///
  /// In zh, this message translates to:
  /// **'成绩查询'**
  String get marksQuery;

  /// marksQuerySubtitle
  ///
  /// In zh, this message translates to:
  /// **'查看全部课程成绩'**
  String get marksQuerySubtitle;

  /// unifiedExam
  ///
  /// In zh, this message translates to:
  /// **'统考成绩'**
  String get unifiedExam;

  /// unifiedExamSubtitle
  ///
  /// In zh, this message translates to:
  /// **'CET / 省计算机等级考试'**
  String get unifiedExamSubtitle;

  /// examRoom
  ///
  /// In zh, this message translates to:
  /// **'考场查询'**
  String get examRoom;

  /// examRoomSubtitle
  ///
  /// In zh, this message translates to:
  /// **'查看考试时间与考场安排'**
  String get examRoomSubtitle;

  /// creditStats
  ///
  /// In zh, this message translates to:
  /// **'学分统计'**
  String get creditStats;

  /// creditStatsSubtitle
  ///
  /// In zh, this message translates to:
  /// **'查看各类学分完成进度'**
  String get creditStatsSubtitle;

  /// noGpaData
  ///
  /// In zh, this message translates to:
  /// **'暂无绩点数据'**
  String get noGpaData;

  /// dataParseError
  ///
  /// In zh, this message translates to:
  /// **'数据解析异常'**
  String get dataParseError;

  /// noMarksData
  ///
  /// In zh, this message translates to:
  /// **'暂无成绩数据'**
  String get noMarksData;

  /// unknownSemester
  ///
  /// In zh, this message translates to:
  /// **'未知学期'**
  String get unknownSemester;

  /// No description provided for @courseCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 门课程'**
  String courseCount(int count);

  /// No description provided for @creditsTag.
  ///
  /// In zh, this message translates to:
  /// **'学分 {credits}'**
  String creditsTag(String credits);

  /// No description provided for @gpaTag.
  ///
  /// In zh, this message translates to:
  /// **'绩点 {gpa}'**
  String gpaTag(String gpa);

  /// noUnifiedExamData
  ///
  /// In zh, this message translates to:
  /// **'暂无统考成绩'**
  String get noUnifiedExamData;

  /// cetScores
  ///
  /// In zh, this message translates to:
  /// **'CET 成绩'**
  String get cetScores;

  /// provincialComputerScores
  ///
  /// In zh, this message translates to:
  /// **'省计算机成绩'**
  String get provincialComputerScores;

  /// noExamRoomInfo
  ///
  /// In zh, this message translates to:
  /// **'暂无考场信息'**
  String get noExamRoomInfo;

  /// examTaken
  ///
  /// In zh, this message translates to:
  /// **'已考'**
  String get examTaken;

  /// No description provided for @creditSuffix.
  ///
  /// In zh, this message translates to:
  /// **'{credit}学分'**
  String creditSuffix(String credit);

  /// noCreditData
  ///
  /// In zh, this message translates to:
  /// **'暂无学分数据'**
  String get noCreditData;

  /// appearance
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// followSystem
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// light
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get light;

  /// dark
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get dark;

  /// themeColor
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get themeColor;

  /// themeDynamic
  ///
  /// In zh, this message translates to:
  /// **'动态取色'**
  String get themeDynamic;

  /// themeDeepPurple
  ///
  /// In zh, this message translates to:
  /// **'深紫'**
  String get themeDeepPurple;

  /// themeBlue
  ///
  /// In zh, this message translates to:
  /// **'蓝色'**
  String get themeBlue;

  /// themeTeal
  ///
  /// In zh, this message translates to:
  /// **'青色'**
  String get themeTeal;

  /// themeGreen
  ///
  /// In zh, this message translates to:
  /// **'绿色'**
  String get themeGreen;

  /// themeOrange
  ///
  /// In zh, this message translates to:
  /// **'橙色'**
  String get themeOrange;

  /// themeRed
  ///
  /// In zh, this message translates to:
  /// **'红色'**
  String get themeRed;

  /// themePink
  ///
  /// In zh, this message translates to:
  /// **'粉色'**
  String get themePink;

  /// themeIndigo
  ///
  /// In zh, this message translates to:
  /// **'靛蓝'**
  String get themeIndigo;

  /// themeBrown
  ///
  /// In zh, this message translates to:
  /// **'棕色'**
  String get themeBrown;

  /// devTools
  ///
  /// In zh, this message translates to:
  /// **'Dev Tools'**
  String get devTools;

  /// collapse
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapse;

  /// expandAll
  ///
  /// In zh, this message translates to:
  /// **'展开全部'**
  String get expandAll;

  /// noCalendarData
  ///
  /// In zh, this message translates to:
  /// **'暂无校历数据'**
  String get noCalendarData;

  /// No description provided for @academicYearTerm.
  ///
  /// In zh, this message translates to:
  /// **'{startYear}-{endYear} 学年  第{term}学期'**
  String academicYearTerm(String startYear, String endYear, String term);

  /// current
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get current;

  /// noScheduleEvents
  ///
  /// In zh, this message translates to:
  /// **'暂无日程数据'**
  String get noScheduleEvents;

  /// appDescription
  ///
  /// In zh, this message translates to:
  /// **'福州大学一站式校园助手 —— 课表、成绩、考试、校历，开箱即用。'**
  String get appDescription;

  /// openSourceUrl
  ///
  /// In zh, this message translates to:
  /// **'开源地址'**
  String get openSourceUrl;

  /// contributors
  ///
  /// In zh, this message translates to:
  /// **'贡献名单'**
  String get contributors;

  /// No description provided for @commitCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次提交'**
  String commitCount(int count);

  /// emptyClassroom
  ///
  /// In zh, this message translates to:
  /// **'空教室查询'**
  String get emptyClassroom;

  /// emptyClassroomSubtitle
  ///
  /// In zh, this message translates to:
  /// **'查找空闲教室'**
  String get emptyClassroomSubtitle;

  /// noEmptyRoomData
  ///
  /// In zh, this message translates to:
  /// **'暂无空教室数据'**
  String get noEmptyRoomData;

  /// selectDate
  ///
  /// In zh, this message translates to:
  /// **'选择日期'**
  String get selectDate;

  /// selectCampus
  ///
  /// In zh, this message translates to:
  /// **'选择校区'**
  String get selectCampus;

  /// startPeriod
  ///
  /// In zh, this message translates to:
  /// **'开始节次'**
  String get startPeriod;

  /// endPeriod
  ///
  /// In zh, this message translates to:
  /// **'结束节次'**
  String get endPeriod;

  /// query
  ///
  /// In zh, this message translates to:
  /// **'查询'**
  String get query;

  /// officeNotice
  ///
  /// In zh, this message translates to:
  /// **'教务通知'**
  String get officeNotice;

  /// officeNoticeSubtitle
  ///
  /// In zh, this message translates to:
  /// **'查看教务处通知公告'**
  String get officeNoticeSubtitle;

  /// noNoticeData
  ///
  /// In zh, this message translates to:
  /// **'暂无通知数据'**
  String get noNoticeData;

  /// No description provided for @pageN.
  ///
  /// In zh, this message translates to:
  /// **'第 {page} 页'**
  String pageN(int page);

  /// No description provided for @totalPages.
  ///
  /// In zh, this message translates to:
  /// **'共 {total} 页'**
  String totalPages(int total);

  /// openInBrowser
  ///
  /// In zh, this message translates to:
  /// **'在浏览器中打开'**
  String get openInBrowser;

  /// webView
  ///
  /// In zh, this message translates to:
  /// **'网页浏览'**
  String get webView;

  /// warning shown when SSL certificate verification is bypassed in WebView
  ///
  /// In zh, this message translates to:
  /// **'SSL 证书验证已跳过，请注意网页安全'**
  String get sslWarning;

  /// refresh
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// copyLink
  ///
  /// In zh, this message translates to:
  /// **'复制链接'**
  String get copyLink;

  /// snackbar message after copying to clipboard
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// clearCookies
  ///
  /// In zh, this message translates to:
  /// **'清除Cookie'**
  String get clearCookies;

  /// selectSemester
  ///
  /// In zh, this message translates to:
  /// **'选择学期'**
  String get selectSemester;

  /// autoSemester
  ///
  /// In zh, this message translates to:
  /// **'自动（当前学期）'**
  String get autoSemester;

  /// checkForUpdates
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkForUpdates;

  /// newVersionAvailable
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get newVersionAvailable;

  /// releaseNotes
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get releaseNotes;

  /// skipThisVersion
  ///
  /// In zh, this message translates to:
  /// **'跳过此版本'**
  String get skipThisVersion;

  /// downloadUpdate
  ///
  /// In zh, this message translates to:
  /// **'前往下载'**
  String get downloadUpdate;

  /// alreadyLatest
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get alreadyLatest;

  /// updateCheckFailed
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败'**
  String get updateCheckFailed;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
