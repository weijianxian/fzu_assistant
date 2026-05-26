// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '福大助手';

  @override
  String get navSchedule => '课程表';

  @override
  String get navToolbox => '工具箱';

  @override
  String get navMy => '我的';

  @override
  String get retry => '重试';

  @override
  String loadingFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String get noData => '暂无数据';

  @override
  String dataUpdatedAt(String time) {
    return '数据更新于 $time';
  }

  @override
  String get studentId => '学号';

  @override
  String get password => '密码';

  @override
  String get captcha => '验证码';

  @override
  String get getCaptcha => '获取验证码';

  @override
  String get login => '登录';

  @override
  String get loginValidationError => '请输入学号、密码和验证码';

  @override
  String captchaFetchFailed(String error) {
    return '获取验证码失败: $error';
  }

  @override
  String weekN(int week) {
    return '第 $week 周';
  }

  @override
  String get thisWeek => '本周';

  @override
  String get noScheduleData => '暂无课程数据';

  @override
  String get monday => '周一';

  @override
  String get tuesday => '周二';

  @override
  String get wednesday => '周三';

  @override
  String get thursday => '周四';

  @override
  String get friday => '周五';

  @override
  String get saturday => '周六';

  @override
  String get sunday => '周日';

  @override
  String get college => '学院';

  @override
  String get major => '专业';

  @override
  String get grade => '年级';

  @override
  String get calendar => '校历';

  @override
  String get themeSettings => '外观设置';

  @override
  String get settings => '设置';

  @override
  String get scheduleSettings => '课表设置';

  @override
  String get generalSettings => '一般设置';

  @override
  String get webEnhancement => '网页增强';

  @override
  String get siteInjection => '注入网页样式';

  @override
  String get siteInjectionDescription => '注入自定义 CSS/JS 以改善网页外观';

  @override
  String get about => '关于';

  @override
  String get logout => '退出登录';

  @override
  String get language => '语言';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get gradesAndCredits => '成绩与学分';

  @override
  String get examsAndRooms => '考试与教室';

  @override
  String get campusInfo => '校园信息';

  @override
  String get gpaInfo => '绩点信息';

  @override
  String get gpaInfoSubtitle => '查看绩点排名数据';

  @override
  String get marksQuery => '成绩查询';

  @override
  String get marksQuerySubtitle => '查看全部课程成绩';

  @override
  String get unifiedExam => '统考成绩';

  @override
  String get unifiedExamSubtitle => 'CET / 省计算机等级考试';

  @override
  String get examRoom => '考场查询';

  @override
  String get examRoomSubtitle => '查看考试时间与考场安排';

  @override
  String get creditStats => '学分统计';

  @override
  String get creditStatsSubtitle => '查看各类学分完成进度';

  @override
  String get noGpaData => '暂无绩点数据';

  @override
  String get dataParseError => '数据解析异常';

  @override
  String get noMarksData => '暂无成绩数据';

  @override
  String get unknownSemester => '未知学期';

  @override
  String courseCount(int count) {
    return '$count 门课程';
  }

  @override
  String creditsTag(String credits) {
    return '学分 $credits';
  }

  @override
  String gpaTag(String gpa) {
    return '绩点 $gpa';
  }

  @override
  String get noUnifiedExamData => '暂无统考成绩';

  @override
  String get cetScores => 'CET 成绩';

  @override
  String get provincialComputerScores => '省计算机成绩';

  @override
  String get noExamRoomInfo => '暂无考场信息';

  @override
  String get examTaken => '已考';

  @override
  String creditSuffix(String credit) {
    return '$credit学分';
  }

  @override
  String get noCreditData => '暂无学分数据';

  @override
  String get appearance => '外观';

  @override
  String get followSystem => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get themeColor => '主题色';

  @override
  String get themeDynamic => '动态取色';

  @override
  String get themeDeepPurple => '深紫';

  @override
  String get themeBlue => '蓝色';

  @override
  String get themeTeal => '青色';

  @override
  String get themeGreen => '绿色';

  @override
  String get themeOrange => '橙色';

  @override
  String get themeRed => '红色';

  @override
  String get themePink => '粉色';

  @override
  String get themeIndigo => '靛蓝';

  @override
  String get themeBrown => '棕色';

  @override
  String get devTools => 'Dev Tools';

  @override
  String get collapse => '收起';

  @override
  String get expandAll => '展开全部';

  @override
  String get noCalendarData => '暂无校历数据';

  @override
  String academicYearTerm(String startYear, String endYear, String term) {
    return '$startYear-$endYear 学年  第$term学期';
  }

  @override
  String get current => '当前';

  @override
  String get noScheduleEvents => '暂无日程数据';

  @override
  String get appDescription => '福州大学一站式校园助手 —— 课表、成绩、考试、校历，开箱即用。';

  @override
  String get openSourceUrl => '开源地址';

  @override
  String get contributors => '贡献名单';

  @override
  String commitCount(int count) {
    return '$count 次提交';
  }

  @override
  String get emptyClassroom => '空教室查询';

  @override
  String get emptyClassroomSubtitle => '查找空闲教室';

  @override
  String get noEmptyRoomData => '暂无空教室数据';

  @override
  String get selectDate => '选择日期';

  @override
  String get selectCampus => '选择校区';

  @override
  String get startPeriod => '开始节次';

  @override
  String get endPeriod => '结束节次';

  @override
  String get query => '查询';

  @override
  String get officeNotice => '教务通知';

  @override
  String get officeNoticeSubtitle => '查看教务处通知公告';

  @override
  String get noNoticeData => '暂无通知数据';

  @override
  String pageN(int page) {
    return '第 $page 页';
  }

  @override
  String totalPages(int total) {
    return '共 $total 页';
  }

  @override
  String get openInBrowser => '在浏览器中打开';

  @override
  String get webView => '网页浏览';

  @override
  String get sslWarning => 'SSL 证书验证已跳过，请注意网页安全';

  @override
  String get refresh => '刷新';

  @override
  String get copyLink => '复制链接';

  @override
  String get copied => '已复制';

  @override
  String get clearCookies => '清除Cookie';

  @override
  String get selectSemester => '选择学期';

  @override
  String get autoSemester => '自动（当前学期）';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get newVersionAvailable => '发现新版本';

  @override
  String get releaseNotes => '更新日志';

  @override
  String get skipThisVersion => '跳过此版本';

  @override
  String get downloadUpdate => '前往下载';

  @override
  String get alreadyLatest => '已是最新版本';

  @override
  String get updateCheckFailed => '检查更新失败';

  @override
  String get showExamOnSchedule => '在课表中显示考试';

  @override
  String get permissionManagement => '权限管理';

  @override
  String get permissionManagementSubtitle => '通知、精确闹钟等权限';

  @override
  String get notificationPermission => '通知权限';

  @override
  String get notificationPermissionDesc => '接收课程提醒、考试通知等推送消息';

  @override
  String get exactAlarmPermission => '精确闹钟权限';

  @override
  String get exactAlarmPermissionDesc => '定时触发通知，确保在指定时间准时提醒';
}
