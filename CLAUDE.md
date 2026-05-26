# FZU Assistant

福州大学一站式校园助手 —— 课表、成绩、考试、校历，开箱即用。

## 技术栈

- Flutter 3.x + Dart 3.x
- flutter_hooks（HookWidget / useState / useEffect / useMemoized）
- Dio + CookieJar 做 HTTP 请求，html 包解析 DOM
- charset 包处理 GBK 编码（校历页面）
- flutter_secure_storage 存储登录凭据
- flutter_localizations + intl 国际化（中英双语）
- flutter_staggered_grid_view 瀑布流网格布局
- re_editor + re_highlight 代码编辑器（JSON 语法高亮，开发者工具用）
- flutter_inappwebview 内置浏览器（Windows + Android，支持 Cookie 注入）
- flutter_local_notifications 本地通知（Android/iOS/Windows/macOS/Linux）
- android_alarm_manager_plus Android 精确闹钟调度（AlarmManager）
- timezone 时区支持（通知定时调度需要）
- permission_handler 统一权限管理（通知、精确闹钟等）

## 项目结构

如果你需要新建页面，请严格按照以下结构放置代码:
```
lib/
  main.dart              # 入口，IndexedStack + LayoutBuilder 自适应导航
  l10n/                  # 国际化
    app_localizations.dart    # 自动生成的本地化类
    app_localizations_zh.dart # 中文翻译
    app_localizations_en.dart # 英文翻译
  model/                 # 数据模型（纯 Dart class）
    course.dart          # 课程、课表规则、调课规则、当前周次、学期信息
    gpa.dart             # 绩点数据
    mark.dart            # 成绩记录
    unified_exam.dart    # 统考成绩（CET/省计算机）
    exam_room.dart       # 考场信息
    credit.dart          # 学分统计
    calendar.dart        # 校历（学期 + 事件）
    student_info.dart    # 学生个人信息
    empty_room.dart      # 空教室
    notice.dart          # 教务通知（列表 + 部门）
    github_release.dart  # GitHub Release 信息
    login_result.dart    # 登录结果
  common/                # 通用组件
    hooks/               # 自定义 Hooks
      use_mounted.dart   # 组件挂载状态 Hook
      use_permission.dart # 通用权限 Hook（permission_handler + ValueNotifier）
    utils/               # 工具函数
      cache_helper.dart  # 缓存辅助工具
      html_utils.dart    # HTML 解析工具
      context_ext.dart   # BuildContext 扩展（isLandscape 方向判断）
    widget/              # 通用组件
      tool_page_wrapper.dart  # 工具页包装器（loading/error/refresh/footer，支持 child 和 slivers 两种模式）
      masonry_sliver_grid.dart # 瀑布流网格封装（SliverMasonryGrid.extent + 断点常量）
      section.dart       # 区域组件
      term_selector_button.dart # 学期选择按钮
      half_screen_sheet.dart # 半屏弹窗
      update_dialog.dart # 更新对话框
  router/                # 路由
    app_routes.dart      # 路由表 + onGenerateRoute + context.push() 扩展
  constants/             # 常量
    sp_keys.dart         # SharedPreferences key
    breakpoints.dart     # 响应式断点（kTileMinWidth）
    site_injections.dart # WebView URI 正则 CSS/JS 注入规则
    time_slots.dart      # 课程时间段常量（11 个时段，1-based index）
  screen/
    guest/               # 匿名页面 如编辑器，webview等
      login.dart         # 登录页
      editor_page.dart   # 通用代码编辑器（re_editor + JSON 高亮）
      webview_page.dart  # 内置浏览器（flutter_inappwebview，支持 Cookie 注入，自动拼接教务处 URL 的 id 参数，CSS/JS 注入受 siteInjectionEnabled 控制，Windows+Android）
    schedule/            # 课程表（首页 tab）
      schedule.dart      # 课程表主页（状态管理 + _ScheduleBody 组件）
      schedule_grid.dart # 课程表网格（RefreshIndicator + SingleChildScrollView 包裹，支持下拉刷新）
      course_card.dart   # 课程卡片
    toolbox/             # 工具箱（首页 tab）
      toolbox.dart       # 工具箱主页（MasonrySliverGrid 自适应多列）
      gpa/               # 绩点信息
      marks/             # 成绩查询（MasonrySliverGrid 自适应多列）
      unified_exam/      # 统考成绩
      exam_room/         # 考场查询（MasonrySliverGrid 自适应多列）
      credit/            # 学分统计
      empty_room/        # 空教室查询（日期/节次/校区选择 + 结果列表）
      notice/            # 教务通知（分页列表，WebView 打开详情）
    my/                  # 我的（首页 tab）
      my.dart            # 我的页面主页
      about/             # 关于页
      calendar/          # 校历
    settings/            # 设置页（三个入口卡片）
      settings_page.dart # 设置页面主页（课表设置/一般设置/主题设置 三个入口）
      schedule_settings_page.dart # 课表设置（学期选择）
      general_settings_page.dart  # 一般设置（语言 + 网页注入开关）
      theme/             # 主题相关
        theme_section.dart # 主题设置页面（外观模式 + 主题色，含 ThemeTile 组件）
      permission_settings_page.dart # 权限管理（通知、精确闹钟权限检查与跳转）
      early_class_reminder_settings_page.dart # 早课提醒设置（开关/分钟/跳过周末/权限检查）
    dev/                 # 开发者工具
      dev_tool.dart      # 开发者工具主页（导航入口）
      shared_prefs_page.dart # SharedPreferences 查看/编辑/删除
      secure_storage_page.dart # SecureStorage 查看/编辑
      notification_debug_page.dart # 通知通道调试（AlarmManager vs WorkManager）
      early_class_reminder_page.dart # 早课提醒管理（开关/分钟滑块/跳过周末/重新调度）
      kv_tile.dart       # 通用键值对列表项组件（支持 onTap 编辑）
  service/               # 业务逻辑
    auth_storage.dart    # 凭据存储
    captcha_solver.dart  # 验证码识别
    update_service.dart  # 更新检查服务
    app_themes.dart      # 主题色列表 + buildTheme()
    notification_service.dart # 通知服务（AlarmManager 调度，flutter_local_notifications 显示）
    early_class_reminder_service.dart # 早课提醒（每天晚上提醒明天第一节课，AlarmManager 定时调度）
    api/                 # API 相关服务
      api_client.dart    # Dio 单例，登录/重登/拦截器
      academic_service.dart # 教务处数据抓取（GPA/成绩/考场/校历/空教室/通知/讲座）
      user_service.dart  # 用户信息
      course_service.dart # 课程表
      login_service.dart # 登录服务
      html_helper.dart   # HTML 解析辅助
    settings/
      app_settings.dart  # 统一设置管理（主题 + 语言 + 学期 + 网页注入，InheritedWidget + SP 持久化）
```

## 编码规范

- **每次项目结构或技术栈变更后，必须同步更新本 CLAUDE.md 文件**

- 页面统一用 HookWidget，状态用 useState/useEffect/useMemoized
- 导航统一使用 `context.push(page)` / `context.pushReplacement(page)` / `context.pushNamed(route)` 扩展方法（定义在 `lib/router/app_routes.dart`），禁止直接写 `Navigator.push(context, MaterialPageRoute(...))`
- 工具箱内所有工具页使用 ToolPageWrapper 包装（loading、error、空数据、下拉刷新、数据更新时间），`emptyText` 为必填参数；需要瀑布流的页面传 `slivers` 参数，普通列表传 `child` 参数
- 多列自适应布局统一使用 `MasonrySliverGrid`（封装自 `lib/common/masonry_sliver_grid.dart`），列宽断点从 `lib/constants/breakpoints.dart` 的 `kTileMinWidth` 读取
- 横屏/宽屏自动切换侧栏导航（NavigationRail），窄屏使用底部导航栏（BottomNavigationBar），通过 `context.isLandscape`（`common/utils/context_ext.dart`）判断方向
- 响应式断点常量统一定义在 `lib/constants/breakpoints.dart`
- 教务处数据抓取在 AcademicService 中实现，用 Dio GET/POST 请求 HTML 页面，html 包解析 DOM
- 教务处页面多为 GBK 编码，用 `charset` 包的 `gbk.decode()` 解码
- 请求教务处接口需要带 `queryParameters: {'id': userId}`
- ASP.NET WebForms 页面需要先 GET 获取 __VIEWSTATE/__EVENTVALIDATION，再 POST 提交
- 工具页数据列表优先使用 Table 布局（对齐整齐），不用手搓 Row+Card
- UI 文本必须通过 `AppLocalizations.of(context)!.xxx` 引用，禁止硬编码中文/英文字符串
- Service 层错误消息保留中文（无 BuildContext），UI 层捕获后展示
- 状态管理模式：AppSettingsProvider 使用 InheritedWidget + ValueNotifier + SharedPreferences 持久化

## 国际化

- 使用 Flutter 官方 `gen-l10n` 方案，配置文件 `l10n.yaml`
- ARB 文件：`lib/l10n/app_zh.arb`（中文）、`lib/l10n/app_en.arb`（英文）
- 添加新语言：新建 `app_XX.arb` → `flutter gen-l10n` → 在 `AppSettings._localeOptions` 注册
- 语言切换：「我的 → 设置 → 一般设置 → 语言」SegmentedButton 选择，通过 `AppSettings` 持久化到 SharedPreferences
- `MaterialApp.locale` 绑定 `AppSettings.currentLocale`，`null` 表示跟随系统

## Windows 注意事项

- `flutter_inappwebview` 在 Windows 上需要 WebView2 Runtime
- `windows/runner/flutter_window.cpp` 中有 `closeWindow` 方法频道的 workaround（修复关窗 bug）
- `main.dart` 中需初始化 `WebViewEnvironment`，`userDataFolder` 设在 app support 目录

## 构建

```bash
flutter run                    # 开发运行
flutter build apk              # Android 打包
flutter analyze                # 静态分析
flutter gen-l10n               # 重新生成国际化代码
```

## 参考

- jwch Go 库（`tmp/jwch/`）：教务处抓包逻辑参考（HTML 解析、表单字段、URL 格式）
- fzuhelper-app（`tmp/fzuhelper-app/`）：React Native 前端参考（UI 交互、功能列表）
