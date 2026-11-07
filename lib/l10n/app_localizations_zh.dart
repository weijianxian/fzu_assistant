// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settingsAppSection => '应用设置';

  @override
  String get settingsPlatformSection => '平台功能';

  @override
  String get settingsCoursesSection => '课程管理';

  @override
  String get settingsSemesterSection => '学期';

  @override
  String get settingsDisplaySection => '显示设置';

  @override
  String get settingsGeneralSection => '通用';

  @override
  String get settingsSyncSection => '同步设置';

  @override
  String get settingsSyncStatusSection => '同步状态';

  @override
  String get settingsDataSection => '数据管理';

  @override
  String get settingsConnectionSection => '连接配置';

  @override
  String get settingsPermissionsSection => '系统权限';

  @override
  String get settingsRefreshSection => '课表更新';

  @override
  String get settingsAutoSyncSection => '自动同步';

  @override
  String get settingsManualSyncSection => '手动同步';

  @override
  String get settingsExportSection => '导出设置';

  @override
  String get settingsReminderSection => '提醒设置';

  @override
  String get scheduleSync => '课表同步';

  @override
  String get scheduleSyncDescription => '更新课表、桌面小组件和已开启同步的系统日历';

  @override
  String get scheduleSyncLinkDescription => '手动同步、自动更新时间与相关权限';

  @override
  String get scheduleSyncAutomaticDescription => '每天定时更新课表、小组件与已开启同步的日历';

  @override
  String get scheduleSyncAlarmPurpose => '自动同步需要此权限，手动同步不受影响';

  @override
  String get scheduleSyncUpdated => '课表已同步，小组件和已开启同步的系统日历已更新。';

  @override
  String get scheduleSyncUnsupported => '课表同步仅支持 Android。';

  @override
  String get hiddenCourseManagement => '不展示课程管理';

  @override
  String get customCourseManagement => '自定义课程管理';

  @override
  String get academicCachedSession => '教务连接失败，正在展示历史缓存，请重试以获取最新数据。';

  @override
  String get accountManagement => '账号管理';

  @override
  String get accountAcademic => '教务处';

  @override
  String get accountSso => '统一身份认证（SSO）';

  @override
  String get accountSignedOut => '未登录';

  @override
  String get accountSsoDescription => '管理统一认证、一码通和学习中心的登录状态';

  @override
  String get accountAcademicLogoutDescription =>
      '退出教务处，并清除当前账号的统一认证、一码通和学习中心登录状态。';

  @override
  String get campusSwipeHint => '上下滑动切换消费码和入馆码';

  @override
  String get campusCode => '一码通';

  @override
  String get campusPayCode => '消费码';

  @override
  String get campusLibraryCode => '入馆码';

  @override
  String get campusLibraryCodeHint => '请将二维码或条形码对准图书馆闸机扫码处。';

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
  String get themeSettingsSubtitle => '深浅色模式和主题色';

  @override
  String get settings => '设置';

  @override
  String get homeSettings => '课表设置';

  @override
  String get homeSettingsSubtitle => '管理学期、课表显示与自定义课程';

  @override
  String get generalSettings => '一般设置';

  @override
  String get generalSettingsSubtitle => '语言与网页增强';

  @override
  String get advancedSettings => '高级设置';

  @override
  String get advancedSettingsSubtitle => 'GitHub 下载代理配置';

  @override
  String get githubProxy => 'GitHub 代理';

  @override
  String get githubProxyEnabled => '启用 GitHub 代理';

  @override
  String get githubProxyDescription => '更新包和 GitHub 资源下载会使用代理';

  @override
  String get githubProxyBaseUrl => '代理地址';

  @override
  String get githubProxyBaseUrlDescription =>
      '填写 GitHub 下载代理地址，例如 https://gh-proxy.org/。';

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
  String get interfaceStyle => '界面风格';

  @override
  String get interfaceStyleClassic => '经典列表';

  @override
  String get interfaceStyleClassicDescription => '平铺展示，简洁紧凑';

  @override
  String get interfaceStyleCards => '卡片分组';

  @override
  String get interfaceStyleCardsDescription => '相关设置分组，行间保留间隙';

  @override
  String get interfaceStyleContinuousCards => '连续卡片';

  @override
  String get interfaceStyleContinuousCardsDescription => '同组设置连成完整卡片，内部无分隔';

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
  String get reset => '重置';

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
  String get skipUpdatesPermanently => '永久跳过';

  @override
  String get downloadUpdate => '前往下载';

  @override
  String get installUpdate => '下载并安装';

  @override
  String get updateNoCompatiblePackage => '未找到适配当前设备的安装包，已打开下载页面';

  @override
  String get updateInstallPermissionRequired => '请允许安装未知来源应用后，再点击下载并安装';

  @override
  String get updateDownloadFailed => '下载更新失败';

  @override
  String get updateInstallFailed => '打开安装器失败';

  @override
  String get updateOpeningInstaller => '打开安装器';

  @override
  String get alreadyLatest => '已是最新版本';

  @override
  String get updateCheckFailed => '检查更新失败';

  @override
  String get showExamOnSchedule => '在课表中显示考试';

  @override
  String get showExamOnScheduleDescription => '把考试安排显示在对应日期的课程表里';

  @override
  String get west2AdjustmentsEnabled => '从 west2 获取调课数据';

  @override
  String get west2AdjustmentsDescription => '从西二在线补充全校调休安排，数据请以教务通知为准';

  @override
  String get autoAdjustCourse => '自动调课';

  @override
  String get autoAdjustCourseDescription => '根据教务系统的调课记录调整课表';

  @override
  String get evaluation => '一键评议';

  @override
  String get evaluationSubtitle => '批量评议任课教师';

  @override
  String get noEvaluationData => '暂无待评议的课程';

  @override
  String get evalTabXqxk => '学期选课';

  @override
  String get evalTabScore => '成绩查询';

  @override
  String get evalScoreHint => '百分制评分';

  @override
  String get evalSelectComment => '选择评语';

  @override
  String get evalCustomComment => '自己评价';

  @override
  String get evalCustomHint => '来评价一下老师吧';

  @override
  String get evalSubmit => '提交';

  @override
  String get evalSubmitAll => '全部提交';

  @override
  String get evalFillCaptcha => '填写验证码';

  @override
  String get evalCaptchaRequired => '验证码不能为空';

  @override
  String get evalCaptchaError => '验证码错误';

  @override
  String get evalSuccess => '评议成功！';

  @override
  String evalScoreRequired(String course) {
    return '$course 的评分未填写';
  }

  @override
  String evalCommentRequired(String course) {
    return '$course 的评语未填写';
  }

  @override
  String get evalRefreshCaptcha => '看不清，换一张';

  @override
  String get evalNotAvailable => '当前没有待评议的课程，您已经完成全部课程的评议，或评议尚未开始。';

  @override
  String get evalNoFilled => '请先填写评议内容';

  @override
  String evalSubmitFailed(String error) {
    return '评议提交失败: $error';
  }

  @override
  String classPeriod(int period) {
    return '第 $period 节';
  }

  @override
  String classPeriodRange(int start, int end) {
    return '第 $start-$end 节';
  }

  @override
  String get adjustedMark => '[调课]';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '还原窗口';

  @override
  String get windowClose => '关闭窗口';

  @override
  String get profileInfo => '个人资料';

  @override
  String get scheduleMorning => '上午';

  @override
  String get scheduleAfternoon => '下午';

  @override
  String get scheduleEvening => '晚上';

  @override
  String get scheduleExamMark => '[考试]';

  @override
  String get schedulePreviousWeek => '上一周';

  @override
  String get scheduleNextWeek => '下一周';

  @override
  String get showNonCurrentWeekCourses => '显示非本周课程';

  @override
  String get showNonCurrentWeekCoursesDescription => '在课表的空闲时段淡化显示非本周课程';

  @override
  String get nonCurrentWeekMark => '[非本周]';

  @override
  String get academicShortcuts => '教务快捷入口';

  @override
  String get academicShortcutsSubtitle => '选课、教务申请与嘉锡讲坛';

  @override
  String get courseSelection => '选课';

  @override
  String get campusElectiveSelection => '校选课';

  @override
  String get retakeSelection => '重修选课';

  @override
  String get minorSelection => '辅修选课';

  @override
  String get academicApplications => '教务申请';

  @override
  String get majorTransferApplication => '转专业申请';

  @override
  String get examDeferralApplication => '缓考申请';

  @override
  String get courseExemptionApplication => '免修申请';

  @override
  String get minorApplication => '辅修申请';

  @override
  String get classroomApplication => '教室申请';

  @override
  String get creditRecognition => '学分认定';

  @override
  String get majorAllocation => '大类分专业';

  @override
  String get electiveCreditConversion => '选修转创拓';

  @override
  String get jiaxiLectures => '嘉锡讲坛';

  @override
  String get skipCourseSession => '我不想上';

  @override
  String get skipCourseSessionDescription => '仅隐藏本周这一次课，可在课表设置中恢复。';

  @override
  String get hiddenCourseSessions => '不展示的课';

  @override
  String get hiddenCourseSessionsDescription => '恢复课表中已隐藏的单次课程';

  @override
  String get noHiddenCourseSessions => '暂无不展示的课';

  @override
  String get restoreCourseSession => '恢复展示';

  @override
  String get restoreAllCourseSessions => '全部恢复';

  @override
  String get learningCenter => '学习中心';

  @override
  String get ssoLogin => '统一身份认证登录';

  @override
  String get ssoLoginDescription => '使用独立的统一认证账号登录校园服务，密码不在本机保存。';

  @override
  String get ssoSmsVerification => '手机验证';

  @override
  String get ssoSendSms => '发送验证码';

  @override
  String get ssoSmsSent => '验证码已发送';

  @override
  String get ssoLogout => '退出统一认证';

  @override
  String get ssoLogoutDescription => '退出统一认证、一码通和学习中心，保留教务登录。';

  @override
  String get ssoSessionExpired => '学习中心登录已过期，请重新登录后重试操作。';

  @override
  String get learningReserve => '预约座位';

  @override
  String get learningReserveSubtitle => '查询空闲座位，预约学习时段';

  @override
  String get learningAppointments => '我的预约';

  @override
  String get learningInstructions => '预约晋江楼 4–5 层的学习座位，到场扫码签到并在离开时签退。';

  @override
  String get learningCancel => '取消';

  @override
  String get learningConfirm => '确定';

  @override
  String get learningSelectPeriod => '选择日期、时段和楼层（08:00–22:30，最多 4 小时）';

  @override
  String get learningBegin => '开始时间';

  @override
  String get learningEnd => '结束时间';

  @override
  String learningFloor(String floor) {
    return '$floor 层';
  }

  @override
  String learningSeatLabel(String floor, String seat) {
    return '$floor 层 · 座位 $seat';
  }

  @override
  String get learningAvailable => '空闲';

  @override
  String get learningOccupied => '已占用';

  @override
  String get learningSeatTimes => '座位当日可用时段';

  @override
  String get learningReserved => '预约成功，请在「我的预约」查看并按时签到。';

  @override
  String get learningSeatList => '座位列表';

  @override
  String learningSeatArea(String area) {
    return '$area区';
  }

  @override
  String get learningOtherArea => '其他';

  @override
  String get learningSeatGuide => '座位导览图';

  @override
  String get learningSingleSeat => '单人座';

  @override
  String get learningSharedSeat => '多人座';

  @override
  String get learningSofaSeat => '沙发座';

  @override
  String get learningSharedAndSofaSeat => '多人座、沙发座';

  @override
  String learningAreaSummary(int available, int occupied) {
    return '空闲 $available · 已占用 $occupied';
  }

  @override
  String get learningNoSeats => '未查询到座位，请更换时段或稍后重试。';

  @override
  String get learningSeatLegend => '浅色座位可预约；点击占用座位查看当日可用时段。';

  @override
  String get learningSignOut => '签退';

  @override
  String get learningCancelAppointment => '取消预约';

  @override
  String get learningActionSucceeded => '操作成功';

  @override
  String get learningUpcoming => '未开始';

  @override
  String get learningPending => '待签到';

  @override
  String get learningSignedIn => '已签到';

  @override
  String get learningMissed => '未签到';

  @override
  String get learningCancelled => '已取消';

  @override
  String get learningCompleted => '已完成';

  @override
  String get learningUnknown => '未知状态';

  @override
  String learningAppointmentTitle(String floor, String seat) {
    return '$floor 层 $seat';
  }

  @override
  String get learningNoAppointments => '暂无预约记录';

  @override
  String get learningLoadMore => '加载更多';

  @override
  String get learningScanSignIn => '扫码签到';

  @override
  String get learningScannerUnsupported =>
      '此平台暂不支持相机扫码，请使用 Android、iOS 或 macOS 设备扫描现场二维码签到。';

  @override
  String get learningCameraError => '无法使用相机，请检查系统相机权限后重新打开扫码页面。';

  @override
  String get learningInvalidQr => '二维码无效或已过期，请扫描现场最新二维码。';

  @override
  String get learningScanHint => '请扫描学习中心现场签到二维码';

  @override
  String get courseReminderTitle => '明日课程提醒';

  @override
  String get courseReminderDescription => '每天提醒明天最早的课程，无课时提醒休息';

  @override
  String get courseReminderUnknown => '暂时无法确认明天的课程，请打开应用刷新课表和校历。';

  @override
  String get courseReminderRest => '明天没有课，好好休息吧！';

  @override
  String courseReminderCourse(String time, String course, String location) {
    return '明天最早 $time · $course · $location';
  }

  @override
  String get reminderTime => '提醒时间';

  @override
  String reminderBeijingTime(String time) {
    return '北京时间 $time';
  }

  @override
  String get reminderPermissionsRequired => '请先允许通知和精确闹钟，再开启提醒。';

  @override
  String get reminderNotificationPermission => '通知权限';

  @override
  String get reminderExactPermission => '精确闹钟权限';

  @override
  String get reminderPermissionGranted => '已允许，点击管理系统权限';

  @override
  String get reminderPermissionDenied => '未允许，点击前往系统设置';

  @override
  String get reminderPermissionLoading => '正在读取权限';

  @override
  String get reminderFailed => '提醒设置失败，请检查权限后重试。';

  @override
  String get permissionManagement => '权限管理';

  @override
  String get permissionManagementSubtitle => '查看应用需要的权限和授权状态';

  @override
  String get permissionManagementDescription => '查看权限用途、授权状态并管理应用权限';

  @override
  String get appPermissionSettings => '应用系统设置';

  @override
  String get permissionSettingsFailed => '无法打开系统权限设置，请重试。';

  @override
  String get permissionLoadFailed => '无法读取应用权限，请重试。';

  @override
  String get permissionAllowed => '已允许';

  @override
  String get permissionNotAllowed => '未允许';

  @override
  String get permissionSpecial => '特殊访问权限';

  @override
  String get permissionRuntime => '运行时权限';

  @override
  String get permissionInstall => '安装时权限';

  @override
  String get reminderNotificationStyle => '锁屏与通知样式';

  @override
  String get reminderNotificationStyleDescription => '管理课程提醒的锁屏显示、声音与横幅';

  @override
  String get permissionPurposeNotifications => '发送课程与定时任务通知';

  @override
  String get permissionPurposeAlarms => '按设定时间执行后台任务';

  @override
  String get permissionPurposeCamera => '扫描学习中心签到二维码';

  @override
  String get permissionPurposeLocation => '向晚点名网页提供当前位置以校验签到范围';

  @override
  String get permissionNameCoarseLocation => '大致位置';

  @override
  String get permissionNameFineLocation => '精确位置';

  @override
  String get permissionPurposeInstall => '安装应用更新';

  @override
  String get permissionPurposeInternet => '联网获取课表、成绩和校园服务数据';

  @override
  String get permissionPurposeWake => '后台任务执行时保持设备唤醒';

  @override
  String get permissionPurposeBoot => '设备重启后恢复定时任务';

  @override
  String get courseReminderSettings => '早课提醒';

  @override
  String get courseReminderSettingsSubtitle => '每天晚上提醒明天最早的课程';

  @override
  String get permissionNameNotifications => '通知';

  @override
  String get permissionNameAlarms => '精确闹钟';

  @override
  String get permissionNameCamera => '相机';

  @override
  String get permissionNameInstall => '安装应用';

  @override
  String get permissionNameInternet => '网络访问';

  @override
  String get permissionNameWake => '保持唤醒';

  @override
  String get permissionNameBoot => '接收开机通知';

  @override
  String get thirdPartyServices => '第三方服务';

  @override
  String get thirdPartyDescription => '管理西二在线调休补充与历年卷服务';

  @override
  String get thirdPartyDisabled => '尚未启用，请前往第三方服务设置';

  @override
  String get accessTip => '询问';

  @override
  String get accessAllow => '开启';

  @override
  String get accessHide => '隐藏';

  @override
  String get pastPapers => '历年卷';

  @override
  String get pastPapersDescription => '从西二在线获取历年试卷目录与下载链接';

  @override
  String get campusServices => '校园服务';

  @override
  String get campusServicesDescription => '按需打开学校官方服务；需要登录的服务复用统一身份认证。';

  @override
  String get campusDormRepair => '公寓报修';

  @override
  String get campusReservations => '综合预约';

  @override
  String get campusLibraryReservation => '图书馆预约';

  @override
  String get campusLostAndFound => '失物招领';

  @override
  String get campusAttendance => '晚点名签到';

  @override
  String get campusElectricBike => '电动车管理';

  @override
  String get campusYiban => '校本化（易班）';

  @override
  String get webViewLoadError => '网页加载失败';

  @override
  String get customCourses => '自定义课程';

  @override
  String get customCoursesDescription => '管理当前账号各学期的自定义课程';

  @override
  String get customCoursesEmpty => '当前学期暂无自定义课程';

  @override
  String get customCourseAdd => '添加课程';

  @override
  String get customCourseEdit => '编辑课程';

  @override
  String get customCourseDelete => '删除课程';

  @override
  String get customCourseSave => '保存课程';

  @override
  String get customCourseName => '课程名称';

  @override
  String get customCourseTeacher => '教师（选填）';

  @override
  String get customCourseLocation => '地点（选填）';

  @override
  String get customCourseRemark => '备注（选填）';

  @override
  String get customCourseWeekday => '星期';

  @override
  String get customCourseStartWeek => '起始周';

  @override
  String get customCourseEndWeek => '结束周';

  @override
  String get customCourseRepeat => '重复方式';

  @override
  String get customCourseEveryWeek => '每周';

  @override
  String get customCourseOddWeeks => '单周';

  @override
  String get customCourseEvenWeeks => '双周';

  @override
  String get customCourseColor => '课程颜色';

  @override
  String get customCourseNameRequired => '请输入课程名称';

  @override
  String get customCourseTermHint => '六位学期编号，例如 202601';

  @override
  String get customCourseTermInvalid => '请输入六位学期编号';

  @override
  String get customCourseRangeInvalid => '结束周或结束节次不能早于起始值';

  @override
  String get customCourseLoginRequired => '请先登录教务账号后管理课程';

  @override
  String get webdavAutoSync => '每次打开自动同步';

  @override
  String get webdavAutoSyncDescription => '在启动或返回应用时自动同步，两端都有改动时请手动选择';

  @override
  String get webdavAutoSyncConflict => '两端数据不同，请前往 WebDAV 手动上传或下载。';

  @override
  String get webdavAutoSyncManualUpload => '服务器不支持防冲突覆盖，请前往 WebDAV 手动上传。';

  @override
  String get webdavAutoSyncFailed => '自动同步失败，请在 WebDAV 设置中检查连接。';

  @override
  String get webdavTestConnection => '测试连接';

  @override
  String get webdavTestDescription => '测试会自动创建缺失目录，并临时写入、读取及删除一个文件。';

  @override
  String get webdavConnectionValid => '连接有效，目录可读写且测试文件已清理。';

  @override
  String get webdavSync => 'WebDAV 同步';

  @override
  String get webdavDescription => '通过 WebDAV 同步设置及课程记录，不含登录信息与缓存';

  @override
  String get webdavDirectory => 'WebDAV 目录地址';

  @override
  String get webdavDirectoryHint => '填写同步目录地址，上传时会自动创建缺失的文件夹。';

  @override
  String get webdavUsername => 'WebDAV 用户名';

  @override
  String get webdavSave => '保存配置';

  @override
  String get webdavSaved => 'WebDAV 配置已保存';

  @override
  String get webdavUpload => '上传到 WebDAV';

  @override
  String get webdavDownload => '下载并覆盖本地';

  @override
  String get webdavUploaded => '同步数据已上传';

  @override
  String get webdavDownloaded => '设置和课程记录已恢复';

  @override
  String get webdavCreateDescription => '将当前设置和课程记录上传到此目录？';

  @override
  String get webdavUploadDescription => '用当前设备的数据覆盖远端备份？';

  @override
  String get webdavDownloadDescription => '用备份覆盖本地设置和所有账号的自定义及隐藏课程记录，保留登录状态？';

  @override
  String get webdavRemoteUpdated => '备份时间';

  @override
  String get webdavCustomCourses => '自定义课程数';

  @override
  String get webdavHiddenCourses => '隐藏课程记录数';

  @override
  String get webdavNotFound => '远端没有同步文件，请先上传';

  @override
  String get webdavCancel => '取消';

  @override
  String get webdavConfirm => '确认';

  @override
  String get cultivatePlan => '培养计划';

  @override
  String get cultivatePlanDescription => '按年级、学院和专业查找教务处培养方案';

  @override
  String get selectPlanManually => '在教务处手动选择培养计划';

  @override
  String get studentCardServices => '学生证与附卡';

  @override
  String get replaceStudentCard => '补办学生证';

  @override
  String get replaceSupplementaryCard => '补办附卡';

  @override
  String get changeTravelRoute => '更改乘车区间';

  @override
  String get graduationProject => '毕业设计（论文）';

  @override
  String get papersHidden => '历年卷入口已隐藏';

  @override
  String get papersSearch => '搜索当前目录';

  @override
  String get papersRoot => '试卷根目录';

  @override
  String get papersParent => '返回上一级目录';

  @override
  String get papersEmpty => '当前目录没有匹配的试卷或文件夹';

  @override
  String get papersOpenDescription => '在浏览器查看或下载试卷，也可复制下载链接。';

  @override
  String get papersOpenFailed => '无法打开浏览器，请复制链接后手动打开';

  @override
  String get utilityPayment => '水电缴费';

  @override
  String get utilityDescription => '选择校区后跳转建行 App 查询和缴纳宿舍水电费。';

  @override
  String get utilityMobileRequired =>
      '宿舍水电缴费需要手机上的中国建设银行 App，请在 Android 或 iPhone 上使用此功能。';

  @override
  String get utilityCampusQishan => '旗山校区';

  @override
  String get utilityCampusTongpan => '铜盘校区';

  @override
  String get utilityCampusJinjiang => '晋江校区';

  @override
  String get utilityCampusYishan => '怡山校区';

  @override
  String get utilityOpenFailed => '无法打开建设银行 App';

  @override
  String get utilityInstallDescription => '请安装建行 App，或复制缴费链接后重试。';

  @override
  String get utilityClose => '关闭';

  @override
  String get utilityCopyLink => '复制缴费链接';

  @override
  String get utilityCopied => '缴费链接已复制';

  @override
  String get utilityInstall => '下载建行 App';

  @override
  String get utilityDownloadFailed => '无法打开下载页面，请前往应用商店搜索中国建设银行';

  @override
  String get reminderXiaomiNotice => '系统限制提醒';

  @override
  String get reminderXiaomiDescription =>
      '由于 MIUI / HyperOS 限制了应用在后台推送本地通知，该功能不可用，您可尝试在 root 后解锁此限制。';

  @override
  String get gradesSummaryTitle => '学期汇总';

  @override
  String get gradesSummaryTotalCredits => '总修学分';

  @override
  String get gradesSummaryHighestScore => '单科最高';

  @override
  String get gradesSummaryEstimatedGpa => '估算 GPA';

  @override
  String get gradesSummaryMissingValue => '缺失';

  @override
  String get gradesSummaryNoGpa => '无适用课程';

  @override
  String get gradesSummaryIncompleteGpa => '部分课程的学分或绩点缺失，暂无法估算。';

  @override
  String get gradesSummaryIncompleteCredits => '部分课程学分缺失，总修学分仅统计已知值。';

  @override
  String get gradesSummaryGpaNote => '按课程学分加权，仅供参考，以教务处为准。';

  @override
  String get gradesSummaryRules =>
      '已出分的补考替代原记录，同一课程不重复计学分；不计绩点类别、二专业和两级制课程不参与 GPA。';

  @override
  String get gradesMissingGpa => '绩点缺失';

  @override
  String get campusServicesLife => '生活与住宿';

  @override
  String get campusServicesBookings => '空间与预约';

  @override
  String get campusServicesGrowth => '学习与活动';

  @override
  String get campusServicesOffice => '信息与办事';

  @override
  String get campusServicesNetwork => '地图与校园网';

  @override
  String get campusDormRepairDescription => '提交公寓设施报修，查看维修进度。';

  @override
  String get campusReservationsDescription => '进入学校综合预约平台办理预约。';

  @override
  String get campusLibraryReservationDescription => '查询并预约图书馆座位。';

  @override
  String get campusLostAndFoundDescription => '发布和查找校园失物招领信息。';

  @override
  String get campusAttendanceDescription => '进入晚点名平台完成签到。';

  @override
  String get campusElectricBikeDescription => '办理校园电动车相关管理业务。';

  @override
  String get campusYibanDescription => '进入校本化易班校园服务。';

  @override
  String get campusMailbox => '福大邮箱';

  @override
  String get campusMailboxDescription => '开通和使用学校提供的电子邮箱。';

  @override
  String get campusQuickResponse => '马上就办';

  @override
  String get campusQuickResponseDescription => '提交校园诉求和意见建议。';

  @override
  String get campusTrustedDocuments => '可信电子文档';

  @override
  String get campusTrustedDocumentsDescription => '进入学校可信电子文档系统办理业务。';

  @override
  String get campusOfficialNotices => '通知文件系统';

  @override
  String get campusOfficialNoticesDescription => '浏览学校发布的通知和文件。';

  @override
  String get campusYouthLeague => '团委管理服务';

  @override
  String get campusYouthLeagueDescription => '进入团委管理服务平台办理团务。';

  @override
  String get campusStudentAffairs => '一站式智慧学工';

  @override
  String get campusStudentAffairsDescription => '办理学生事务并查看学工服务。';

  @override
  String get campusLectureReports => '讲座报告';

  @override
  String get campusLectureReportsDescription => '查看学校公开发布的讲座与报告。';

  @override
  String get campusCertifications => '考证信息';

  @override
  String get campusCertificationsDescription => '查询校园考证和资格考试信息。';

  @override
  String get campusElectricBikeRegistration => '电动车登记';

  @override
  String get campusElectricBikeRegistrationDescription => '进入学校电动车登记系统。';

  @override
  String get campusUnifiedPayment => '统一支付';

  @override
  String get campusUnifiedPaymentDescription => '进入学校统一支付平台办理缴费。';

  @override
  String get campusCardServices => '一卡通服务';

  @override
  String get campusCardServicesDescription => '进入学校一卡通服务平台。';

  @override
  String get campusForms => '一表通';

  @override
  String get campusFormsDescription => '进入学校一表通平台填报表单。';

  @override
  String get campusResume => '个人简历';

  @override
  String get campusResumeDescription => '查看和维护校园服务中的个人简历。';

  @override
  String get campusVenueReservation => '场地预约';

  @override
  String get campusVenueReservationDescription => '查询和预约学校开放的场地。';

  @override
  String get campusNewStudentServices => '迎新服务';

  @override
  String get campusNewStudentServicesDescription => '查看新生报到及迎新办理事项。';

  @override
  String get campusIdentityVerification => '实名身份核验';

  @override
  String get campusIdentityVerificationDescription => '进入学校实名身份核验服务。';

  @override
  String get campusMap => '校园地图';

  @override
  String get campusMapDescription => '查看校园地图并查找校内地点。';

  @override
  String get campusActivities => '校园活动';

  @override
  String get campusActivitiesDescription => '浏览校园活动并查看活动详情。';

  @override
  String get campusSavedActivities => '校园活动收藏';

  @override
  String get campusSavedActivitiesDescription => '查看已收藏的校园活动。';

  @override
  String get campusNetworkRepair => '校园网报修';

  @override
  String get campusNetworkRepairDescription => '提交校园网络故障报修。';

  @override
  String get campusNetworkGuide => '校园网接入指南';

  @override
  String get campusNetworkGuideDescription => '查看校园网络接入说明。';

  @override
  String get campusReturnReservation => '集体返校预约';

  @override
  String get campusReturnReservationDescription => '办理集体返校相关预约。';

  @override
  String get campusPartyTraining => '党员培训';

  @override
  String get campusPartyTrainingDescription => '进入学校党员培训平台学习。';

  @override
  String get campusAccommodation => '住宿服务申请';

  @override
  String get campusAccommodationDescription => '提交住宿服务相关申请。';

  @override
  String get jobFairTitle => '招聘会／宣讲会';

  @override
  String get jobFairDescription => '查看学校发布的招聘活动，时间均为北京时间。';

  @override
  String get jobFairPreviousMonth => '上个月';

  @override
  String get jobFairNextMonth => '下个月';

  @override
  String get jobFairCurrentMonth => '回到本月';

  @override
  String get jobFairSelectMonth => '选择月份';

  @override
  String get jobFairUpcoming => '未开始';

  @override
  String get jobFairPast => '往期活动';

  @override
  String get jobFairRecruitment => '招聘会';

  @override
  String get jobFairKeynote => '宣讲会';

  @override
  String get jobFairNoEvents => '本月暂无招聘会或宣讲会';

  @override
  String get jobFairUnknownTitle => '未公布活动名称';

  @override
  String get jobFairUnknownPlace => '地点待公布';

  @override
  String get jobFairLoadFailed => '招聘活动加载失败，请重试。';

  @override
  String get jobFairRefreshFailed => '刷新失败，仍显示上次加载的活动。';

  @override
  String get jobFairInvalidDetails => '该活动的官方详情地址无效。';

  @override
  String get jobFairShowingPreviousMonth => '月份加载失败，仍显示上次成功加载的月份。';

  @override
  String get jobFairPartialData => '部分活动格式异常，已略过，请以官方公告为准。';

  @override
  String get lecturesDescription => '查看已报名讲座及出勤情况，报名请前往教务处官方页面。';

  @override
  String get lecturesEmpty => '暂无已报名讲座';

  @override
  String get lecturesOpenOfficial => '打开官方页面报名 / 查看';

  @override
  String get lectureCategory => '类别';

  @override
  String get lectureIssueNumber => '期数';

  @override
  String get lectureSpeaker => '主讲人';

  @override
  String get lectureDateTime => '时间（北京）';

  @override
  String get lectureLocation => '地点';

  @override
  String get lectureAttendance => '出勤情况';

  @override
  String get lectureUnknown => '待公布';

  @override
  String get lectureUntitled => '未命名讲座';

  @override
  String get papersDownloadDescription => '下载到应用目录后，可打开或分享文件。';

  @override
  String get papersDownloadLocal => '下载到本地';

  @override
  String get papersDownloadPreparing => '正在获取下载地址';

  @override
  String get papersDownloading => '正在下载';

  @override
  String get papersDownloadComplete => '下载完成';

  @override
  String get papersDownloadCancelled => '下载已取消';

  @override
  String get papersDownloadFailed => '下载失败，请重试或在浏览器中打开';

  @override
  String get papersDownloadInvalidFile => '试卷路径或文件名无效';

  @override
  String get papersDownloadIncomplete => '文件不完整，请重新下载';

  @override
  String get papersDownloadCleanupFailed => '无法清理未完成的文件，请检查应用存储后重试';

  @override
  String get papersOpenFile => '打开文件';

  @override
  String get papersShareFile => '分享文件';

  @override
  String get papersOpenFolder => '打开所在文件夹';

  @override
  String get papersCopyLocalPath => '复制本地路径';

  @override
  String get papersLocalOpenFailed => '无法打开文件，可分享文件或在浏览器中打开';

  @override
  String get papersShareFailed => '此设备无法分享该文件，可复制本地路径或在浏览器中打开';

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
    return '已下载 $received';
  }

  @override
  String papersDownloadProgress(String received, String total, String percent) {
    return '$received / $total · $percent';
  }

  @override
  String get nextCourseWidgetSettings => '桌面小组件';

  @override
  String get nextCourseWidgetDescription => '在桌面查看下一节课或本周课表';

  @override
  String get nextCourseWidgetAdd => '添加到桌面';

  @override
  String get nextCourseWidgetAddDescription => '将所选课程小组件添加到桌面';

  @override
  String get nextCourseWidgetPinUnavailable => '当前桌面不支持直接添加，请长按桌面，从小组件列表添加。';

  @override
  String get nextCourseWidgetRefresh => '立即联网更新';

  @override
  String get nextCourseWidgetRefreshDescription => '登录教务处并刷新本地校历、课表和所有小组件。';

  @override
  String get nextCourseWidgetUpdated => '小组件已更新';

  @override
  String get nextCourseWidgetFailed => '小组件更新失败，请重试。';

  @override
  String get nextCourseWidgetPrivacy => '桌面会显示课程名称、时间和地点，退出教务账号后清空。';

  @override
  String get nextCourseWidgetMissing => '请先刷新校历和当前学期课表。';

  @override
  String get nextCourseWidgetUnsupported => '桌面小组件暂仅支持 Android。';

  @override
  String get widgetVariantCompact => '2×1';

  @override
  String get widgetVariantSquare => '2×2';

  @override
  String get widgetVariantTimetable => '周课表 4×4';

  @override
  String get widgetPreview => '小组件预览';

  @override
  String get widgetNextClass => '下一节课';

  @override
  String get widgetInProgress => '正在上课';

  @override
  String get widgetWeeklyTimetable => '本周课表';

  @override
  String widgetAddVariant(String variant) {
    return '添加 $variant 小组件';
  }

  @override
  String get widgetSyncEnabled => '夜间自动更新';

  @override
  String get widgetSyncDescription => '每天登录教务处，更新本地课表和桌面小组件。';

  @override
  String get widgetSyncTime => '自动更新时间';

  @override
  String get widgetSyncLastSuccess => '上次成功更新';

  @override
  String get widgetSyncNever => '尚未成功联网更新';

  @override
  String get widgetSyncNext => '下次自动更新';

  @override
  String get widgetSyncFailed => '联网更新失败，继续使用已有缓存，请重试。';

  @override
  String get calendarSync => '日历同步';

  @override
  String get calendarSyncDescription => '将课表写入系统日历';

  @override
  String get calendarSyncScope => '同步当前和临近学期的课程、自定义课程、调课及可选考试。隐藏的课次不会写入日历。';

  @override
  String get calendarSyncEnabled => '同步到系统日历';

  @override
  String get calendarSyncPausedHint => '关闭后，已同步的日程会保留。';

  @override
  String get calendarSyncPermission => '日历权限';

  @override
  String get calendarSyncPermissionRequired => '请先授予日历读写权限。';

  @override
  String get calendarSyncTime => '每日同步时间';

  @override
  String get calendarSyncNow => '立即同步';

  @override
  String get calendarSyncBusy => '正在同步…';

  @override
  String get calendarSyncLastSuccess => '上次同步成功';

  @override
  String get calendarSyncFailed => '同步未完成，请检查网络和日历权限后重试。';

  @override
  String calendarSyncResult(int inserted, int updated, int deleted) {
    return '新增 $inserted · 更新 $updated · 删除 $deleted';
  }

  @override
  String get calendarSyncReadPermission => '读取日历';

  @override
  String get calendarSyncWritePermission => '写入日历';

  @override
  String get calendarSyncReadPurpose => '比对已同步的课程日程';

  @override
  String get calendarSyncWritePurpose => '新增、更新和删除专属日历中的课程与考试';

  @override
  String get calendarSyncClear => '删除本应用全部日程';

  @override
  String get calendarSyncClearHint =>
      '删除本机所有账号由福大助手创建的课程和考试，并关闭日历同步。手动添加的独立日程和其他日历不受影响。';

  @override
  String get calendarSyncCleared => '已删除本应用日程并关闭日历同步。';

  @override
  String get calendarSyncClearFailed => '日程清理未完成，请检查日历权限后重试。';

  @override
  String get calendarSyncStartHint => '开启后，将课表写入系统日历。';

  @override
  String get calendarSyncNever => '尚未同步';

  @override
  String get calendarSyncOff => '同步已关闭';

  @override
  String get calendarSyncPending => '设置待同步';

  @override
  String get calendarSyncSaved => '设置已保存，下次同步时应用。';

  @override
  String get calendarSyncSaving => '正在保存设置…';

  @override
  String get calendarSyncSaveFailed => '设置未能保存，请重试。';

  @override
  String get calendarSyncLoadFailed => '暂时无法读取同步状态，请重试。';

  @override
  String get calendarSyncScheduleFailed => '自动同步尚未安排，请重试。';

  @override
  String calendarSyncOccurrences(int count) {
    return '覆盖 $count 次课程与考试';
  }

  @override
  String get calendarSyncNoChanges => '本次没有变更';

  @override
  String get calendarSyncSharedTime => '与桌面小组件共用时间';

  @override
  String get calendarSyncPermissions => '系统权限';

  @override
  String get calendarSyncPermissionsReady => '日历访问与定时同步均已允许';

  @override
  String get calendarSyncCalendarNeeded => '需要日历访问权限';

  @override
  String get calendarSyncAlarmNeeded => '需要定时同步权限';

  @override
  String get calendarSyncAlarmHint => '允许精确闹钟后，才能按时自动同步。';

  @override
  String get calendarSyncGrantCalendar => '允许日历访问';

  @override
  String get calendarSyncGrantAlarm => '允许定时同步';

  @override
  String get calendarSyncAllowed => '已允许';

  @override
  String get calendarSyncNotAllowed => '未允许';

  @override
  String get calendarSyncCalendarPurpose => '用于读写本应用创建的日程';

  @override
  String get calendarSyncAlarmPurpose => '用于在设定时间自动同步';

  @override
  String get calendarSyncHelp => '同步说明';

  @override
  String get calendarSyncRecurrenceHint =>
      '常规课程使用系统重复日程。调课、停课和隐藏只调整对应课次，重复同步不会重复添加。';

  @override
  String get calendarSyncPauseHelp =>
      '关闭同步或退出账号会停止更新，已经写入的日程保留。可以在本页底部删除本应用创建的全部日程。';

  @override
  String get calendarSyncClearSummary => '删除所有账号的已同步日程，并关闭同步';

  @override
  String get calendarSyncClearConfirm => '删除日程';

  @override
  String get calendarSyncClearing => '正在删除日程…';

  @override
  String get calendarExport => '导出到日历';

  @override
  String get calendarExportDescription => '将缓存课程与考试导出为日历文件';

  @override
  String get calendarExportSnapshot =>
      '使用北京时间，包含自定义课程、调课和隐藏记录的处理结果；课表变化后需重新导出。';

  @override
  String get calendarExportMissingData => '请先在首页刷新校历和课表。';

  @override
  String get calendarExportIncludeExams => '包含考试';

  @override
  String get calendarExportReminder => '日程提醒';

  @override
  String get calendarExportNoReminder => '不提醒';

  @override
  String calendarExportReminderMinutes(int minutes) {
    return '提前 $minutes 分钟';
  }

  @override
  String calendarExportEventCount(int count) {
    return '$count 条日程';
  }

  @override
  String calendarExportSkippedExams(int count) {
    return '$count 条考试安排无法解析，已跳过。';
  }

  @override
  String get calendarExportSave => '导出日历文件';

  @override
  String get calendarExportBusy => '正在导出…';

  @override
  String get calendarExportSaved => '日历文件已导出';

  @override
  String get academicChanges => '学业动态';

  @override
  String get academicChangesSubtitle => '查看查询后发现的成绩和考试变化。';

  @override
  String get academicChangesDescription =>
      '首次查询建立基线，后续成功查询时记录成绩与考试变化，保留最近 100 条；点击记录标为已读。';

  @override
  String get academicChangesEmpty => '暂无变化记录，请先查询成绩或考试。';

  @override
  String get academicChangesMarkRead => '全部标为已读';

  @override
  String get academicChangeGradeAdded => '新成绩';

  @override
  String get academicChangeGradeChanged => '成绩变更';

  @override
  String get academicChangeExamAdded => '新增考试安排';

  @override
  String get academicChangeExamChanged => '考试安排变更';

  @override
  String get academicChangeExamRemoved => '考试安排已撤回';

  @override
  String academicChangeCount(int count) {
    return '$count 条未读学业变化';
  }

  @override
  String academicChangeFromTo(String before, String after) {
    return '$before → $after';
  }

  @override
  String get themeMyThemes => '我的主题';

  @override
  String get themeCreate => '创建主题';

  @override
  String get themeImport => '导入主题';

  @override
  String get themeExport => '导出主题';

  @override
  String get themeShare => '分享主题';

  @override
  String get themeDuplicate => '复制主题';

  @override
  String get themeCopy => '副本';

  @override
  String get themeDelete => '删除主题';

  @override
  String get themeDeleteMessage => '删除后将移除此主题；当前正在使用时恢复默认色卡。';

  @override
  String get themeUntitled => '新主题';

  @override
  String get themeEmpty => '创建自己的配色，或导入他人分享的主题。';

  @override
  String get themeImportHelp => '导入包含背景图片的主题包或主题 JSON 文件';

  @override
  String get themeImported => '主题已导入，点击即可应用。';

  @override
  String get themeExported => '主题包已导出';

  @override
  String get themePackageHelp => '主题包包含亮暗配色、样式和背景图片';

  @override
  String get themeEdit => '编辑主题';

  @override
  String get themeBasicInfo => '基础信息';

  @override
  String get themeName => '主题名称';

  @override
  String get themeBasePalette => '基础色卡';

  @override
  String get themeCustomPalette => '自定义';

  @override
  String get themeColorSource => '主题色';

  @override
  String get themeSourceSystem => '手机壁纸取色';

  @override
  String get themeSourceSystemHelp => '使用系统提供的动态配色';

  @override
  String get themeSourceSystemUnavailable => '当前系统不支持动态配色';

  @override
  String get themeSourceImage => 'App 壁纸取色';

  @override
  String get themeSourceSeed => '自选主题色';

  @override
  String get themeCustomSeed => '自定义颜色';

  @override
  String get themeReplacePalette => '重新生成配色？';

  @override
  String themeReplacePaletteMessage(String appearance) {
    return '将替换$appearance的主题配色，保留背景与课表样式';
  }

  @override
  String get themeBackground => '背景图片';

  @override
  String get themeChooseImage => '选择图片';

  @override
  String get themeRemoveImage => '移除图片';

  @override
  String get themeBackgroundDim => '背景压暗';

  @override
  String get themeBackgroundBlur => '背景模糊';

  @override
  String get themeSurfaceOpacity => '面板不透明度';

  @override
  String get themeCourseStyle => '课表与卡片';

  @override
  String get themeCoursePalette => '课程卡片色卡';

  @override
  String get themeCoursePaletteCustom => '自定义';

  @override
  String get themeCoursePaletteEdit => '编辑色卡';

  @override
  String get themeCoursePaletteAdd => '新增颜色';

  @override
  String get themeCoursePaletteFromWallpaper => '从壁纸生成';

  @override
  String themeCoursePaletteRemove(int index) {
    return '移除颜色 $index';
  }

  @override
  String themeCoursePaletteCount(int count) {
    return '$count 色';
  }

  @override
  String themeCoursePaletteColor(int index) {
    return '颜色 $index';
  }

  @override
  String get themeCourseOpacity => '课程卡片不透明度';

  @override
  String get themeCardRadius => '界面卡片圆角';

  @override
  String get themeCourseRadius => '课程卡片圆角';

  @override
  String get themeDividerWidth => '分割线宽度';

  @override
  String get themeScheduleColors => '课表颜色';

  @override
  String get themeResetColor => '恢复默认';

  @override
  String get themeColorHex => '颜色值';

  @override
  String get themeColorHexHelp => '支持 #RRGGBB 或 #AARRGGBB';

  @override
  String get themePreview => '预览';

  @override
  String get themeSaveApply => '保存并应用';

  @override
  String get themeUnsavedTitle => '放弃修改？';

  @override
  String get themeUnsavedMessage => '未保存的主题修改将丢失。';

  @override
  String get themeDiscard => '放弃修改';

  @override
  String get themeKeepEditing => '继续编辑';

  @override
  String get themeSaved => '主题已保存并应用';

  @override
  String get themeNameRequired => '请输入 1 至 80 个字符的主题名称';

  @override
  String get themeColorInvalid => '请输入有效的十六进制颜色';

  @override
  String get themeImageHelp => '分别设置浅色和深色背景图片';

  @override
  String academicChangeDetectedAt(String time) {
    return '发现时间（北京时间）：$time';
  }
}
