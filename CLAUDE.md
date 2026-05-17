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

## 项目结构

如果你需要新建页面，请严格按照以下结构放置代码:
```
lib/
  main.dart              # 入口，IndexedStack + LayoutBuilder 自适应导航
  l10n/                  # 国际化
    app_zh.arb           # 中文翻译
    app_en.arb           # 英文翻译
    locale_provider.dart # 语言状态管理（InheritedWidget）
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
    lecture.dart         # 讲座信息
  common/                # 通用组件
    tool_page_wrapper.dart  # 工具页包装器（loading/error/refresh/footer，支持 child 和 slivers 两种模式）
    masonry_sliver_grid.dart # 瀑布流网格封装（SliverMasonryGrid.extent + 断点常量）
  constants/             # 常量
    sp_keys.dart         # SharedPreferences key
    breakpoints.dart     # 响应式断点（kNavBreakpoint、kTileMinWidth）
    site_injections.dart # WebView URI 正则 CSS/JS 注入规则
  screen/
    guest/               # 匿名页面 如编辑器，webview等
      login.dart         # 登录页
      editor_page.dart   # 通用代码编辑器（re_editor + JSON 高亮）
      webview_page.dart  # 内置浏览器（flutter_inappwebview，支持 Cookie 注入，Windows+Android）
    schedule/            # 课程表（首页 tab）
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
      about/             # 关于页
      calendar/          # 校历
    settings/            # 主题设置
    dev/                 # 开发者工具
      dev_tool.dart      # 开发者工具主页（导航入口）
      shared_prefs_page.dart # SharedPreferences 查看/编辑/删除
      secure_storage_page.dart # SecureStorage 查看/编辑
      kv_tile.dart       # 通用键值对列表项组件（支持 onTap 编辑）
  service/               # 业务逻辑
    api_client.dart      # Dio 单例，登录/重登/拦截器
    academic_service.dart # 教务处数据抓取（GPA/成绩/考场/校历/空教室/通知/讲座）
    user_service.dart    # 用户信息
    course_service.dart  # 课程表
    auth_storage.dart    # 凭据存储
    captcha_solver.dart  # 验证码识别
  theme/                 # 主题配置
    theme_provider.dart  # 主题状态管理（InheritedWidget）
```

## 编码规范

- **每次项目结构或技术栈变更后，必须同步更新本 CLAUDE.md 文件**

- 页面统一用 HookWidget，状态用 useState/useEffect/useMemoized
- 工具箱内所有工具页使用 ToolPageWrapper 包装（loading、error、空数据、下拉刷新、数据更新时间），`emptyText` 为必填参数；需要瀑布流的页面传 `slivers` 参数，普通列表传 `child` 参数
- 多列自适应布局统一使用 `MasonrySliverGrid`（封装自 `lib/common/masonry_sliver_grid.dart`），列宽断点从 `lib/constants/breakpoints.dart` 的 `kTileMinWidth` 读取
- 横屏/宽屏自动切换侧栏导航（NavigationRail），窄屏使用底部导航栏（BottomNavigationBar），断点为 `kNavBreakpoint`
- 响应式断点常量统一定义在 `lib/constants/breakpoints.dart`
- 教务处数据抓取在 AcademicService 中实现，用 Dio GET/POST 请求 HTML 页面，html 包解析 DOM
- 教务处页面多为 GBK 编码，用 `charset` 包的 `gbk.decode()` 解码
- 请求教务处接口需要带 `queryParameters: {'id': userId}`
- ASP.NET WebForms 页面需要先 GET 获取 __VIEWSTATE/__EVENTVALIDATION，再 POST 提交
- 工具页数据列表优先使用 Table 布局（对齐整齐），不用手搓 Row+Card
- UI 文本必须通过 `AppLocalizations.of(context)!.xxx` 引用，禁止硬编码中文/英文字符串
- Service 层错误消息保留中文（无 BuildContext），UI 层捕获后展示
- 状态管理模式：ThemeProvider / LocaleProvider 使用 InheritedWidget + ValueNotifier + SharedPreferences 持久化

## 国际化

- 使用 Flutter 官方 `gen-l10n` 方案，配置文件 `l10n.yaml`
- ARB 文件：`lib/l10n/app_zh.arb`（中文）、`lib/l10n/app_en.arb`（英文）
- 添加新语言：新建 `app_XX.arb` → `flutter gen-l10n` → 在 `LocaleState.locales` 注册
- 语言切换：「我的 → 语言」弹窗选择，通过 `LocaleProvider` 持久化到 SharedPreferences
- `MaterialApp.locale` 绑定 `LocaleState.currentLocale`，`null` 表示跟随系统

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
