// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

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
  String get homeSettingsSubtitle => '管理学期、课表显示与自定义课程。';

  @override
  String get generalSettings => '一般设置';

  @override
  String get generalSettingsSubtitle => '语言与网页增强';

  @override
  String get advancedSettings => '高级设置';

  @override
  String get advancedSettingsSubtitle => '网络代理等进阶选项';

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
  String get west2AdjustmentsDescription => '从西二在线补充全校调休安排，数据请以教务通知为准。';

  @override
  String get autoAdjustCourse => '自动调课';

  @override
  String get autoAdjustCourseDescription => '根据教务系统的调课记录调整课表。';

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
  String get showNonCurrentWeekCoursesDescription => '在课表的空闲时段淡化显示非本周课程。';

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
  String get hiddenCourseSessionsDescription => '恢复课表中已隐藏的单次课程。';

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
  String get courseReminderDescription => '每天提醒明天最早的课程，无课时提醒休息。';

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
  String get permissionManagementDescription => '查看权限用途与授权状态，点击进入系统管理。';

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
  String get reminderNotificationStyleDescription =>
      '管理课程提醒渠道的锁屏显示、声音和横幅；已修改的系统设置需在这里手动调整。';

  @override
  String get permissionPurposeNotifications => '发送课程与定时任务通知';

  @override
  String get permissionPurposeAlarms => '按设定时间执行后台任务';

  @override
  String get permissionPurposeCamera => '扫描学习中心签到二维码';

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
  String get thirdPartyDescription => '按功能选择隐藏、询问或开启西二在线服务。';

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
  String get pastPapersDescription => '从西二在线获取历年试卷目录与下载链接。';

  @override
  String get campusServices => '校园服务';

  @override
  String get campusServicesDescription => '通过统一认证使用学校官方校园服务。';

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
  String get customCoursesDescription => '管理当前账号各学期的自定义课程。';

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
  String get webdavAutoSyncDescription => '开启后在启动或返回应用时同步，两端都有改动时请手动选择。';

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
  String get webdavDescription => '通过 WebDAV 同步设置及课程记录，不含登录信息与缓存。';

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
}
