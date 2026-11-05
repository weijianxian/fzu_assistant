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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @hiddenCourseManagement.
  ///
  /// In zh, this message translates to:
  /// **'不展示课程管理'**
  String get hiddenCourseManagement;

  /// No description provided for @customCourseManagement.
  ///
  /// In zh, this message translates to:
  /// **'自定义课程管理'**
  String get customCourseManagement;

  /// No description provided for @academicCachedSession.
  ///
  /// In zh, this message translates to:
  /// **'教务连接失败，正在展示历史缓存，请重试以获取最新数据。'**
  String get academicCachedSession;

  /// No description provided for @accountManagement.
  ///
  /// In zh, this message translates to:
  /// **'账号管理'**
  String get accountManagement;

  /// No description provided for @accountAcademic.
  ///
  /// In zh, this message translates to:
  /// **'教务处'**
  String get accountAcademic;

  /// No description provided for @accountSso.
  ///
  /// In zh, this message translates to:
  /// **'统一身份认证（SSO）'**
  String get accountSso;

  /// No description provided for @accountSignedOut.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get accountSignedOut;

  /// No description provided for @accountSsoDescription.
  ///
  /// In zh, this message translates to:
  /// **'管理统一认证、一码通和学习中心的登录状态'**
  String get accountSsoDescription;

  /// No description provided for @accountAcademicLogoutDescription.
  ///
  /// In zh, this message translates to:
  /// **'退出教务处，并清除当前账号的统一认证、一码通和学习中心登录状态。'**
  String get accountAcademicLogoutDescription;

  /// No description provided for @campusSwipeHint.
  ///
  /// In zh, this message translates to:
  /// **'上下滑动切换消费码和入馆码'**
  String get campusSwipeHint;

  /// No description provided for @campusCode.
  ///
  /// In zh, this message translates to:
  /// **'一码通'**
  String get campusCode;

  /// No description provided for @campusPayCode.
  ///
  /// In zh, this message translates to:
  /// **'消费码'**
  String get campusPayCode;

  /// No description provided for @campusLibraryCode.
  ///
  /// In zh, this message translates to:
  /// **'入馆码'**
  String get campusLibraryCode;

  /// No description provided for @campusLibraryCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'请将二维码或条形码对准图书馆闸机扫码处。'**
  String get campusLibraryCodeHint;

  /// appName
  ///
  /// In zh, this message translates to:
  /// **'福大助手'**
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

  /// No description provided for @thisWeek.
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

  /// themeSettingsSubtitle
  ///
  /// In zh, this message translates to:
  /// **'深浅色模式和主题色'**
  String get themeSettingsSubtitle;

  /// settings
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// homeSettings
  ///
  /// In zh, this message translates to:
  /// **'课表设置'**
  String get homeSettings;

  /// homeSettingsSubtitle
  ///
  /// In zh, this message translates to:
  /// **'管理学期、课表显示与自定义课程。'**
  String get homeSettingsSubtitle;

  /// generalSettings
  ///
  /// In zh, this message translates to:
  /// **'一般设置'**
  String get generalSettings;

  /// generalSettingsSubtitle
  ///
  /// In zh, this message translates to:
  /// **'语言与网页增强'**
  String get generalSettingsSubtitle;

  /// advancedSettings
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get advancedSettings;

  /// advancedSettingsSubtitle
  ///
  /// In zh, this message translates to:
  /// **'网络代理等进阶选项'**
  String get advancedSettingsSubtitle;

  /// githubProxy
  ///
  /// In zh, this message translates to:
  /// **'GitHub 代理'**
  String get githubProxy;

  /// githubProxyEnabled
  ///
  /// In zh, this message translates to:
  /// **'启用 GitHub 代理'**
  String get githubProxyEnabled;

  /// githubProxyDescription
  ///
  /// In zh, this message translates to:
  /// **'更新包和 GitHub 资源下载会使用代理'**
  String get githubProxyDescription;

  /// githubProxyBaseUrl
  ///
  /// In zh, this message translates to:
  /// **'代理地址'**
  String get githubProxyBaseUrl;

  /// githubProxyBaseUrlDescription
  ///
  /// In zh, this message translates to:
  /// **'填写 GitHub 下载代理地址，例如 https://gh-proxy.org/。'**
  String get githubProxyBaseUrlDescription;

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

  /// reset
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

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

  /// Button text for disabling automatic update prompts permanently
  ///
  /// In zh, this message translates to:
  /// **'永久跳过'**
  String get skipUpdatesPermanently;

  /// downloadUpdate
  ///
  /// In zh, this message translates to:
  /// **'前往下载'**
  String get downloadUpdate;

  /// Button text for downloading and installing an update in app
  ///
  /// In zh, this message translates to:
  /// **'下载并安装'**
  String get installUpdate;

  /// Shown when no compatible update package asset is found
  ///
  /// In zh, this message translates to:
  /// **'未找到适配当前设备的安装包，已打开下载页面'**
  String get updateNoCompatiblePackage;

  /// Shown when Android install permission is required
  ///
  /// In zh, this message translates to:
  /// **'请允许安装未知来源应用后，再点击下载并安装'**
  String get updateInstallPermissionRequired;

  /// Shown when update download fails
  ///
  /// In zh, this message translates to:
  /// **'下载更新失败'**
  String get updateDownloadFailed;

  /// Shown when opening Android installer fails
  ///
  /// In zh, this message translates to:
  /// **'打开安装器失败'**
  String get updateInstallFailed;

  /// Shown while opening the Android package installer
  ///
  /// In zh, this message translates to:
  /// **'打开安装器'**
  String get updateOpeningInstaller;

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

  /// showExamOnSchedule
  ///
  /// In zh, this message translates to:
  /// **'在课表中显示考试'**
  String get showExamOnSchedule;

  /// showExamOnScheduleDescription
  ///
  /// In zh, this message translates to:
  /// **'把考试安排显示在对应日期的课程表里'**
  String get showExamOnScheduleDescription;

  /// No description provided for @west2AdjustmentsEnabled.
  ///
  /// In zh, this message translates to:
  /// **'从 west2 获取调课数据'**
  String get west2AdjustmentsEnabled;

  /// No description provided for @west2AdjustmentsDescription.
  ///
  /// In zh, this message translates to:
  /// **'从西二在线补充全校调休安排，数据请以教务通知为准。'**
  String get west2AdjustmentsDescription;

  /// autoAdjustCourse
  ///
  /// In zh, this message translates to:
  /// **'自动调课'**
  String get autoAdjustCourse;

  /// autoAdjustCourseDescription
  ///
  /// In zh, this message translates to:
  /// **'根据教务系统的调课记录调整课表。'**
  String get autoAdjustCourseDescription;

  /// evaluation
  ///
  /// In zh, this message translates to:
  /// **'一键评议'**
  String get evaluation;

  /// evaluationSubtitle
  ///
  /// In zh, this message translates to:
  /// **'批量评议任课教师'**
  String get evaluationSubtitle;

  /// noEvaluationData
  ///
  /// In zh, this message translates to:
  /// **'暂无待评议的课程'**
  String get noEvaluationData;

  /// evalTabXqxk
  ///
  /// In zh, this message translates to:
  /// **'学期选课'**
  String get evalTabXqxk;

  /// evalTabScore
  ///
  /// In zh, this message translates to:
  /// **'成绩查询'**
  String get evalTabScore;

  /// evalScoreHint
  ///
  /// In zh, this message translates to:
  /// **'百分制评分'**
  String get evalScoreHint;

  /// evalSelectComment
  ///
  /// In zh, this message translates to:
  /// **'选择评语'**
  String get evalSelectComment;

  /// evalCustomComment
  ///
  /// In zh, this message translates to:
  /// **'自己评价'**
  String get evalCustomComment;

  /// evalCustomHint
  ///
  /// In zh, this message translates to:
  /// **'来评价一下老师吧'**
  String get evalCustomHint;

  /// evalSubmit
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get evalSubmit;

  /// evalSubmitAll
  ///
  /// In zh, this message translates to:
  /// **'全部提交'**
  String get evalSubmitAll;

  /// evalFillCaptcha
  ///
  /// In zh, this message translates to:
  /// **'填写验证码'**
  String get evalFillCaptcha;

  /// evalCaptchaRequired
  ///
  /// In zh, this message translates to:
  /// **'验证码不能为空'**
  String get evalCaptchaRequired;

  /// evalCaptchaError
  ///
  /// In zh, this message translates to:
  /// **'验证码错误'**
  String get evalCaptchaError;

  /// evalSuccess
  ///
  /// In zh, this message translates to:
  /// **'评议成功！'**
  String get evalSuccess;

  /// No description provided for @evalScoreRequired.
  ///
  /// In zh, this message translates to:
  /// **'{course} 的评分未填写'**
  String evalScoreRequired(String course);

  /// No description provided for @evalCommentRequired.
  ///
  /// In zh, this message translates to:
  /// **'{course} 的评语未填写'**
  String evalCommentRequired(String course);

  /// evalRefreshCaptcha
  ///
  /// In zh, this message translates to:
  /// **'看不清，换一张'**
  String get evalRefreshCaptcha;

  /// evalNotAvailable
  ///
  /// In zh, this message translates to:
  /// **'当前没有待评议的课程，您已经完成全部课程的评议，或评议尚未开始。'**
  String get evalNotAvailable;

  /// evalNoFilled
  ///
  /// In zh, this message translates to:
  /// **'请先填写评议内容'**
  String get evalNoFilled;

  /// No description provided for @evalSubmitFailed.
  ///
  /// In zh, this message translates to:
  /// **'评议提交失败: {error}'**
  String evalSubmitFailed(String error);

  /// No description provided for @classPeriod.
  ///
  /// In zh, this message translates to:
  /// **'第 {period} 节'**
  String classPeriod(int period);

  /// No description provided for @classPeriodRange.
  ///
  /// In zh, this message translates to:
  /// **'第 {start}-{end} 节'**
  String classPeriodRange(int start, int end);

  /// No description provided for @adjustedMark.
  ///
  /// In zh, this message translates to:
  /// **'[调课]'**
  String get adjustedMark;

  /// No description provided for @windowMinimize.
  ///
  /// In zh, this message translates to:
  /// **'最小化'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In zh, this message translates to:
  /// **'最大化'**
  String get windowMaximize;

  /// No description provided for @windowRestore.
  ///
  /// In zh, this message translates to:
  /// **'还原窗口'**
  String get windowRestore;

  /// No description provided for @windowClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭窗口'**
  String get windowClose;

  /// No description provided for @profileInfo.
  ///
  /// In zh, this message translates to:
  /// **'个人资料'**
  String get profileInfo;

  /// No description provided for @scheduleMorning.
  ///
  /// In zh, this message translates to:
  /// **'上午'**
  String get scheduleMorning;

  /// No description provided for @scheduleAfternoon.
  ///
  /// In zh, this message translates to:
  /// **'下午'**
  String get scheduleAfternoon;

  /// No description provided for @scheduleEvening.
  ///
  /// In zh, this message translates to:
  /// **'晚上'**
  String get scheduleEvening;

  /// No description provided for @scheduleExamMark.
  ///
  /// In zh, this message translates to:
  /// **'[考试]'**
  String get scheduleExamMark;

  /// No description provided for @schedulePreviousWeek.
  ///
  /// In zh, this message translates to:
  /// **'上一周'**
  String get schedulePreviousWeek;

  /// No description provided for @scheduleNextWeek.
  ///
  /// In zh, this message translates to:
  /// **'下一周'**
  String get scheduleNextWeek;

  /// No description provided for @showNonCurrentWeekCourses.
  ///
  /// In zh, this message translates to:
  /// **'显示非本周课程'**
  String get showNonCurrentWeekCourses;

  /// No description provided for @showNonCurrentWeekCoursesDescription.
  ///
  /// In zh, this message translates to:
  /// **'在课表的空闲时段淡化显示非本周课程。'**
  String get showNonCurrentWeekCoursesDescription;

  /// No description provided for @nonCurrentWeekMark.
  ///
  /// In zh, this message translates to:
  /// **'[非本周]'**
  String get nonCurrentWeekMark;

  /// No description provided for @academicShortcuts.
  ///
  /// In zh, this message translates to:
  /// **'教务快捷入口'**
  String get academicShortcuts;

  /// No description provided for @academicShortcutsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选课、教务申请与嘉锡讲坛'**
  String get academicShortcutsSubtitle;

  /// No description provided for @courseSelection.
  ///
  /// In zh, this message translates to:
  /// **'选课'**
  String get courseSelection;

  /// No description provided for @campusElectiveSelection.
  ///
  /// In zh, this message translates to:
  /// **'校选课'**
  String get campusElectiveSelection;

  /// No description provided for @retakeSelection.
  ///
  /// In zh, this message translates to:
  /// **'重修选课'**
  String get retakeSelection;

  /// No description provided for @minorSelection.
  ///
  /// In zh, this message translates to:
  /// **'辅修选课'**
  String get minorSelection;

  /// No description provided for @academicApplications.
  ///
  /// In zh, this message translates to:
  /// **'教务申请'**
  String get academicApplications;

  /// No description provided for @majorTransferApplication.
  ///
  /// In zh, this message translates to:
  /// **'转专业申请'**
  String get majorTransferApplication;

  /// No description provided for @examDeferralApplication.
  ///
  /// In zh, this message translates to:
  /// **'缓考申请'**
  String get examDeferralApplication;

  /// No description provided for @courseExemptionApplication.
  ///
  /// In zh, this message translates to:
  /// **'免修申请'**
  String get courseExemptionApplication;

  /// No description provided for @minorApplication.
  ///
  /// In zh, this message translates to:
  /// **'辅修申请'**
  String get minorApplication;

  /// No description provided for @classroomApplication.
  ///
  /// In zh, this message translates to:
  /// **'教室申请'**
  String get classroomApplication;

  /// No description provided for @creditRecognition.
  ///
  /// In zh, this message translates to:
  /// **'学分认定'**
  String get creditRecognition;

  /// No description provided for @majorAllocation.
  ///
  /// In zh, this message translates to:
  /// **'大类分专业'**
  String get majorAllocation;

  /// No description provided for @electiveCreditConversion.
  ///
  /// In zh, this message translates to:
  /// **'选修转创拓'**
  String get electiveCreditConversion;

  /// No description provided for @jiaxiLectures.
  ///
  /// In zh, this message translates to:
  /// **'嘉锡讲坛'**
  String get jiaxiLectures;

  /// No description provided for @skipCourseSession.
  ///
  /// In zh, this message translates to:
  /// **'我不想上'**
  String get skipCourseSession;

  /// No description provided for @skipCourseSessionDescription.
  ///
  /// In zh, this message translates to:
  /// **'仅隐藏本周这一次课，可在课表设置中恢复。'**
  String get skipCourseSessionDescription;

  /// No description provided for @hiddenCourseSessions.
  ///
  /// In zh, this message translates to:
  /// **'不展示的课'**
  String get hiddenCourseSessions;

  /// No description provided for @hiddenCourseSessionsDescription.
  ///
  /// In zh, this message translates to:
  /// **'恢复课表中已隐藏的单次课程。'**
  String get hiddenCourseSessionsDescription;

  /// No description provided for @noHiddenCourseSessions.
  ///
  /// In zh, this message translates to:
  /// **'暂无不展示的课'**
  String get noHiddenCourseSessions;

  /// No description provided for @restoreCourseSession.
  ///
  /// In zh, this message translates to:
  /// **'恢复展示'**
  String get restoreCourseSession;

  /// No description provided for @restoreAllCourseSessions.
  ///
  /// In zh, this message translates to:
  /// **'全部恢复'**
  String get restoreAllCourseSessions;

  /// No description provided for @learningCenter.
  ///
  /// In zh, this message translates to:
  /// **'学习中心'**
  String get learningCenter;

  /// No description provided for @ssoLogin.
  ///
  /// In zh, this message translates to:
  /// **'统一身份认证登录'**
  String get ssoLogin;

  /// No description provided for @ssoLoginDescription.
  ///
  /// In zh, this message translates to:
  /// **'使用独立的统一认证账号登录校园服务，密码不在本机保存。'**
  String get ssoLoginDescription;

  /// No description provided for @ssoSmsVerification.
  ///
  /// In zh, this message translates to:
  /// **'手机验证'**
  String get ssoSmsVerification;

  /// No description provided for @ssoSendSms.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get ssoSendSms;

  /// No description provided for @ssoSmsSent.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送'**
  String get ssoSmsSent;

  /// No description provided for @ssoLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出统一认证'**
  String get ssoLogout;

  /// No description provided for @ssoLogoutDescription.
  ///
  /// In zh, this message translates to:
  /// **'退出统一认证、一码通和学习中心，保留教务登录。'**
  String get ssoLogoutDescription;

  /// No description provided for @ssoSessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'学习中心登录已过期，请重新登录后重试操作。'**
  String get ssoSessionExpired;

  /// No description provided for @learningReserve.
  ///
  /// In zh, this message translates to:
  /// **'预约座位'**
  String get learningReserve;

  /// No description provided for @learningReserveSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查询空闲座位，预约学习时段'**
  String get learningReserveSubtitle;

  /// No description provided for @learningAppointments.
  ///
  /// In zh, this message translates to:
  /// **'我的预约'**
  String get learningAppointments;

  /// No description provided for @learningInstructions.
  ///
  /// In zh, this message translates to:
  /// **'预约晋江楼 4–5 层的学习座位，到场扫码签到并在离开时签退。'**
  String get learningInstructions;

  /// No description provided for @learningCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get learningCancel;

  /// No description provided for @learningConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get learningConfirm;

  /// No description provided for @learningSelectPeriod.
  ///
  /// In zh, this message translates to:
  /// **'选择日期、时段和楼层（08:00–22:30，最多 4 小时）'**
  String get learningSelectPeriod;

  /// No description provided for @learningBegin.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get learningBegin;

  /// No description provided for @learningEnd.
  ///
  /// In zh, this message translates to:
  /// **'结束时间'**
  String get learningEnd;

  /// No description provided for @learningFloor.
  ///
  /// In zh, this message translates to:
  /// **'{floor} 层'**
  String learningFloor(String floor);

  /// No description provided for @learningSeatLabel.
  ///
  /// In zh, this message translates to:
  /// **'{floor} 层 · 座位 {seat}'**
  String learningSeatLabel(String floor, String seat);

  /// No description provided for @learningAvailable.
  ///
  /// In zh, this message translates to:
  /// **'空闲'**
  String get learningAvailable;

  /// No description provided for @learningOccupied.
  ///
  /// In zh, this message translates to:
  /// **'已占用'**
  String get learningOccupied;

  /// No description provided for @learningSeatTimes.
  ///
  /// In zh, this message translates to:
  /// **'座位当日可用时段'**
  String get learningSeatTimes;

  /// No description provided for @learningReserved.
  ///
  /// In zh, this message translates to:
  /// **'预约成功，请在「我的预约」查看并按时签到。'**
  String get learningReserved;

  /// No description provided for @learningSeatList.
  ///
  /// In zh, this message translates to:
  /// **'座位列表'**
  String get learningSeatList;

  /// No description provided for @learningSeatArea.
  ///
  /// In zh, this message translates to:
  /// **'{area}区'**
  String learningSeatArea(String area);

  /// No description provided for @learningOtherArea.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get learningOtherArea;

  /// No description provided for @learningSeatGuide.
  ///
  /// In zh, this message translates to:
  /// **'座位导览图'**
  String get learningSeatGuide;

  /// No description provided for @learningSingleSeat.
  ///
  /// In zh, this message translates to:
  /// **'单人座'**
  String get learningSingleSeat;

  /// No description provided for @learningSharedSeat.
  ///
  /// In zh, this message translates to:
  /// **'多人座'**
  String get learningSharedSeat;

  /// No description provided for @learningSofaSeat.
  ///
  /// In zh, this message translates to:
  /// **'沙发座'**
  String get learningSofaSeat;

  /// No description provided for @learningSharedAndSofaSeat.
  ///
  /// In zh, this message translates to:
  /// **'多人座、沙发座'**
  String get learningSharedAndSofaSeat;

  /// No description provided for @learningAreaSummary.
  ///
  /// In zh, this message translates to:
  /// **'空闲 {available} · 已占用 {occupied}'**
  String learningAreaSummary(int available, int occupied);

  /// No description provided for @learningNoSeats.
  ///
  /// In zh, this message translates to:
  /// **'未查询到座位，请更换时段或稍后重试。'**
  String get learningNoSeats;

  /// No description provided for @learningSeatLegend.
  ///
  /// In zh, this message translates to:
  /// **'浅色座位可预约；点击占用座位查看当日可用时段。'**
  String get learningSeatLegend;

  /// No description provided for @learningSignOut.
  ///
  /// In zh, this message translates to:
  /// **'签退'**
  String get learningSignOut;

  /// No description provided for @learningCancelAppointment.
  ///
  /// In zh, this message translates to:
  /// **'取消预约'**
  String get learningCancelAppointment;

  /// No description provided for @learningActionSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'操作成功'**
  String get learningActionSucceeded;

  /// No description provided for @learningUpcoming.
  ///
  /// In zh, this message translates to:
  /// **'未开始'**
  String get learningUpcoming;

  /// No description provided for @learningPending.
  ///
  /// In zh, this message translates to:
  /// **'待签到'**
  String get learningPending;

  /// No description provided for @learningSignedIn.
  ///
  /// In zh, this message translates to:
  /// **'已签到'**
  String get learningSignedIn;

  /// No description provided for @learningMissed.
  ///
  /// In zh, this message translates to:
  /// **'未签到'**
  String get learningMissed;

  /// No description provided for @learningCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get learningCancelled;

  /// No description provided for @learningCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get learningCompleted;

  /// No description provided for @learningUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知状态'**
  String get learningUnknown;

  /// No description provided for @learningAppointmentTitle.
  ///
  /// In zh, this message translates to:
  /// **'{floor} 层 {seat}'**
  String learningAppointmentTitle(String floor, String seat);

  /// No description provided for @learningNoAppointments.
  ///
  /// In zh, this message translates to:
  /// **'暂无预约记录'**
  String get learningNoAppointments;

  /// No description provided for @learningLoadMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多'**
  String get learningLoadMore;

  /// No description provided for @learningScanSignIn.
  ///
  /// In zh, this message translates to:
  /// **'扫码签到'**
  String get learningScanSignIn;

  /// No description provided for @learningScannerUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'此平台暂不支持相机扫码，请使用 Android、iOS 或 macOS 设备扫描现场二维码签到。'**
  String get learningScannerUnsupported;

  /// No description provided for @learningCameraError.
  ///
  /// In zh, this message translates to:
  /// **'无法使用相机，请检查系统相机权限后重新打开扫码页面。'**
  String get learningCameraError;

  /// No description provided for @learningInvalidQr.
  ///
  /// In zh, this message translates to:
  /// **'二维码无效或已过期，请扫描现场最新二维码。'**
  String get learningInvalidQr;

  /// No description provided for @learningScanHint.
  ///
  /// In zh, this message translates to:
  /// **'请扫描学习中心现场签到二维码'**
  String get learningScanHint;

  /// No description provided for @courseReminderTitle.
  ///
  /// In zh, this message translates to:
  /// **'明日课程提醒'**
  String get courseReminderTitle;

  /// No description provided for @courseReminderDescription.
  ///
  /// In zh, this message translates to:
  /// **'每天提醒明天最早的课程，无课时提醒休息。'**
  String get courseReminderDescription;

  /// No description provided for @courseReminderUnknown.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法确认明天的课程，请打开应用刷新课表和校历。'**
  String get courseReminderUnknown;

  /// No description provided for @courseReminderRest.
  ///
  /// In zh, this message translates to:
  /// **'明天没有课，好好休息吧！'**
  String get courseReminderRest;

  /// No description provided for @courseReminderCourse.
  ///
  /// In zh, this message translates to:
  /// **'明天最早 {time} · {course} · {location}'**
  String courseReminderCourse(String time, String course, String location);

  /// No description provided for @reminderTime.
  ///
  /// In zh, this message translates to:
  /// **'提醒时间'**
  String get reminderTime;

  /// No description provided for @reminderBeijingTime.
  ///
  /// In zh, this message translates to:
  /// **'北京时间 {time}'**
  String reminderBeijingTime(String time);

  /// No description provided for @reminderPermissionsRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先允许通知和精确闹钟，再开启提醒。'**
  String get reminderPermissionsRequired;

  /// No description provided for @reminderNotificationPermission.
  ///
  /// In zh, this message translates to:
  /// **'通知权限'**
  String get reminderNotificationPermission;

  /// No description provided for @reminderExactPermission.
  ///
  /// In zh, this message translates to:
  /// **'精确闹钟权限'**
  String get reminderExactPermission;

  /// No description provided for @reminderPermissionGranted.
  ///
  /// In zh, this message translates to:
  /// **'已允许，点击管理系统权限'**
  String get reminderPermissionGranted;

  /// No description provided for @reminderPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'未允许，点击前往系统设置'**
  String get reminderPermissionDenied;

  /// No description provided for @reminderPermissionLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取权限'**
  String get reminderPermissionLoading;

  /// No description provided for @reminderFailed.
  ///
  /// In zh, this message translates to:
  /// **'提醒设置失败，请检查权限后重试。'**
  String get reminderFailed;

  /// No description provided for @permissionManagement.
  ///
  /// In zh, this message translates to:
  /// **'权限管理'**
  String get permissionManagement;

  /// No description provided for @permissionManagementSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看应用需要的权限和授权状态'**
  String get permissionManagementSubtitle;

  /// No description provided for @permissionManagementDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看权限用途与授权状态，点击进入系统管理。'**
  String get permissionManagementDescription;

  /// No description provided for @appPermissionSettings.
  ///
  /// In zh, this message translates to:
  /// **'应用系统设置'**
  String get appPermissionSettings;

  /// No description provided for @permissionSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开系统权限设置，请重试。'**
  String get permissionSettingsFailed;

  /// No description provided for @permissionLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取应用权限，请重试。'**
  String get permissionLoadFailed;

  /// No description provided for @permissionAllowed.
  ///
  /// In zh, this message translates to:
  /// **'已允许'**
  String get permissionAllowed;

  /// No description provided for @permissionNotAllowed.
  ///
  /// In zh, this message translates to:
  /// **'未允许'**
  String get permissionNotAllowed;

  /// No description provided for @permissionSpecial.
  ///
  /// In zh, this message translates to:
  /// **'特殊访问权限'**
  String get permissionSpecial;

  /// No description provided for @permissionRuntime.
  ///
  /// In zh, this message translates to:
  /// **'运行时权限'**
  String get permissionRuntime;

  /// No description provided for @permissionInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装时权限'**
  String get permissionInstall;

  /// No description provided for @reminderNotificationStyle.
  ///
  /// In zh, this message translates to:
  /// **'锁屏与通知样式'**
  String get reminderNotificationStyle;

  /// No description provided for @reminderNotificationStyleDescription.
  ///
  /// In zh, this message translates to:
  /// **'管理课程提醒的锁屏显示、声音与横幅。'**
  String get reminderNotificationStyleDescription;

  /// No description provided for @permissionPurposeNotifications.
  ///
  /// In zh, this message translates to:
  /// **'发送课程与定时任务通知'**
  String get permissionPurposeNotifications;

  /// No description provided for @permissionPurposeAlarms.
  ///
  /// In zh, this message translates to:
  /// **'按设定时间执行后台任务'**
  String get permissionPurposeAlarms;

  /// No description provided for @permissionPurposeCamera.
  ///
  /// In zh, this message translates to:
  /// **'扫描学习中心签到二维码'**
  String get permissionPurposeCamera;

  /// No description provided for @permissionPurposeInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装应用更新'**
  String get permissionPurposeInstall;

  /// No description provided for @permissionPurposeInternet.
  ///
  /// In zh, this message translates to:
  /// **'联网获取课表、成绩和校园服务数据'**
  String get permissionPurposeInternet;

  /// No description provided for @permissionPurposeWake.
  ///
  /// In zh, this message translates to:
  /// **'后台任务执行时保持设备唤醒'**
  String get permissionPurposeWake;

  /// No description provided for @permissionPurposeBoot.
  ///
  /// In zh, this message translates to:
  /// **'设备重启后恢复定时任务'**
  String get permissionPurposeBoot;

  /// No description provided for @courseReminderSettings.
  ///
  /// In zh, this message translates to:
  /// **'早课提醒'**
  String get courseReminderSettings;

  /// No description provided for @courseReminderSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'每天晚上提醒明天最早的课程'**
  String get courseReminderSettingsSubtitle;

  /// No description provided for @permissionNameNotifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get permissionNameNotifications;

  /// No description provided for @permissionNameAlarms.
  ///
  /// In zh, this message translates to:
  /// **'精确闹钟'**
  String get permissionNameAlarms;

  /// No description provided for @permissionNameCamera.
  ///
  /// In zh, this message translates to:
  /// **'相机'**
  String get permissionNameCamera;

  /// No description provided for @permissionNameInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装应用'**
  String get permissionNameInstall;

  /// No description provided for @permissionNameInternet.
  ///
  /// In zh, this message translates to:
  /// **'网络访问'**
  String get permissionNameInternet;

  /// No description provided for @permissionNameWake.
  ///
  /// In zh, this message translates to:
  /// **'保持唤醒'**
  String get permissionNameWake;

  /// No description provided for @permissionNameBoot.
  ///
  /// In zh, this message translates to:
  /// **'接收开机通知'**
  String get permissionNameBoot;

  /// No description provided for @thirdPartyServices.
  ///
  /// In zh, this message translates to:
  /// **'第三方服务'**
  String get thirdPartyServices;

  /// No description provided for @thirdPartyDescription.
  ///
  /// In zh, this message translates to:
  /// **'按功能选择隐藏、询问或开启西二在线服务。'**
  String get thirdPartyDescription;

  /// No description provided for @thirdPartyDisabled.
  ///
  /// In zh, this message translates to:
  /// **'尚未启用，请前往第三方服务设置'**
  String get thirdPartyDisabled;

  /// No description provided for @accessTip.
  ///
  /// In zh, this message translates to:
  /// **'询问'**
  String get accessTip;

  /// No description provided for @accessAllow.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get accessAllow;

  /// No description provided for @accessHide.
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get accessHide;

  /// No description provided for @pastPapers.
  ///
  /// In zh, this message translates to:
  /// **'历年卷'**
  String get pastPapers;

  /// No description provided for @pastPapersDescription.
  ///
  /// In zh, this message translates to:
  /// **'从西二在线获取历年试卷目录与下载链接。'**
  String get pastPapersDescription;

  /// No description provided for @campusServices.
  ///
  /// In zh, this message translates to:
  /// **'校园服务'**
  String get campusServices;

  /// No description provided for @campusServicesDescription.
  ///
  /// In zh, this message translates to:
  /// **'按需打开学校官方服务；需要登录的服务复用统一身份认证。'**
  String get campusServicesDescription;

  /// No description provided for @campusDormRepair.
  ///
  /// In zh, this message translates to:
  /// **'公寓报修'**
  String get campusDormRepair;

  /// No description provided for @campusReservations.
  ///
  /// In zh, this message translates to:
  /// **'综合预约'**
  String get campusReservations;

  /// No description provided for @campusLibraryReservation.
  ///
  /// In zh, this message translates to:
  /// **'图书馆预约'**
  String get campusLibraryReservation;

  /// No description provided for @campusLostAndFound.
  ///
  /// In zh, this message translates to:
  /// **'失物招领'**
  String get campusLostAndFound;

  /// No description provided for @campusAttendance.
  ///
  /// In zh, this message translates to:
  /// **'晚点名签到'**
  String get campusAttendance;

  /// No description provided for @campusElectricBike.
  ///
  /// In zh, this message translates to:
  /// **'电动车管理'**
  String get campusElectricBike;

  /// No description provided for @campusYiban.
  ///
  /// In zh, this message translates to:
  /// **'校本化（易班）'**
  String get campusYiban;

  /// No description provided for @webViewLoadError.
  ///
  /// In zh, this message translates to:
  /// **'网页加载失败'**
  String get webViewLoadError;

  /// No description provided for @customCourses.
  ///
  /// In zh, this message translates to:
  /// **'自定义课程'**
  String get customCourses;

  /// No description provided for @customCoursesDescription.
  ///
  /// In zh, this message translates to:
  /// **'管理当前账号各学期的自定义课程。'**
  String get customCoursesDescription;

  /// No description provided for @customCoursesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前学期暂无自定义课程'**
  String get customCoursesEmpty;

  /// No description provided for @customCourseAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加课程'**
  String get customCourseAdd;

  /// No description provided for @customCourseEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑课程'**
  String get customCourseEdit;

  /// No description provided for @customCourseDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除课程'**
  String get customCourseDelete;

  /// No description provided for @customCourseSave.
  ///
  /// In zh, this message translates to:
  /// **'保存课程'**
  String get customCourseSave;

  /// No description provided for @customCourseName.
  ///
  /// In zh, this message translates to:
  /// **'课程名称'**
  String get customCourseName;

  /// No description provided for @customCourseTeacher.
  ///
  /// In zh, this message translates to:
  /// **'教师（选填）'**
  String get customCourseTeacher;

  /// No description provided for @customCourseLocation.
  ///
  /// In zh, this message translates to:
  /// **'地点（选填）'**
  String get customCourseLocation;

  /// No description provided for @customCourseRemark.
  ///
  /// In zh, this message translates to:
  /// **'备注（选填）'**
  String get customCourseRemark;

  /// No description provided for @customCourseWeekday.
  ///
  /// In zh, this message translates to:
  /// **'星期'**
  String get customCourseWeekday;

  /// No description provided for @customCourseStartWeek.
  ///
  /// In zh, this message translates to:
  /// **'起始周'**
  String get customCourseStartWeek;

  /// No description provided for @customCourseEndWeek.
  ///
  /// In zh, this message translates to:
  /// **'结束周'**
  String get customCourseEndWeek;

  /// No description provided for @customCourseRepeat.
  ///
  /// In zh, this message translates to:
  /// **'重复方式'**
  String get customCourseRepeat;

  /// No description provided for @customCourseEveryWeek.
  ///
  /// In zh, this message translates to:
  /// **'每周'**
  String get customCourseEveryWeek;

  /// No description provided for @customCourseOddWeeks.
  ///
  /// In zh, this message translates to:
  /// **'单周'**
  String get customCourseOddWeeks;

  /// No description provided for @customCourseEvenWeeks.
  ///
  /// In zh, this message translates to:
  /// **'双周'**
  String get customCourseEvenWeeks;

  /// No description provided for @customCourseColor.
  ///
  /// In zh, this message translates to:
  /// **'课程颜色'**
  String get customCourseColor;

  /// No description provided for @customCourseNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入课程名称'**
  String get customCourseNameRequired;

  /// No description provided for @customCourseTermHint.
  ///
  /// In zh, this message translates to:
  /// **'六位学期编号，例如 202601'**
  String get customCourseTermHint;

  /// No description provided for @customCourseTermInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入六位学期编号'**
  String get customCourseTermInvalid;

  /// No description provided for @customCourseRangeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'结束周或结束节次不能早于起始值'**
  String get customCourseRangeInvalid;

  /// No description provided for @customCourseLoginRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先登录教务账号后管理课程'**
  String get customCourseLoginRequired;

  /// No description provided for @webdavAutoSync.
  ///
  /// In zh, this message translates to:
  /// **'每次打开自动同步'**
  String get webdavAutoSync;

  /// No description provided for @webdavAutoSyncDescription.
  ///
  /// In zh, this message translates to:
  /// **'开启后在启动或返回应用时同步，两端都有改动时请手动选择。'**
  String get webdavAutoSyncDescription;

  /// No description provided for @webdavAutoSyncConflict.
  ///
  /// In zh, this message translates to:
  /// **'两端数据不同，请前往 WebDAV 手动上传或下载。'**
  String get webdavAutoSyncConflict;

  /// No description provided for @webdavAutoSyncManualUpload.
  ///
  /// In zh, this message translates to:
  /// **'服务器不支持防冲突覆盖，请前往 WebDAV 手动上传。'**
  String get webdavAutoSyncManualUpload;

  /// No description provided for @webdavAutoSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'自动同步失败，请在 WebDAV 设置中检查连接。'**
  String get webdavAutoSyncFailed;

  /// No description provided for @webdavTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get webdavTestConnection;

  /// No description provided for @webdavTestDescription.
  ///
  /// In zh, this message translates to:
  /// **'测试会自动创建缺失目录，并临时写入、读取及删除一个文件。'**
  String get webdavTestDescription;

  /// No description provided for @webdavConnectionValid.
  ///
  /// In zh, this message translates to:
  /// **'连接有效，目录可读写且测试文件已清理。'**
  String get webdavConnectionValid;

  /// No description provided for @webdavSync.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 同步'**
  String get webdavSync;

  /// No description provided for @webdavDescription.
  ///
  /// In zh, this message translates to:
  /// **'通过 WebDAV 同步设置及课程记录，不含登录信息与缓存。'**
  String get webdavDescription;

  /// No description provided for @webdavDirectory.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 目录地址'**
  String get webdavDirectory;

  /// No description provided for @webdavDirectoryHint.
  ///
  /// In zh, this message translates to:
  /// **'填写同步目录地址，上传时会自动创建缺失的文件夹。'**
  String get webdavDirectoryHint;

  /// No description provided for @webdavUsername.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 用户名'**
  String get webdavUsername;

  /// No description provided for @webdavSave.
  ///
  /// In zh, this message translates to:
  /// **'保存配置'**
  String get webdavSave;

  /// No description provided for @webdavSaved.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 配置已保存'**
  String get webdavSaved;

  /// No description provided for @webdavUpload.
  ///
  /// In zh, this message translates to:
  /// **'上传到 WebDAV'**
  String get webdavUpload;

  /// No description provided for @webdavDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载并覆盖本地'**
  String get webdavDownload;

  /// No description provided for @webdavUploaded.
  ///
  /// In zh, this message translates to:
  /// **'同步数据已上传'**
  String get webdavUploaded;

  /// No description provided for @webdavDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'设置和课程记录已恢复'**
  String get webdavDownloaded;

  /// No description provided for @webdavCreateDescription.
  ///
  /// In zh, this message translates to:
  /// **'将当前设置和课程记录上传到此目录？'**
  String get webdavCreateDescription;

  /// No description provided for @webdavUploadDescription.
  ///
  /// In zh, this message translates to:
  /// **'用当前设备的数据覆盖远端备份？'**
  String get webdavUploadDescription;

  /// No description provided for @webdavDownloadDescription.
  ///
  /// In zh, this message translates to:
  /// **'用备份覆盖本地设置和所有账号的自定义及隐藏课程记录，保留登录状态？'**
  String get webdavDownloadDescription;

  /// No description provided for @webdavRemoteUpdated.
  ///
  /// In zh, this message translates to:
  /// **'备份时间'**
  String get webdavRemoteUpdated;

  /// No description provided for @webdavCustomCourses.
  ///
  /// In zh, this message translates to:
  /// **'自定义课程数'**
  String get webdavCustomCourses;

  /// No description provided for @webdavHiddenCourses.
  ///
  /// In zh, this message translates to:
  /// **'隐藏课程记录数'**
  String get webdavHiddenCourses;

  /// No description provided for @webdavNotFound.
  ///
  /// In zh, this message translates to:
  /// **'远端没有同步文件，请先上传'**
  String get webdavNotFound;

  /// No description provided for @webdavCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get webdavCancel;

  /// No description provided for @webdavConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get webdavConfirm;

  /// No description provided for @cultivatePlan.
  ///
  /// In zh, this message translates to:
  /// **'培养计划'**
  String get cultivatePlan;

  /// No description provided for @cultivatePlanDescription.
  ///
  /// In zh, this message translates to:
  /// **'按年级、学院和专业查找教务处培养方案'**
  String get cultivatePlanDescription;

  /// No description provided for @selectPlanManually.
  ///
  /// In zh, this message translates to:
  /// **'在教务处手动选择培养计划'**
  String get selectPlanManually;

  /// No description provided for @studentCardServices.
  ///
  /// In zh, this message translates to:
  /// **'学生证与附卡'**
  String get studentCardServices;

  /// No description provided for @replaceStudentCard.
  ///
  /// In zh, this message translates to:
  /// **'补办学生证'**
  String get replaceStudentCard;

  /// No description provided for @replaceSupplementaryCard.
  ///
  /// In zh, this message translates to:
  /// **'补办附卡'**
  String get replaceSupplementaryCard;

  /// No description provided for @changeTravelRoute.
  ///
  /// In zh, this message translates to:
  /// **'更改乘车区间'**
  String get changeTravelRoute;

  /// No description provided for @graduationProject.
  ///
  /// In zh, this message translates to:
  /// **'毕业设计（论文）'**
  String get graduationProject;

  /// No description provided for @papersHidden.
  ///
  /// In zh, this message translates to:
  /// **'历年卷入口已隐藏'**
  String get papersHidden;

  /// No description provided for @papersSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索当前目录'**
  String get papersSearch;

  /// No description provided for @papersRoot.
  ///
  /// In zh, this message translates to:
  /// **'试卷根目录'**
  String get papersRoot;

  /// No description provided for @papersParent.
  ///
  /// In zh, this message translates to:
  /// **'返回上一级目录'**
  String get papersParent;

  /// No description provided for @papersEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前目录没有匹配的试卷或文件夹'**
  String get papersEmpty;

  /// No description provided for @papersOpenDescription.
  ///
  /// In zh, this message translates to:
  /// **'在浏览器查看或下载试卷，也可复制下载链接。'**
  String get papersOpenDescription;

  /// No description provided for @papersOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开浏览器，请复制链接后手动打开'**
  String get papersOpenFailed;

  /// No description provided for @utilityPayment.
  ///
  /// In zh, this message translates to:
  /// **'水电缴费'**
  String get utilityPayment;

  /// No description provided for @utilityDescription.
  ///
  /// In zh, this message translates to:
  /// **'选择校区后跳转建行 App 查询和缴纳宿舍水电费。'**
  String get utilityDescription;

  /// No description provided for @utilityMobileRequired.
  ///
  /// In zh, this message translates to:
  /// **'宿舍水电缴费需要手机上的中国建设银行 App，请在 Android 或 iPhone 上使用此功能。'**
  String get utilityMobileRequired;

  /// No description provided for @utilityCampusQishan.
  ///
  /// In zh, this message translates to:
  /// **'旗山校区'**
  String get utilityCampusQishan;

  /// No description provided for @utilityCampusTongpan.
  ///
  /// In zh, this message translates to:
  /// **'铜盘校区'**
  String get utilityCampusTongpan;

  /// No description provided for @utilityCampusJinjiang.
  ///
  /// In zh, this message translates to:
  /// **'晋江校区'**
  String get utilityCampusJinjiang;

  /// No description provided for @utilityCampusYishan.
  ///
  /// In zh, this message translates to:
  /// **'怡山校区'**
  String get utilityCampusYishan;

  /// No description provided for @utilityOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开建设银行 App'**
  String get utilityOpenFailed;

  /// No description provided for @utilityInstallDescription.
  ///
  /// In zh, this message translates to:
  /// **'请安装建行 App，或复制缴费链接后重试。'**
  String get utilityInstallDescription;

  /// No description provided for @utilityClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get utilityClose;

  /// No description provided for @utilityCopyLink.
  ///
  /// In zh, this message translates to:
  /// **'复制缴费链接'**
  String get utilityCopyLink;

  /// No description provided for @utilityCopied.
  ///
  /// In zh, this message translates to:
  /// **'缴费链接已复制'**
  String get utilityCopied;

  /// No description provided for @utilityInstall.
  ///
  /// In zh, this message translates to:
  /// **'下载建行 App'**
  String get utilityInstall;

  /// No description provided for @utilityDownloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开下载页面，请前往应用商店搜索中国建设银行'**
  String get utilityDownloadFailed;

  /// No description provided for @reminderXiaomiNotice.
  ///
  /// In zh, this message translates to:
  /// **'系统限制提醒'**
  String get reminderXiaomiNotice;

  /// No description provided for @reminderXiaomiDescription.
  ///
  /// In zh, this message translates to:
  /// **'由于 MIUI / HyperOS 限制了应用在后台推送本地通知，该功能不可用，您可尝试在 root 后解锁此限制。'**
  String get reminderXiaomiDescription;

  /// No description provided for @gradesSummaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'学期汇总'**
  String get gradesSummaryTitle;

  /// No description provided for @gradesSummaryTotalCredits.
  ///
  /// In zh, this message translates to:
  /// **'总修学分'**
  String get gradesSummaryTotalCredits;

  /// No description provided for @gradesSummaryHighestScore.
  ///
  /// In zh, this message translates to:
  /// **'单科最高'**
  String get gradesSummaryHighestScore;

  /// No description provided for @gradesSummaryEstimatedGpa.
  ///
  /// In zh, this message translates to:
  /// **'估算 GPA'**
  String get gradesSummaryEstimatedGpa;

  /// No description provided for @gradesSummaryMissingValue.
  ///
  /// In zh, this message translates to:
  /// **'缺失'**
  String get gradesSummaryMissingValue;

  /// No description provided for @gradesSummaryNoGpa.
  ///
  /// In zh, this message translates to:
  /// **'无适用课程'**
  String get gradesSummaryNoGpa;

  /// No description provided for @gradesSummaryIncompleteGpa.
  ///
  /// In zh, this message translates to:
  /// **'部分课程的学分或绩点缺失，暂无法估算。'**
  String get gradesSummaryIncompleteGpa;

  /// No description provided for @gradesSummaryIncompleteCredits.
  ///
  /// In zh, this message translates to:
  /// **'部分课程学分缺失，总修学分仅统计已知值。'**
  String get gradesSummaryIncompleteCredits;

  /// No description provided for @gradesSummaryGpaNote.
  ///
  /// In zh, this message translates to:
  /// **'按课程学分加权，仅供参考，以教务处为准。'**
  String get gradesSummaryGpaNote;

  /// No description provided for @gradesSummaryRules.
  ///
  /// In zh, this message translates to:
  /// **'已出分的补考替代原记录，同一课程不重复计学分；不计绩点类别、二专业和两级制课程不参与 GPA。'**
  String get gradesSummaryRules;

  /// No description provided for @gradesMissingGpa.
  ///
  /// In zh, this message translates to:
  /// **'绩点缺失'**
  String get gradesMissingGpa;

  /// No description provided for @campusServicesLife.
  ///
  /// In zh, this message translates to:
  /// **'生活与住宿'**
  String get campusServicesLife;

  /// No description provided for @campusServicesBookings.
  ///
  /// In zh, this message translates to:
  /// **'空间与预约'**
  String get campusServicesBookings;

  /// No description provided for @campusServicesGrowth.
  ///
  /// In zh, this message translates to:
  /// **'学习与活动'**
  String get campusServicesGrowth;

  /// No description provided for @campusServicesOffice.
  ///
  /// In zh, this message translates to:
  /// **'信息与办事'**
  String get campusServicesOffice;

  /// No description provided for @campusServicesNetwork.
  ///
  /// In zh, this message translates to:
  /// **'地图与校园网'**
  String get campusServicesNetwork;

  /// No description provided for @campusDormRepairDescription.
  ///
  /// In zh, this message translates to:
  /// **'提交公寓设施报修，查看维修进度。'**
  String get campusDormRepairDescription;

  /// No description provided for @campusReservationsDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入学校综合预约平台办理预约。'**
  String get campusReservationsDescription;

  /// No description provided for @campusLibraryReservationDescription.
  ///
  /// In zh, this message translates to:
  /// **'查询并预约图书馆座位。'**
  String get campusLibraryReservationDescription;

  /// No description provided for @campusLostAndFoundDescription.
  ///
  /// In zh, this message translates to:
  /// **'发布和查找校园失物招领信息。'**
  String get campusLostAndFoundDescription;

  /// No description provided for @campusAttendanceDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入晚点名平台完成签到。'**
  String get campusAttendanceDescription;

  /// No description provided for @campusElectricBikeDescription.
  ///
  /// In zh, this message translates to:
  /// **'办理校园电动车相关管理业务。'**
  String get campusElectricBikeDescription;

  /// No description provided for @campusYibanDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入校本化易班校园服务。'**
  String get campusYibanDescription;

  /// No description provided for @campusMailbox.
  ///
  /// In zh, this message translates to:
  /// **'福大邮箱'**
  String get campusMailbox;

  /// No description provided for @campusMailboxDescription.
  ///
  /// In zh, this message translates to:
  /// **'开通和使用学校提供的电子邮箱。'**
  String get campusMailboxDescription;

  /// No description provided for @campusQuickResponse.
  ///
  /// In zh, this message translates to:
  /// **'马上就办'**
  String get campusQuickResponse;

  /// No description provided for @campusQuickResponseDescription.
  ///
  /// In zh, this message translates to:
  /// **'提交校园诉求和意见建议。'**
  String get campusQuickResponseDescription;

  /// No description provided for @campusTrustedDocuments.
  ///
  /// In zh, this message translates to:
  /// **'可信电子文档'**
  String get campusTrustedDocuments;

  /// No description provided for @campusTrustedDocumentsDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入学校可信电子文档系统办理业务。'**
  String get campusTrustedDocumentsDescription;

  /// No description provided for @campusOfficialNotices.
  ///
  /// In zh, this message translates to:
  /// **'通知文件系统'**
  String get campusOfficialNotices;

  /// No description provided for @campusOfficialNoticesDescription.
  ///
  /// In zh, this message translates to:
  /// **'浏览学校发布的通知和文件。'**
  String get campusOfficialNoticesDescription;

  /// No description provided for @campusYouthLeague.
  ///
  /// In zh, this message translates to:
  /// **'团委管理服务'**
  String get campusYouthLeague;

  /// No description provided for @campusYouthLeagueDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入团委管理服务平台办理团务。'**
  String get campusYouthLeagueDescription;

  /// No description provided for @campusStudentAffairs.
  ///
  /// In zh, this message translates to:
  /// **'一站式智慧学工'**
  String get campusStudentAffairs;

  /// No description provided for @campusStudentAffairsDescription.
  ///
  /// In zh, this message translates to:
  /// **'办理学生事务并查看学工服务。'**
  String get campusStudentAffairsDescription;

  /// No description provided for @campusLectureReports.
  ///
  /// In zh, this message translates to:
  /// **'讲座报告'**
  String get campusLectureReports;

  /// No description provided for @campusLectureReportsDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看学校公开发布的讲座与报告。'**
  String get campusLectureReportsDescription;

  /// No description provided for @campusCertifications.
  ///
  /// In zh, this message translates to:
  /// **'考证信息'**
  String get campusCertifications;

  /// No description provided for @campusCertificationsDescription.
  ///
  /// In zh, this message translates to:
  /// **'查询校园考证和资格考试信息。'**
  String get campusCertificationsDescription;

  /// No description provided for @campusElectricBikeRegistration.
  ///
  /// In zh, this message translates to:
  /// **'电动车登记'**
  String get campusElectricBikeRegistration;

  /// No description provided for @campusElectricBikeRegistrationDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入学校电动车登记系统。'**
  String get campusElectricBikeRegistrationDescription;

  /// No description provided for @campusUnifiedPayment.
  ///
  /// In zh, this message translates to:
  /// **'统一支付'**
  String get campusUnifiedPayment;

  /// No description provided for @campusUnifiedPaymentDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入学校统一支付平台办理缴费。'**
  String get campusUnifiedPaymentDescription;

  /// No description provided for @campusCardServices.
  ///
  /// In zh, this message translates to:
  /// **'一卡通服务'**
  String get campusCardServices;

  /// No description provided for @campusCardServicesDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入学校一卡通服务平台。'**
  String get campusCardServicesDescription;

  /// No description provided for @campusForms.
  ///
  /// In zh, this message translates to:
  /// **'一表通'**
  String get campusForms;

  /// No description provided for @campusFormsDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入学校一表通平台填报表单。'**
  String get campusFormsDescription;

  /// No description provided for @campusResume.
  ///
  /// In zh, this message translates to:
  /// **'个人简历'**
  String get campusResume;

  /// No description provided for @campusResumeDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看和维护校园服务中的个人简历。'**
  String get campusResumeDescription;

  /// No description provided for @campusVenueReservation.
  ///
  /// In zh, this message translates to:
  /// **'场地预约'**
  String get campusVenueReservation;

  /// No description provided for @campusVenueReservationDescription.
  ///
  /// In zh, this message translates to:
  /// **'查询和预约学校开放的场地。'**
  String get campusVenueReservationDescription;

  /// No description provided for @campusNewStudentServices.
  ///
  /// In zh, this message translates to:
  /// **'迎新服务'**
  String get campusNewStudentServices;

  /// No description provided for @campusNewStudentServicesDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看新生报到及迎新办理事项。'**
  String get campusNewStudentServicesDescription;

  /// No description provided for @campusIdentityVerification.
  ///
  /// In zh, this message translates to:
  /// **'实名身份核验'**
  String get campusIdentityVerification;

  /// No description provided for @campusIdentityVerificationDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入学校实名身份核验服务。'**
  String get campusIdentityVerificationDescription;

  /// No description provided for @campusMap.
  ///
  /// In zh, this message translates to:
  /// **'校园地图'**
  String get campusMap;

  /// No description provided for @campusMapDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看校园地图并查找校内地点。'**
  String get campusMapDescription;

  /// No description provided for @campusActivities.
  ///
  /// In zh, this message translates to:
  /// **'校园活动'**
  String get campusActivities;

  /// No description provided for @campusActivitiesDescription.
  ///
  /// In zh, this message translates to:
  /// **'浏览校园活动并查看活动详情。'**
  String get campusActivitiesDescription;

  /// No description provided for @campusSavedActivities.
  ///
  /// In zh, this message translates to:
  /// **'校园活动收藏'**
  String get campusSavedActivities;

  /// No description provided for @campusSavedActivitiesDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看已收藏的校园活动。'**
  String get campusSavedActivitiesDescription;

  /// No description provided for @campusNetworkRepair.
  ///
  /// In zh, this message translates to:
  /// **'校园网报修'**
  String get campusNetworkRepair;

  /// No description provided for @campusNetworkRepairDescription.
  ///
  /// In zh, this message translates to:
  /// **'提交校园网络故障报修。'**
  String get campusNetworkRepairDescription;

  /// No description provided for @campusNetworkGuide.
  ///
  /// In zh, this message translates to:
  /// **'校园网接入指南'**
  String get campusNetworkGuide;

  /// No description provided for @campusNetworkGuideDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看校园网络接入说明。'**
  String get campusNetworkGuideDescription;

  /// No description provided for @campusReturnReservation.
  ///
  /// In zh, this message translates to:
  /// **'集体返校预约'**
  String get campusReturnReservation;

  /// No description provided for @campusReturnReservationDescription.
  ///
  /// In zh, this message translates to:
  /// **'办理集体返校相关预约。'**
  String get campusReturnReservationDescription;

  /// No description provided for @campusPartyTraining.
  ///
  /// In zh, this message translates to:
  /// **'党员培训'**
  String get campusPartyTraining;

  /// No description provided for @campusPartyTrainingDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入学校党员培训平台学习。'**
  String get campusPartyTrainingDescription;

  /// No description provided for @campusAccommodation.
  ///
  /// In zh, this message translates to:
  /// **'住宿服务申请'**
  String get campusAccommodation;

  /// No description provided for @campusAccommodationDescription.
  ///
  /// In zh, this message translates to:
  /// **'提交住宿服务相关申请。'**
  String get campusAccommodationDescription;

  /// No description provided for @jobFairTitle.
  ///
  /// In zh, this message translates to:
  /// **'招聘会／宣讲会'**
  String get jobFairTitle;

  /// No description provided for @jobFairDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看学校发布的招聘活动，时间均为北京时间。'**
  String get jobFairDescription;

  /// No description provided for @jobFairPreviousMonth.
  ///
  /// In zh, this message translates to:
  /// **'上个月'**
  String get jobFairPreviousMonth;

  /// No description provided for @jobFairNextMonth.
  ///
  /// In zh, this message translates to:
  /// **'下个月'**
  String get jobFairNextMonth;

  /// No description provided for @jobFairCurrentMonth.
  ///
  /// In zh, this message translates to:
  /// **'回到本月'**
  String get jobFairCurrentMonth;

  /// No description provided for @jobFairSelectMonth.
  ///
  /// In zh, this message translates to:
  /// **'选择月份'**
  String get jobFairSelectMonth;

  /// No description provided for @jobFairUpcoming.
  ///
  /// In zh, this message translates to:
  /// **'未开始'**
  String get jobFairUpcoming;

  /// No description provided for @jobFairPast.
  ///
  /// In zh, this message translates to:
  /// **'往期活动'**
  String get jobFairPast;

  /// No description provided for @jobFairRecruitment.
  ///
  /// In zh, this message translates to:
  /// **'招聘会'**
  String get jobFairRecruitment;

  /// No description provided for @jobFairKeynote.
  ///
  /// In zh, this message translates to:
  /// **'宣讲会'**
  String get jobFairKeynote;

  /// No description provided for @jobFairNoEvents.
  ///
  /// In zh, this message translates to:
  /// **'本月暂无招聘会或宣讲会'**
  String get jobFairNoEvents;

  /// No description provided for @jobFairUnknownTitle.
  ///
  /// In zh, this message translates to:
  /// **'未公布活动名称'**
  String get jobFairUnknownTitle;

  /// No description provided for @jobFairUnknownPlace.
  ///
  /// In zh, this message translates to:
  /// **'地点待公布'**
  String get jobFairUnknownPlace;

  /// No description provided for @jobFairLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'招聘活动加载失败，请重试。'**
  String get jobFairLoadFailed;

  /// No description provided for @jobFairRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'刷新失败，仍显示上次加载的活动。'**
  String get jobFairRefreshFailed;

  /// No description provided for @jobFairInvalidDetails.
  ///
  /// In zh, this message translates to:
  /// **'该活动的官方详情地址无效。'**
  String get jobFairInvalidDetails;

  /// No description provided for @jobFairShowingPreviousMonth.
  ///
  /// In zh, this message translates to:
  /// **'月份加载失败，仍显示上次成功加载的月份。'**
  String get jobFairShowingPreviousMonth;

  /// No description provided for @jobFairPartialData.
  ///
  /// In zh, this message translates to:
  /// **'部分活动格式异常，已略过，请以官方公告为准。'**
  String get jobFairPartialData;

  /// No description provided for @lecturesDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看已报名讲座及出勤情况，报名请前往教务处官方页面。'**
  String get lecturesDescription;

  /// No description provided for @lecturesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无已报名讲座'**
  String get lecturesEmpty;

  /// No description provided for @lecturesOpenOfficial.
  ///
  /// In zh, this message translates to:
  /// **'打开官方页面报名 / 查看'**
  String get lecturesOpenOfficial;

  /// No description provided for @lectureCategory.
  ///
  /// In zh, this message translates to:
  /// **'类别'**
  String get lectureCategory;

  /// No description provided for @lectureIssueNumber.
  ///
  /// In zh, this message translates to:
  /// **'期数'**
  String get lectureIssueNumber;

  /// No description provided for @lectureSpeaker.
  ///
  /// In zh, this message translates to:
  /// **'主讲人'**
  String get lectureSpeaker;

  /// No description provided for @lectureDateTime.
  ///
  /// In zh, this message translates to:
  /// **'时间（北京）'**
  String get lectureDateTime;

  /// No description provided for @lectureLocation.
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get lectureLocation;

  /// No description provided for @lectureAttendance.
  ///
  /// In zh, this message translates to:
  /// **'出勤情况'**
  String get lectureAttendance;

  /// No description provided for @lectureUnknown.
  ///
  /// In zh, this message translates to:
  /// **'待公布'**
  String get lectureUnknown;

  /// No description provided for @lectureUntitled.
  ///
  /// In zh, this message translates to:
  /// **'未命名讲座'**
  String get lectureUntitled;

  /// No description provided for @papersDownloadDescription.
  ///
  /// In zh, this message translates to:
  /// **'下载到应用目录后，可打开或分享文件。'**
  String get papersDownloadDescription;

  /// No description provided for @papersDownloadLocal.
  ///
  /// In zh, this message translates to:
  /// **'下载到本地'**
  String get papersDownloadLocal;

  /// No description provided for @papersDownloadPreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在获取下载地址'**
  String get papersDownloadPreparing;

  /// No description provided for @papersDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载'**
  String get papersDownloading;

  /// No description provided for @papersDownloadComplete.
  ///
  /// In zh, this message translates to:
  /// **'下载完成'**
  String get papersDownloadComplete;

  /// No description provided for @papersDownloadCancelled.
  ///
  /// In zh, this message translates to:
  /// **'下载已取消'**
  String get papersDownloadCancelled;

  /// No description provided for @papersDownloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败，请重试或在浏览器中打开'**
  String get papersDownloadFailed;

  /// No description provided for @papersDownloadInvalidFile.
  ///
  /// In zh, this message translates to:
  /// **'试卷路径或文件名无效'**
  String get papersDownloadInvalidFile;

  /// No description provided for @papersDownloadIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'文件不完整，请重新下载'**
  String get papersDownloadIncomplete;

  /// No description provided for @papersDownloadCleanupFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法清理未完成的文件，请检查应用存储后重试'**
  String get papersDownloadCleanupFailed;

  /// No description provided for @papersOpenFile.
  ///
  /// In zh, this message translates to:
  /// **'打开文件'**
  String get papersOpenFile;

  /// No description provided for @papersShareFile.
  ///
  /// In zh, this message translates to:
  /// **'分享文件'**
  String get papersShareFile;

  /// No description provided for @papersOpenFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开所在文件夹'**
  String get papersOpenFolder;

  /// No description provided for @papersCopyLocalPath.
  ///
  /// In zh, this message translates to:
  /// **'复制本地路径'**
  String get papersCopyLocalPath;

  /// No description provided for @papersLocalOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开文件，可分享文件或在浏览器中打开'**
  String get papersLocalOpenFailed;

  /// No description provided for @papersShareFailed.
  ///
  /// In zh, this message translates to:
  /// **'此设备无法分享该文件，可复制本地路径或在浏览器中打开'**
  String get papersShareFailed;

  /// No description provided for @papersByteUnit.
  ///
  /// In zh, this message translates to:
  /// **'B'**
  String get papersByteUnit;

  /// No description provided for @papersKibibyteUnit.
  ///
  /// In zh, this message translates to:
  /// **'KiB'**
  String get papersKibibyteUnit;

  /// No description provided for @papersMebibyteUnit.
  ///
  /// In zh, this message translates to:
  /// **'MiB'**
  String get papersMebibyteUnit;

  /// No description provided for @papersGibibyteUnit.
  ///
  /// In zh, this message translates to:
  /// **'GiB'**
  String get papersGibibyteUnit;

  /// No description provided for @papersDownloadBytes.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {received}'**
  String papersDownloadBytes(String received);

  /// No description provided for @papersDownloadProgress.
  ///
  /// In zh, this message translates to:
  /// **'{received} / {total} · {percent}'**
  String papersDownloadProgress(String received, String total, String percent);

  /// No description provided for @nextCourseWidgetSettings.
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件'**
  String get nextCourseWidgetSettings;

  /// No description provided for @nextCourseWidgetDescription.
  ///
  /// In zh, this message translates to:
  /// **'在桌面查看下一节课或本周课表，点击返回课表。'**
  String get nextCourseWidgetDescription;

  /// No description provided for @nextCourseWidgetAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加到桌面'**
  String get nextCourseWidgetAdd;

  /// No description provided for @nextCourseWidgetAddDescription.
  ///
  /// In zh, this message translates to:
  /// **'由桌面确认添加；也可长按桌面，在小组件中选择福大助手。'**
  String get nextCourseWidgetAddDescription;

  /// No description provided for @nextCourseWidgetPinUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前桌面不支持直接添加，请长按桌面，从小组件列表添加。'**
  String get nextCourseWidgetPinUnavailable;

  /// No description provided for @nextCourseWidgetRefresh.
  ///
  /// In zh, this message translates to:
  /// **'立即联网更新'**
  String get nextCourseWidgetRefresh;

  /// No description provided for @nextCourseWidgetRefreshDescription.
  ///
  /// In zh, this message translates to:
  /// **'登录教务处并刷新本地校历、课表和所有小组件。'**
  String get nextCourseWidgetRefreshDescription;

  /// No description provided for @nextCourseWidgetUpdated.
  ///
  /// In zh, this message translates to:
  /// **'小组件已更新'**
  String get nextCourseWidgetUpdated;

  /// No description provided for @nextCourseWidgetFailed.
  ///
  /// In zh, this message translates to:
  /// **'小组件更新失败，请重试。'**
  String get nextCourseWidgetFailed;

  /// No description provided for @nextCourseWidgetPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'桌面会显示课程名称、时间和地点，退出教务账号后清空。'**
  String get nextCourseWidgetPrivacy;

  /// No description provided for @nextCourseWidgetMissing.
  ///
  /// In zh, this message translates to:
  /// **'请先刷新校历和当前学期课表。'**
  String get nextCourseWidgetMissing;

  /// No description provided for @nextCourseWidgetUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件暂仅支持 Android。'**
  String get nextCourseWidgetUnsupported;

  /// No description provided for @widgetVariantCompact.
  ///
  /// In zh, this message translates to:
  /// **'2×1'**
  String get widgetVariantCompact;

  /// No description provided for @widgetVariantSquare.
  ///
  /// In zh, this message translates to:
  /// **'2×2'**
  String get widgetVariantSquare;

  /// No description provided for @widgetVariantTimetable.
  ///
  /// In zh, this message translates to:
  /// **'周课表 4×4'**
  String get widgetVariantTimetable;

  /// No description provided for @widgetPreview.
  ///
  /// In zh, this message translates to:
  /// **'小组件预览'**
  String get widgetPreview;

  /// No description provided for @widgetNextClass.
  ///
  /// In zh, this message translates to:
  /// **'下一节课'**
  String get widgetNextClass;

  /// No description provided for @widgetInProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在上课'**
  String get widgetInProgress;

  /// No description provided for @widgetWeeklyTimetable.
  ///
  /// In zh, this message translates to:
  /// **'本周课表'**
  String get widgetWeeklyTimetable;

  /// No description provided for @widgetAddVariant.
  ///
  /// In zh, this message translates to:
  /// **'添加 {variant} 小组件'**
  String widgetAddVariant(String variant);

  /// No description provided for @widgetSyncEnabled.
  ///
  /// In zh, this message translates to:
  /// **'夜间自动更新'**
  String get widgetSyncEnabled;

  /// No description provided for @widgetSyncDescription.
  ///
  /// In zh, this message translates to:
  /// **'每天登录教务处，更新本地课表和桌面小组件。'**
  String get widgetSyncDescription;

  /// No description provided for @widgetSyncTime.
  ///
  /// In zh, this message translates to:
  /// **'自动更新时间'**
  String get widgetSyncTime;

  /// No description provided for @widgetSyncLastSuccess.
  ///
  /// In zh, this message translates to:
  /// **'上次成功更新'**
  String get widgetSyncLastSuccess;

  /// No description provided for @widgetSyncNever.
  ///
  /// In zh, this message translates to:
  /// **'尚未成功联网更新'**
  String get widgetSyncNever;

  /// No description provided for @widgetSyncNext.
  ///
  /// In zh, this message translates to:
  /// **'下次自动更新'**
  String get widgetSyncNext;

  /// No description provided for @widgetSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'联网更新失败，继续使用已有缓存，请重试。'**
  String get widgetSyncFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
