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
  main.dart              # 应用初始化、主题配置与启动页
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
  common/                # 通用组件
    utils/               # 工具函数
      cache_helper.dart  # 缓存辅助工具
      html_utils.dart    # HTML 解析工具
      context_ext.dart   # BuildContext 扩展（isLandscape 方向判断）
      course_sessions.dart # 周/天视图共用的课程筛选与节次时间
    widget/              # 通用组件
      navigation/home_view_toggle.dart # 首页周视图/天视图切换
      tool_page_wrapper.dart  # 工具页包装器（loading/error/refresh/footer，支持 child 和 slivers 两种模式）
      masonry_sliver_grid.dart # 瀑布流网格封装（SliverMasonryGrid.extent + 断点常量）
      section.dart       # 区域组件
      term_selector_button.dart # 学期选择按钮
      half_screen_sheet.dart # 半屏弹窗
      update_dialog.dart # 更新对话框
  router/                # 路由
    app_routes.dart      # 路由名、参数对象与命名导航扩展
    app_router.dart      # 集中式路由表与页面构建
  constants/             # 常量
    sp_keys.dart         # SharedPreferences key
    breakpoints.dart     # 响应式断点（kTileMinWidth）
    site_injections.dart # WebView URI 正则 CSS/JS 注入规则
  screen/
    guest/               # 匿名页面 如编辑器，webview等
      login.dart         # 登录页
      editor_page.dart   # 通用代码编辑器（re_editor + JSON 高亮）
      webview_page.dart  # 内置浏览器（flutter_inappwebview，支持 Cookie 注入，自动拼接教务处 URL 的 id 参数，CSS/JS 注入受 siteInjectionEnabled 控制，Windows+Android）
    schedule/            # 课程表（首页 tab）
      schedule.dart      # 课程表主页（状态管理 + _ScheduleBody 组件）
      schedule_grid.dart # 课程表网格（RefreshIndicator + SingleChildScrollView 包裹，支持下拉刷新）
      course_card.dart   # 课程卡片
    home/                # 首页天视图
      home_screen.dart   # 首页壳，管理自适应导航与三个主 Tab
      home_timeline_page.dart # 时间线首页（课程 + 校历事件 + 学期概览）
      timeline_events.dart # 校历事件日期解析与单日/跨日拆分
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
    settings/            # 设置页（首页/一般/主题/高级设置入口）
      settings_page.dart # 设置页面主页
      home_settings_page.dart # 首页设置（视图、时间线范围、学期及课表选项）
      general_settings_page.dart  # 一般设置（语言 + 网页注入开关）
      theme/             # 主题相关
        theme_section.dart # 主题设置页面（外观模式 + 主题色，含 ThemeTile 组件）
    dev/                 # 开发者工具
      dev_tool.dart      # 开发者工具主页（导航入口）
      shared_prefs_page.dart # SharedPreferences 查看/编辑/删除
      secure_storage_page.dart # SecureStorage 查看/编辑
      kv_tile.dart       # 通用键值对列表项组件（支持 onTap 编辑）
  service/               # 业务逻辑
    auth_storage.dart    # 凭据存储
    captcha_solver.dart  # 验证码识别
    update_service.dart  # 更新检查服务
    app_themes.dart      # 主题色列表 + buildTheme()
    webview_environment.dart # Windows WebView2 环境初始化
    api/                 # API 相关服务
      api_client.dart    # Dio 单例，登录/重登/拦截器
      academic_service.dart # 教务处数据抓取（GPA/成绩/考场/校历/空教室/通知/讲座）
      user_service.dart  # 用户信息
      course_service.dart # 课程表
      html_helper.dart   # HTML 解析辅助
    settings/
      app_settings.dart  # 统一设置管理（主题 + 语言 + 学期 + 网页注入，InheritedWidget + SP 持久化）
```

## 编码规范

- **每次项目结构或技术栈变更后，必须同步更新本 CLAUDE.md 文件**

- 页面统一用 HookWidget，状态用 useState/useEffect/useMemoized
- 页面导航统一使用 `context.pushNamed(AppRoutes.xxx)` / `context.pushReplacementNamed(AppRoutes.xxx)`；路由名和参数定义在 `app_routes.dart`，页面构建集中在 `app_router.dart`，禁止页面直接构造 `MaterialPageRoute`
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
- `service/webview_environment.dart` 中初始化 `WebViewEnvironment`，`userDataFolder` 设在 app support 目录

## 构建

```bash
flutter run                    # 开发运行
flutter build apk              # Android 打包
flutter build windows --release # Windows 打包（输出 build/windows/x64/runner/Release）
flutter analyze                # 静态分析
flutter gen-l10n               # 重新生成国际化代码
```

### Windows 安装包（Inno Setup）

安装脚本 `installer/windows/setup.iss`（抄自 zerx-lab/FluxDown），CI 在 `flutter build windows` 之后调用：

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

`UpdateService.installWindowsUpdate()` 下载 release 里的 `*-setup.exe` 后静默执行：

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
  **便携版不自我更新**：`{app}` 指向安装目录，跑安装器会悄悄多装一份而不是更新当前这份，
  因此便携版回退到「打开下载页」并提示。
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

安装包与自动更新链路无法在本地端到端验证（需要真实 release 资产），
因此**打了第一个带 `-setup.exe` 的 tag 之后**，务必在干净环境上人工走一遍：

1. 从 Release 下载 `FZU-Assistant-<version>-windows-x64-setup.exe`，双击安装：
   确认**没有 UAC 弹窗**、装在 `%LOCALAPPDATA%\Programs\FZU Assistant`、
   开始菜单与桌面快捷方式正常。
2. 打开应用 →「我的 → 关于 → 检查更新」：应显示新版本，点「下载并安装」后
   应用**自动退出 → 静默安装 → 自动重启**，版本号已更新。
3. 便携版（`fzu_assistant-windows-*.zip`）解压运行 → 检查更新：
   按钮应为「前往下载」，点后提示「当前为便携版，无法自动更新」并打开下载页，
   **不得**在 `%LOCALAPPDATA%\Programs` 里多出一份安装。
4. 设置 →「应用和功能」卸载：目录、注册表 Run 值、开始菜单项全部清干净。

失败时 Inno 会在 `%TEMP%\Setup Log*.txt` 留日志；静默参数与 `setup.iss` 的配对关系见上一节。

### 本次改动（v1.3.2）

- 新增 `installer/windows/setup.iss` + `ChineseSimplified.isl`：Inno Setup 每用户安装包
- CI 在 `flutter build windows` 后调用 `iscc`，artifact 与 Release 一并上传 `*-setup.exe`
- 应用内 Windows 自动更新：下载 setup.exe → `/SILENT` 安装 → 退出 → 自动重启
- 便携版不做自我更新，回退到打开下载页

## 参考

- jwch Go 库（`tmp/jwch/`）：教务处抓包逻辑参考（HTML 解析、表单字段、URL 格式）
- fzuhelper-app（`tmp/fzuhelper-app/`）：React Native 前端参考（UI 交互、功能列表）
