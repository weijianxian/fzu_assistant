# FZU Assistant

福州大学一站式校园助手 —— 课表、成绩、考试、校历，开箱即用。

## 技术栈

- Flutter 3.47.6 + Dart 3.x
- android_alarm_manager_plus（Android 精确闹钟、独立后台 Dart 回调和重启恢复）、flutter_local_notifications（通知展示与锁屏公开内容）
- flutter_hooks（HookWidget / useState / useEffect / useMemoized）
- flutter_svg（登录页 SVG 角色插画）
- Dio + CookieJar 做 HTTP 请求，html 包解析 DOM
- charset 包处理 GBK 编码（校历页面）
- flutter_secure_storage 存储登录凭据
- flutter_localizations + intl 国际化（中英双语）
- flutter_staggered_grid_view 瀑布流网格布局
- re_editor + re_highlight 代码编辑器（JSON 语法高亮，开发者工具用）
- flutter_inappwebview 内置浏览器（Windows + Android，支持 Cookie 注入）
- window_manager（Windows 自绘标题栏、窗口操作与状态监听）
- pointycastle（统一身份认证 AES-ECB / PKCS#7 加密）、mobile_scanner（Android / iOS / macOS 学习中心现场扫码签到）
- barcode_widget（支持原始字节的消费二维码及入馆 Code128 条形码）、asn1lib（解析一卡通 RSA 私钥）、screen_brightness（手机展示码时临时提高应用亮度）

## 项目结构

如果你需要新建页面，请严格按照以下结构放置代码:
```
lib/
  main.dart              # 应用初始化、主题配置、全屏沉浸式 Navigator 与启动页；页面通过 AppScaffold 统一避让系统栏
  l10n/                  # 国际化
    app_localizations.dart    # 自动生成的本地化类
    app_localizations_zh.dart # 中文翻译
    app_localizations_en.dart # 英文翻译
  model/                 # 数据模型（纯 Dart class）
    course.dart          # 课程、课表规则、调课规则、当前周次、学期信息
    hidden_course_session.dart # 按账号、学期、周次和节次持久化的单次隐藏课程
    gpa.dart             # 绩点数据
    mark.dart            # 成绩记录
    unified_exam.dart    # 统考成绩（CET/省计算机）
    exam_room.dart       # 考场信息
    credit.dart          # 学分统计
    calendar.dart        # 校历（学期 + 事件）
    student_info.dart    # 学生个人信息
    learning_center.dart # 学习中心座位、预约状态、可用时段及预约/现场二维码校验
    campus_code.dart     # 一卡通用户信息与消费码原始字节
    empty_room.dart      # 空教室
    notice.dart          # 教务通知（列表 + 部门）
    github_release.dart  # GitHub Release 信息
  common/                # 通用组件
    hooks/
      use_async_data.dart # 通用查询 Hook：加载/错误/更新时间/刷新，卸载保护及最新请求优先
    utils/               # 工具函数
      cache_helper.dart  # 缓存辅助工具
      html_utils.dart    # HTML 解析工具
      context_ext.dart   # BuildContext 扩展（isLandscape 方向判断）
      course_sessions.dart # 课表共用的课程筛选与节次时间
    widget/              # 通用组件
      layout/app_scaffold.dart # 统一普通页面及导航壳：内容避让系统栏，实际 AppBar/导航绘制系统区
      layout/app_scroll_view.dart # 统一滚动视口保持全屏，底部系统边距放在内容末尾
      layout/app_top_banner.dart # 缓存提示条背景延伸至状态栏，内容边距统一处理
      input/password_field.dart # 教务和 SSO 登录共用密码框、显隐按钮及自动填充
      layout/desktop_window_frame.dart # Windows 全局窗口壳（自绘标题栏、提示 Overlay、内容裁剪与顶部缩放）
      layout/split_navigation_page.dart # 横屏两栏导航（左 1/3 功能按钮、右 2/3 独立详情导航）
      tool_page_wrapper.dart  # 工具页包装器（loading/error/refresh/footer，支持 child 和 slivers 两种模式）
      masonry_sliver_grid.dart # 瀑布流网格封装（SliverMasonryGrid.extent + 断点常量）
      section.dart       # 区域组件
      term_selector_button.dart # 学期选择按钮
      half_screen_sheet.dart # 横屏右侧占窗口2/3，竖屏底部拖拽，独立滚动并按屏幕外侧避让系统栏
      sheet/app_bottom_sheet.dart # 普通底部弹层统一处理安全区、键盘及滚动，遮罩保持全屏
      sheet/sheet_drag_handle.dart # 统一顶部拖动柄，上下各8逻辑像素留白
      update_dialog.dart # 更新对话框
  router/                # 路由
    app_routes.dart      # 路由名、参数对象与命名导航扩展
    app_router.dart      # 集中式路由表与页面构建；普通 MaterialPageRoute 保持全屏，不在路由层处理系统边距
  constants/             # 常量
    sp_keys.dart         # SharedPreferences key
    breakpoints.dart     # 响应式尺寸（横向课表最小节次列宽、日期列宽与行高）
    site_injections.dart # WebView URI 正则 CSS/JS 注入规则
  screen/
    campus_code/         # 一码通独立底部 Tab（横屏侧栏）
      campus_code_page.dart # 消费码/入馆码竖向 PageView、消费码下方滑动提示、北京时间与临时亮度；刷新保留旧码原位替换，右下角悬浮刷新按钮，复用 SSO 登录
    guest/               # 匿名页面 如编辑器，webview等
      login.dart         # 登录页
      widgets/login_mascot.dart # 横屏登录页左侧 SVG 角色，密码框聚焦时闭眼；插画位于 assets/illustrations/
      sso_login_page.dart # 统一身份认证登录，支持短信二次验证；密码不落盘
      editor_page.dart   # 通用代码编辑器（re_editor + JSON 高亮）
      webview_page.dart  # 内置浏览器（flutter_inappwebview，支持 Cookie 注入，自动拼接教务处 URL 的 id 参数，CSS/JS 注入受 siteInjectionEnabled 控制，Windows+Android）
    schedule/            # 课程表（首页 tab）
      schedule.dart      # 课程表主页（状态管理 + _ScheduleBody，横屏使用浮动操作按钮）
      widgets/
        schedule_grid.dart # 课表方向切换、课程/调课/考试映射与详情，支持下拉刷新
        horizontal_schedule_grid.dart # 横屏周课表（固定日期列/周次与节次表头、横向时间轴、时段分组、今天高亮及默认聚焦今日/当前时间，手机隐藏滚动条）
        course_card.dart   # 课程卡片（横屏浅色底与课程色条）
        floating_schedule_controls.dart # 横屏设置及翻周悬浮按钮，叠在时间轴上方、避开日期列和系统安全区域，窄窗自动换行
    home/                # 首页导航壳
      home_screen.dart   # 首页壳，管理自适应导航与首页、工具箱、一码通、我的四个主 Tab
    toolbox/             # 工具箱（首页 tab）
      toolbox.dart       # 工具箱主页（MasonrySliverGrid 自适应多列）
      gpa/               # 绩点信息
      marks/             # 成绩查询（MasonrySliverGrid 自适应多列）
      unified_exam/      # 统考成绩
      exam_room/         # 考场查询（MasonrySliverGrid 自适应多列）
      credit/            # 学分统计
      empty_room/        # 空教室查询（日期/节次/校区选择 + 结果列表）
      notice/            # 教务通知（分页列表，WebView 打开详情）
      academic/          # 教务快捷入口（选课、教务申请、嘉锡讲坛，复用带 Cookie 的 WebView）
      learning_center/   # 学习中心：独立 SSO 登录、4/5 层座位查询/预约、时段查询、分页预约记录、取消/签到/签退
        learning_center_page.dart # 入口与 SSO 会话管理
        learning_seats_page.dart # 北京时间未来七天日期卡片、四列半小时时间格和区间高亮；查询后 push 独立座位列表页，返回保留选择
        learning_available_seats_page.dart # 按日期/时段/楼层查询座位，参考 fzuhelper-app 分区、座位类型与空闲/占用统计，右侧分区跳转；固定行高 SliverGrid 稳定滚动范围；占用座位 push 时段页，可用座位使用服务端 spaceId 预约
        learning_seat_times_page.dart # 独立座位当日时段页，使用四列卡片区分可预约/已占用，支持刷新与错误重试，不用弹窗展示查询结果
        learning_appointments_page.dart # 分页预约记录（合并后按预约开始时间倒序），标题为楼层/三位座位号/#预约 ID，副标题为日期和时间段，支持状态更新和预约操作
        learning_scanner_page.dart # 现场二维码扫码签到；Windows/Linux 显示平台不支持提示
        learning_center_widgets.dart # 登录提示、操作确认、会话失效与官方座位导览图全屏缩放；导览图 assets/learning_center/seat-guide.jpg，座位列表和预约记录均通过右上角地图按钮打开
    my/                  # 我的（首页 tab）
      my.dart            # 我的页面主页
      account_management_page.dart # 设置与关于之间的账号管理：教务处退出和统一 SSO 退出（含一码通、学习中心）
      profile_page.dart  # 个人资料（竖屏嵌入我的页面，横屏显示在右栏）；加载或失败时仍保留我的页面底部入口
      about/             # 关于页
      calendar/          # 校历
    settings/            # 设置页（首页/一般/主题/高级设置入口）
      settings_page.dart # 设置页面主页；底部分隔线后直接展示当前平台支持的功能入口或开关，无平台分类页
      course_reminder_settings_page.dart # Android 早课提醒：提醒开关、北京时间及通知/精确闹钟授权和通知渠道管理
      android_permissions_page.dart # Android 预期权限固定清单：标题为权限名称，说明为具体用途和授权状态；不扫描权限，不展示 ID/类型，返回应用自动刷新
      home_settings_page.dart # 首页设置（学期、课表选项及隐藏课程总览/恢复）
      general_settings_page.dart  # 一般设置（语言 + 网页注入开关）
      theme/             # 主题相关
        theme_section.dart # 主题设置页面（外观模式 + 主题色，含 ThemeTile 组件）
    dev/                 # 开发者工具
      dev_tool.dart      # 开发者工具主页（英文标题/分隔线原页分组，保留原有导航与操作）
      learning_center_debug_page.dart # 学习中心 API 调试：分组操作按钮、token 显隐、原始参数/spaceId 直传、HTTP 状态和原始响应；无业务校验和确认弹窗
      shared_prefs_page.dart # SharedPreferences 查看/编辑/删除
      secure_storage_page.dart # SecureStorage 查看/编辑
      kv_tile.dart       # 通用键值对列表项组件（支持 onTap 编辑）
  service/               # 业务逻辑
    auth_storage.dart    # 凭据存储
    account_service.dart # 当前教务/SSO 会话状态与退出清理；教务退出先清 SSO 再清凭据和账号缓存
    captcha_solver.dart  # 验证码识别
    update_service.dart  # 更新检查服务
    app_themes.dart      # 主题色列表 + buildTheme()
    webview_environment.dart # Windows WebView2 环境初始化
    desktop_window.dart # Windows 窗口初始化、状态监听与统一关闭行为
    course_reminder_service.dart # Android 明日课程提醒计划：缓存校历和课表、北京时间、调课与隐藏课程过滤；预排 180 天
    android_task_scheduler.dart # android_alarm_manager_plus 的命名任务分发、后台入口、计划持久化/取消与 flutter_local_notifications 展示
    android_permissions_service.dart # 应用预期权限的实际授权状态读取和系统权限设置跳转
    api/                 # API 相关服务
      api_client.dart    # Dio 单例，登录/重登/拦截器；studentId 为稳定学号，userId 为会话 identifier
      academic_service.dart # 教务处数据抓取（GPA/成绩/考场/校历/空教室/通知/讲座）
      user_service.dart  # 用户信息
      sso_service.dart   # 独立 Dio/CookieJar，SSO 加密、短信验证及学习中心 OAuth token 换取；按教务账号隔离安全存储
      learning_center_service.dart # 学习中心 JSON API：座位/时段/预约记录和预约/取消/签到/签退
      campus_code_service.dart # 一卡通 JSON API、RSA 解密用户密钥及 SO/SP 消费码字节协议
      course_service.dart # 课程表 + 可选 west2 调休数据（公开接口、按学期缓存）
      html_helper.dart   # HTML 解析辅助
    settings/
      app_settings.dart  # 统一设置管理（主题 + 语言 + 学期 + 网页注入，InheritedWidget + SP 持久化）
```

## 校园服务

- `screen/toolbox/campus_services/campus_services_page.dart` 提供公寓报修、综合预约、图书馆预约、失物招领、晚点名、电动车和校本化官方网页。`WebViewArgs.injectSsoCookies` 区分统一认证与教务会话，SSO 登录复用不申请学习中心 token 的页面。WebView 为 HookWidget，SOURCEID_TGC 仅注入 SSO HTTPS host；退出清理原生 Cookie，挂载页面按会话代次销毁旧内容。外部 App 协议仅在用户点击时打开。

## 编码规范

- 首页固定为周课表，不保留天视图、时间线首页、周/天切换或相关设置。历史 home_style / timeline_days 存储值忽略，不恢复已移除的功能。

- 普通页面统一使用 AppScaffold，由内部 Scaffold.body 统一消费 AppBar 尚未处理的顶部和左右边距，保留底部给实际内容处理；背景、标题栏和导航自身延伸至系统区域。首页使用 AppScaffold.shell，外壳不预消费边距，实际子页面的 AppBar 和原生 NavigationRail 自行绘制系统区域并避让内容；横屏分栏仅保留各列触及屏幕外侧的边距。缓存提示统一使用 AppTopBanner，在原生 MaterialBanner 内部避让内容，提示背景覆盖状态栏，其下页面只消费一次顶部边距。状态栏透明并自然显示下方真实表面，保留 AppBar 滚动变色，不通过固定颜色或同步颜色制造沉浸。业务页面不单独放 SafeArea、不用固定留白代替系统边距；Navigator、路由和弹层遮罩保持全屏。普通对话框沿用 Flutter 安全区，全屏导览由 AppScaffold 管理；底部弹层统一使用 showAppBottomSheet 或 showHalfScreenSheet。 垂直滚动统一使用 AppListView、AppCustomScrollView 或 AppSingleChildScrollView，视口延伸至手势区，系统底边距只加入滚动内容末尾并向子树清零；不得在视口外加底部 SafeArea 或使用 Clip.none 泄漏绘制。第三方滚动控件通过 AppScrollInsets 接收内容边距；静态内容使用 AppSafeContent，固定底部操作使用 AppBottomBar 和 Scaffold.bottomNavigationBar，让操作面延伸背景并避让按钮。 横屏侧边抽屉占窗口宽度的2/3，清除不接触屏幕左边时的刘海边距；竖屏拖动柄统一使用 SheetDragHandle，上下各8逻辑像素，内容不再重复添加顶部间距。

- west2 online 服务按功能独立配置 `FeatureAccess.tip / allow / hide`：默认 tip，入口可见但不得请求服务；allow 才启用请求；hide 隐藏入口，仍可在设置中恢复。原 west2 调课布尔开关迁移到 `west2AdjustmentsAccess`，已允许的用户保持 allow；历年卷使用独立 `papersAccess`。统一设置页为 `screen/settings/third_party_settings_page.dart`，模型为 `model/feature_access.dart`，周课表和后台提醒共同读取同一授权状态。
- 本轮功能约束：自定义课程按账号和学期保存，并覆盖周课表与提醒；WebDAV 手动同步应用设置、自定义课程和隐藏课程，禁止上传登录凭据、Cookie、支付数据、缓存及 WebDAV 密码，下载覆盖前须确认。WebDAV 密码只放 SecureStorage。校园服务通过域名隔离的 SSO 会话进入，不把教务 Cookie 当作 SSO Cookie。

- 平台功能直接放在设置主列表底部分隔线之后，仅展示当前平台支持的内容，不设置“平台特性”分类页；Android 展示权限管理和早课提醒入口；Windows 不提供全屏开关，没有专属设置时不展示空分隔区。Android 明日课程提醒默认关闭，默认北京时间 21:00；预生成未来 180 天的通知正文，使用 android_alarm_manager_plus 精确唤醒，在独立后台 Dart isolate 执行命名任务，通过 flutter_local_notifications 展示通知，不依赖前台页面或网络。通知与精确闹钟由用户授权；刷新缓存、调课/隐藏课程/语言设置变更和应用恢复前台时重排，退出教务账号取消计划及测试通知。根据校历日期匹配实际学期，不跟随界面选择的历史学期；缺少课表/校历或超出有效课表周次时提示刷新，不误报无课。AndroidTaskScheduler 持久化计划，闹钟设置 exact/wakeup/allowWhileIdle/rescheduleOnReboot；后台入口保留 @pragma(vm:entry-point)，不引用 UI/主 isolate 内存，执行前核对任务代次防止退出或重排后展示旧通知；插件负责重启恢复。通知默认高重要性、公开锁屏内容，现有系统渠道的用户设置不能由应用强制覆盖，设置提供渠道直达入口。开发者工具仅 Android 显示“Notify in one minute”，使用独立测试闹钟，重复点击替换旧测试，不影响正式计划。

- 教务处成功登录后，将账号绑定的历史 Cookie 与 identifier 保存到 SecureStorage；启动/同账号登录失败且有历史会话时进入缓存模式，保留稳定学号，旧 identifier 不用于业务请求。课表、考场、校历与事件优先展示已有缓存，强制刷新也不得清空缓存；主页提示缓存模式并支持重试登录，退出教务账号同时删除历史会话。

- **每次项目结构或技术栈变更后，必须同步更新本 AGENTS.md 文件**

- 页面统一用 HookWidget，状态用 useState/useEffect/useMemoized
- 设置的平台功能在主列表最底部用分隔线与通用设置分开，按当前平台显示或隐藏，不增加平台分类菜单。Android 权限管理手动维护预期权限清单（通知、精确闹钟、扫码相机、安装更新、联网、定时唤醒和重启恢复），不扫描安装包或插件权限；页面标题展示国际化权限名称，说明展示具体功能用途和授权状态，不展示权限 ID 或类型；通知、精确闹钟、安装未知应用使用实际系统状态，不仅依据 manifest 的授权标志。开发者工具文案及测试通知统一直接使用英文，不接入国际化；工具保持原有入口与操作，在同一列表中用英文标题和分隔线分组，不为分组新增二级页面。
- 页面导航统一使用 `context.pushNamed(AppRoutes.xxx)` / `context.pushReplacementNamed(AppRoutes.xxx)`；教务退出使用 `context.replaceAllNamed(AppRoutes.login)` 清空根导航栈，防止横屏嵌套导航或返回键回到已退出页面。路由名和参数定义在 `app_routes.dart`，页面构建集中在 `app_router.dart`，禁止页面直接构造 `MaterialPageRoute`
- 工具箱内所有工具页使用 ToolPageWrapper 包装（loading、error、空数据、下拉刷新、数据更新时间），`emptyText` 为必填参数；需要瀑布流的页面传 `slivers` 参数，普通列表传 `child` 参数
- 多列自适应布局统一使用 `MasonrySliverGrid`（封装自 `lib/common/masonry_sliver_grid.dart`），列宽断点从 `lib/constants/breakpoints.dart` 的 `kTileMinWidth` 读取
- 横屏/宽屏自动切换侧栏导航（NavigationRail），窄屏使用底部导航栏（BottomNavigationBar），通过 `context.isLandscape`（`common/utils/context_ext.dart`）判断方向
- 响应式断点常量统一定义在 `lib/constants/breakpoints.dart`
- 教务处数据抓取在 AcademicService 中实现，用 Dio GET/POST 请求 HTML 页面，html 包解析 DOM
- 教务处页面多为 GBK 编码，用 `charset` 包的 `gbk.decode()` 解码
- 请求教务处接口需要带 `queryParameters: {'id': userId}`
- ASP.NET WebForms 页面需要先 GET 获取 __VIEWSTATE/__EVENTVALIDATION，再 POST 提交
- 工具页数据列表优先使用 Table 布局（对齐整齐），不用手搓 Row+Card
- UI 文本必须通过 `AppLocalizations.of(context)!.xxx` 引用，禁止硬编码中文/英文字符串；开发者工具（`lib/screen/dev/`）文案直接定义，不使用国际化。
- Service 层错误消息保留中文（无 BuildContext），UI 层捕获后展示
- 状态管理模式：AppSettingsProvider 使用 InheritedWidget + ValueNotifier + SharedPreferences 持久化；普通查询页复用 common/hooks/use_async_data.dart，保留刷新期间的旧数据，特殊分页/条件查询独立管理状态
- 单次隐藏课程保存在 AppSettings.hiddenCourseSessions，按稳定学号 + 学期 + 课程 + 周次/星期/节次隔离；课程详情列表底部提供“我不想上”，说明文字作为按钮的 subtitle，CourseSessions 统一过滤周课表，首页设置支持逐项/全部恢复。非本周课程提示卡和考试卡不提供此操作，刷新课表与登出不删除隐藏记录。
- 学习中心协议参考 `.reference/fzuhelper-app/lib/sso-login.ts` 和 `utils/learning-center/api-service.ts`。SSO Cookie 与学习中心 token 存在 SecureStorage，按教务账号隔离，教务登出时清理；SSO 密码不保存。SSO Cookie 仅发送给其所属域名，学习中心变更请求不自动重试。正常签到须校验现场一分钟有效二维码，直接签到仅在开发者调试页提供。
- 一码通协议参考 `.reference/fzuhelper-app/lib/ykt-login.ts`：无 voucher 时直接展示服务端返回的 20 位在线消费码，不请求离线参数或前端 RSA 配置；有 voucher 时生成离线消费码，SO 正文为原始字节、SP 正文为 Base64，二维码必须按字节编码；摘要对大写十六进制文本计算 SHA1，时间戳使用 Unix 秒。入馆二维码和 Code128 使用服务端用户 account。一码通 token 存在按教务账号隔离的 SecureStorage，SSO/教务登出时清理；支付码、RSA 配置和用户密钥只保留内存。消费码在页面前台每 50 秒刷新，后台/隐藏路由停止刷新并恢复亮度，重新进入时刷新；未开通离线支付仍可使用在线消费码和入馆码。一码通 SSO 登录不依赖学习中心授权。
- 学习中心日期和无时区的服务端时间统一按北京时间（Asia/Shanghai，UTC+8）解释，不受设备时区影响；日期卡片、22 点后默认次日、过去时段禁用、未来七天范围、预约状态及现场二维码校验使用同一时间约定。时间选择参考 fzuhelper-app 的日期卡片与四列时间格，端点深色、区间浅色，最长 4 小时。
- 学习中心开发者调试页直接通过 Dio 调用接口，允许空 token、空 ID 和任意日期时段，预约直接传入 spaceId，不先查座位，不弹操作确认框；展示 HTTP 状态和原始响应，不因业务错误自动清 token 或跳转。正常学习中心页面继续使用业务 Service 的校验和确认流程。
- 开发者工具通过「关于」页面图标累计点击七次进入，无点击间隔限制，跳转后计数清零；横竖屏不显示独立开发者入口。「我的」头像点击后通过带教务 Cookie 的 WebView 打开教务处个人信息页。
- 每次做完一个功能，就 commit 一次，提交信息遵循下方规范。
- 账号管理在“我的”的设置与关于之间，集中提供教务处和 SSO 两项退出；学习中心、一码通页面不另设登出按钮。SSO 退出一起清理统一认证 Cookie、一码通和学习中心 token，保留教务登录；教务退出先清当前账号 SSO 会话，再清教务凭据、Cookie 和账号缓存。SSO 会话变更通知已挂载业务页面清除内存中的二维码/会话，退出前已发出的授权响应不得重新写入 token。

## Commit message 规范

- 使用单行格式：`<emoji> <type>: <中文描述>`，冒号使用英文冒号，冒号后留一个空格。
- 描述说明本次提交的具体改动，简洁明确；技术名词保留原文，不使用「更新代码」「修复问题」等笼统描述。
- 一个提交聚焦一个功能或一类相关改动，不混入无关修改。
- 常用类型与 emoji：
  - `✨ feat`：新增功能或增强现有功能。
  - `🐛 fix`：修复缺陷。
  - `♻️ refactor`：重构代码，不改变功能行为。
  - `🎨 style`：代码格式调整，不改变逻辑。
  - `📝 docs`：文档或开发规范更新。
  - `✅ test`：新增或调整测试。
  - `⚡️ perf`：性能优化。
  - `🔧 chore`：构建、CI、工具配置等维护工作；依赖或 SDK 升级使用 `⬆️ chore`。
- 示例：`🐛 fix: 修复动态主题 ColorScheme 类型不兼容`、`📝 docs: 明确提交信息规范`。
- 正常执行仓库 pre-commit hook，由 hook 自动更新 build 号并检查 Dart 格式，不手动绕过。

## 国际化

- 使用 Flutter 官方 `gen-l10n` 方案，配置文件 `l10n.yaml`
- ARB 文件：`lib/l10n/app_zh.arb`（中文）、`lib/l10n/app_en.arb`（英文）
- 添加新语言：新建 `app_XX.arb` → `flutter gen-l10n` → 在 `AppSettings._localeOptions` 注册
- 语言切换：「我的 → 设置 → 一般设置 → 语言」SegmentedButton 选择，通过 `AppSettings` 持久化到 SharedPreferences
- `MaterialApp.locale` 绑定 `AppSettings.currentLocale`，`null` 表示跟随系统

## Windows 注意事项

- Windows 专用图标为 `assets/icon/icon_windows.svg/png`（浅色圆角底），`windows/runner/resources/app_icon.ico` 包含 16–256px 多尺寸。程序、任务栏、安装器及桌面/开始菜单快捷方式使用同一 ICO，自绘标题栏使用对应 PNG。修改原生图标后需重新构建，Hot Reload 不更新 exe 图标。修改 SVG 后，在项目根目录使用 ImageMagick 重新生成：
  ```powershell
  magick -background none -density 384 assets/icon/icon_windows.svg -resize 1024x1024 PNG32:assets/icon/icon_windows.png
  magick assets/icon/icon_windows.png -define icon:auto-resize=256,128,96,64,48,40,32,24,20,16 windows/runner/resources/app_icon.ico
  ```
- `flutter_inappwebview` 在 Windows 上需要 WebView2 Runtime
- `windows/runner/flutter_window.cpp` 中有 `closeWindow` 方法频道的 workaround（修复关窗 bug）
- Windows 标题栏由 `window_manager` 隐藏，`MaterialApp.builder` 加入全局 `DesktopWindowFrame`；首帧完成后由 Dart 显示窗口。窗口壳拥有独立 Overlay，Navigator 内容使用 ClipRect，防止页面过渡覆盖标题栏。关闭按钮、Alt+F4 和系统菜单关闭共用现有 `closeWindow` 修复。
- `service/webview_environment.dart` 中初始化 `WebViewEnvironment`，`userDataFolder` 设在 app support 目录

## 构建

```bash
flutter run                    # 开发运行
flutter build apk              # Android 打包
flutter build windows --release # Windows 打包（输出 build/windows/x64/runner/Release）
flutter analyze                # 静态分析
flutter gen-l10n               # 重新生成国际化代码
```

### CI 工作流

- `.github/workflows/build.yaml` 负责 `main` 分支 push、`v*` tag 和手动触发，调用各平台构建及汇总 Release；不监听 `feat/platform-builds` 测试分支。
- 平台构建分别位于 `windows.yaml`、`android.yaml`、`apple.yaml` 和 `linux.yaml`，统一仅支持 `workflow_call` 与手动执行，不独立监听 push/PR，避免重复构建；Linux 测试分支的临时 push 触发器已在合并到 `main` 前移除。
- `.github/workflows/check.yaml` 独立在 push/PR/手动触发时执行国际化生成、Dart 格式检查、静态分析和单元/组件测试；纯 Markdown 变更跳过自动检查，同一分支的新检查取消旧检查，tag 不主动取消。
- 主工作流显式向 Android 子工作流传递 `KEY_STORE_PASSWORD`、`KEY_PASSWORD`、`KEY_ALIAS` 和 `KEYSTORE_BASE64` 四项签名 secrets；手动执行 Android 工作流时使用仓库 secrets。
- fork 和 Dependabot PR 无法获取签名 secrets，主工作流跳过这些 PR 的 Android 签名构建，其他平台及 Check 照常运行。
- 主工作流和各平台工作流均按平台前缀、workflow 和 ref 设置 concurrency；同一分支的新运行取消旧运行，tag 构建不主动取消。
- 自动 push/PR 构建通过 `paths-ignore: ['**/*.md']` 跳过仅 Markdown 变更（含子目录）；混合代码变更仍构建，tag 发布和手动构建不受影响。若 pre-commit 同时修改 `pubspec.yaml` 的 build 号，该提交仍会触发构建。

### Linux

- 原生工程位于 `linux/`，可执行文件名为 `fzu_assistant`。
- `.github/workflows/linux.yaml` 在 Ubuntu 24.04 runner 的 Debian forky 容器内构建 x86_64 release；当前 WebView 插件需要 WPE WebKit >= 2.50（trixie 仅提供 2.48，Ubuntu 24.04 缺少 WPE 包）。仅支持手动执行及主构建流程调用，不独立监听测试分支推送，tag Release 包含 Linux 产物。
- CI 安装 Flutter 的 GTK/Clang/CMake/Ninja 构建依赖，以及 WebView 插件的 WPE WebKit、WPEBackend-FDO、libwpe、epoxy、Wayland 和凭据存储的 libsecret 开发包。
- `linux/CMakeLists.txt` 针对 WPE >= 2.54 为 WebView beta 插件提供动画设置更名的兼容定义；升级插件后需检查是否可以移除。
- 发布包为 `FZU-assistant-v<version>-linux-x86_64.tar.gz`，包含完整 bundle，保留可执行权限与符号链接；解压后运行 `./fzu_assistant`。目标系统需提供与 Debian forky 构建兼容的 glibc、GTK、WPE WebKit 等运行库，凭据存储需要可用的 Secret Service。
- 同时发布 `FZU-assistant-v<version>-linux-x86_64.deb`（Debian 架构名为 `amd64`）。`installer/linux/package-deb.sh` 将完整 bundle 安装到 `/usr/lib/fzu-assistant`，提供 `/usr/bin/fzu-assistant` 启动器、`installer/linux/fzu-assistant.desktop` 应用菜单入口和 SVG 图标；使用 `dpkg-shlibdeps` 扫描程序及所有插件生成系统库依赖，不忽略缺失的依赖信息。CI 执行 ShellCheck、desktop-file-validate 和 APT 安装检查，并将 deb 加入 tag Release。
- deb 使用 `sudo apt install ./FZU-assistant-v<version>-linux-x86_64.deb` 安装，运行 `fzu-assistant` 或从应用菜单启动，使用 `sudo apt remove fzu-assistant` 卸载。deb 同样要求目标系统提供兼容的运行库，不能使旧版 Ubuntu/Debian 自动兼容；推荐安装 GNOME Keyring 提供凭据存储的 Secret Service。
- Linux Actions 产物按格式分别上传：`FZU-assistant-v<version>-linux-x86_64-portable` 仅包含 tar.gz，`FZU-assistant-v<version>-linux-x86_64-deb` 仅包含 deb。Release 使用 Linux 通配规则下载这两个产物，分别发布原始 tar.gz 和 deb 文件。
- `cliff.toml` 的 Release 下载表在 Linux x86-64 栏同时列出 DEB 和 TAR.GZ，链接文件名必须与 CI 发布产物一致。
- Windows 无法执行 Linux 原生构建，需在 Linux 或 GitHub Actions Ubuntu runner 上验证。

```bash
flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release
bash installer/linux/package-deb.sh # 需要 dpkg-dev 和 desktop-file-utils
```

### macOS / iOS（暂不配置开发者签名）

- 原生工程：`macos/`、`ios/`；均使用 CocoaPods，最低系统版本为 macOS 12、iOS 15。Flutter 配置使用 `--no-enable-swift-package-manager`，与仓库内 Podfile 保持一致。
- macOS 沿用原生标题栏，Bundle ID 为 `com.weijx.fzuAssistant`，应用名为 `FZU Assistant`；Debug/Profile 和 Release 均需保留 `com.apple.security.network.client`，否则教务请求无法联网。
- macOS 使用本地 ad-hoc 签名（`CODE_SIGN_IDENTITY = -`），不配置 Apple Developer 证书、开发团队、Provisioning Profile 或公证；DMG 本身不签名。不要把 ad-hoc 签名误认为 Developer ID 发布签名。
- macOS 凭据使用 `MacOsOptions(usesDataProtectionKeychain: false)` 的传统 Keychain，不启用 Keychain Sharing，避免未配置开发者签名时需要 Provisioning Profile。
- iOS 保留 Keychain entitlements，使用 `flutter build ios --release --no-codesign`；把 `build/ios/iphoneos/Runner.app` 放进 `Payload/Runner.app` 后压成 IPA。未签名 IPA 需要用户另行签名才能安装到真机，不用于 App Store 发布。
- Apple 图标由 `assets/icon/icon.png`（iOS，移除 alpha）及 `assets/icon/icon_windows.png`（macOS）生成；配置在 `pubspec.yaml` 的 `flutter_launcher_icons`，生成后提交原生 Assets 目录。
- `.github/workflows/apple.yaml` 是可复用构建流程：仅由主构建流程 `build.yaml` 调用或手动执行，PR 构建统一由 `build.yaml` 触发，DMG/IPA 加入 tag Release。Apple/Linux 改动统一在 `feat/platform-builds` 分支开发。
- macOS 发布包为 universal（arm64 + x86_64）；产物命名为 `FZU-assistant-v<version>-macos-universal-unsigned.dmg` 和 `FZU-assistant-v<version>-ios-arm64-unsigned.ipa`。Apple CI 仅构建、打包和上传产物，不再执行静态分析、测试或产物校验；格式检查、静态分析和单元/组件测试由独立 Check 工作流执行。
- 普通单元/组件测试使用 `flutter test`。
- Windows 无法执行 Apple 原生构建；构建必须在有 Xcode 的 macOS 上或 GitHub Actions 的 macOS runner 上验证。

```bash
flutter config --enable-ios --enable-macos-desktop --no-enable-swift-package-manager
flutter pub get
flutter build macos --release
flutter build ios --release --no-codesign
```

### Windows 安装包（Inno Setup）

安装脚本 `installer/windows/setup.iss`（参考 [zerx-lab/FluxDown](https://github.com/zerx-lab/FluxDown)，本地目录 `.reference/FluxDown/`），CI 在 `flutter build windows` 之后调用：

```powershell
iscc /DMyAppVersion=1.3.1 /DMyAppArch=x64 `
     "/DMySourceDir=$PWD\build\windows\x64\runner\Release" `
     installer\windows\setup.iss
```

产物：`build/installer/FZU-Assistant-<version>-windows-x64-setup.exe`（另有便携 zip）。

关键设计（与 FluxDown 一致，改动前先想清楚）：

- **始终每用户安装**：`PrivilegesRequired=lowest` + `DefaultDirName={autopf}\FZU Assistant`
  （`{autopf}` 在非管理员下解析为 `%LOCALAPPDATA%\Programs`），全程不弹 UAC。
  **不要**开放「为所有用户安装」覆盖项——一旦存在管理员模式安装，
  Inno 的 `UsePreviousPrivileges` 会让之后每次静默自动更新都要求提权。
- **`AppId` GUID 恒定**：`{9F2C4B7E-4A31-4C6D-8E52-7B1A0C3D5E84}`，改了就变成并存安装。
- **`CloseApplications=force`** + `[Code] PrepareToInstall` 里 `taskkill /f /im fzu_assistant.exe`
  兜底：应用常驻会锁住 exe/DLL，否则升级报 access denied；顺带清掉旧 `unins000.exe` 的只读属性。
- **`[InstallDelete]` 先清 `*.dll` 与 `data\`**：覆盖升级时避免残留插件 DLL/资源被新版本加载。
- `VersionInfoVersion` 用去掉 `+build` 的 `x.y.z`（`1.3.1+85` 不是合法 Inno 版本号，CI 已切分）。
- 中文语言文件已 vendor 进仓库 `installer/windows/ChineseSimplified.isl`（上游 issrc 移除了 Unofficial 目录），CI 会拷进 Inno 的 `Languages\`。

### 应用内自动更新（Windows）

`UpdateService.installWindowsUpdate()` 在安装版中下载 release 的安装器后静默执行：

```dart
Process.start(installerPath, ['/SILENT', '/SUPPRESSMSGBOXES',
  '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS', '/NORESTART'],
  mode: ProcessStartMode.detached, runInShell: false);
// 800ms 后 exit(0)
```

与 `setup.iss` 的**成对契约**，改一边必须看另一边：

- `/SILENT` ↔ `[Run]` 两条：第一条 `skipifsilent`（安装向导勾选才启动），
  第二条 `skipifnotsilent runasoriginaluser`（静默更新后自动把应用拉回来）。
- 显式 `exit(0)` 而不等窗口关闭：`flutter_window.cpp` 的 `closeWindow` 走 `TerminateProcess`，
  普通关窗不可靠；且进程必须尽快释放 `fzu_assistant.exe` / 插件 DLL 的锁，
  Inno 的 `CloseApplications` 才能改写它们。
- 「已安装」判据 = exe 同目录存在 `unins000.exe`（Inno 自动写入 `{app}`）。
  便携版及调试版也在应用内下载安装器，但仅传 `/NORESTART` 打开交互安装向导；不强制退出当前应用，安装器在用户确认安装后按既有流程关闭旧进程。此操作安装到用户选择的目录，不覆盖便携目录。
- 资产筛选 `UpdateUtils.pickWindowsInstaller()` 只认带 `setup`/`installer` token 的 `.exe`：
  便携 zip 与安装器资产名只差扩展名，裸 `.exe` 兜底会误伤其他附件。

## Release 发布流程
1. 在需要发布release时，先切换到 `main` 分支，抬升语义化版本号（`x.y.z`），提交 commit，触发 pre-commit hook 自动递增 build 号
2. 打上tag，格式为 `v` 加版本号，例如 `v1.2.3`,并 push 到 GitHub，触发 GitHub Actions 构建发布流程


tag规则如下：

``` txt
version: 1.1.8+53  # 开发中
version: 1.1.8+52  # tag: v1.1.8
version: 1.1.7+51
version: 1.1.7+50
version: 1.1.7+49  # tag: v1.1.7 
version: 1.1.6+48
version: 1.1.6+47  # tag: v1.1.6
version: 1.1.5+46
``` 

### Windows 安装包首次发布后的验证

1. 从 Release 下载 `FZU-Assistant-<version>-windows-x64-setup.exe`，双击安装：
   确认**没有 UAC 弹窗**、装在 `%LOCALAPPDATA%\Programs\FZU Assistant`、
   开始菜单与桌面快捷方式正常。
2. 打开应用 →「我的 → 关于 → 检查更新」：应显示新版本，点「下载并安装」后
   应用**自动退出 → 静默安装 → 自动重启**，版本号已更新。
3. 便携版（`fzu_assistant-windows-*.zip`）解压运行 → 检查更新：
   按钮应为「下载并安装」，在应用内显示下载进度，然后打开安装向导；取消向导时当前应用仍可使用，确认后由安装器关闭旧进程并安装到所选目录。
4. 设置 →「应用和功能」卸载：目录、注册表 Run 值、开始菜单项全部清干净。

失败时 Inno 会在 `%TEMP%\Setup Log*.txt` 留日志；静默参数与 `setup.iss` 的配对关系见上一节。

## 开发辅助脚本

- `scripts/learning_center_signin_qrcode.py` 为 uv script，使用 PEP 723 内联依赖 `qrcode[pil]`，无需手动安装 Python 包。
- `uv run scripts/learning_center_signin_qrcode.py` 生成北京时间当前起一分钟有效的签到码，默认 PNG 为 `build/learning-center-signin.png`，同时显示终端二维码及原始内容。
- 加 `--watch` 每 30 秒刷新同一 PNG；`--interval 1–59` 设置刷新间隔，`--output <path>` 指定输出文件，`--no-ascii` 关闭终端图形，Ctrl+C 停止刷新。

## 参考

参考项目统一存放在 `.reference/`，该目录不纳入版本控制。以下 URL 来自各本地仓库的 Git remote：

- [jwch](https://github.com/west2-online/jwch)（`.reference/jwch/`）：Go 教务处接口库，参考 HTML 解析、表单字段和 URL 格式。
- [fzuhelper-app](https://github.com/west2-online/fzuhelper-app)（`.reference/fzuhelper-app/`）：React Native 前端，参考 UI 交互和功能列表。
- [fzuhelper-server](https://github.com/west2-online/fzuhelper-server)（`.reference/fzu-helper-server/`）：福大助手 Go 服务端，参考业务设计。
- [FluxDown](https://github.com/zerx-lab/FluxDown)（`.reference/FluxDown/`）：Flutter 下载管理器，参考 Windows 安装包与自动更新流程。
- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)（`.reference/PiliPlus/`）：Flutter 哔哩哔哩客户端，参考 Flutter UI 与交互实现。

## Review 与界面约定

- 全应用的描述性文字只用一句简要概述，操作确认保留关键后果，不堆砌实现细节。
- 第三方服务使用三选按钮，左侧“隐藏”、中间“询问”、右侧“开启”，默认“询问”且不请求服务。
- review 修改直接 amend / squash 到对应功能的原提交，不创建额外 review 或 fixup 提交。
