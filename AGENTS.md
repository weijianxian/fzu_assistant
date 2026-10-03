# FZU Assistant

福州大学一站式校园助手 —— 课表、成绩、考试、校历，开箱即用。

## 技术栈

- Flutter 3.47.6 + Dart 3.x
- flutter_hooks（HookWidget / useState / useEffect / useMemoized）
- Dio + CookieJar 做 HTTP 请求，html 包解析 DOM
- charset 包处理 GBK 编码（校历页面）
- flutter_secure_storage 存储登录凭据
- flutter_localizations + intl 国际化（中英双语）
- flutter_staggered_grid_view 瀑布流网格布局
- re_editor + re_highlight 代码编辑器（JSON 语法高亮，开发者工具用）
- flutter_inappwebview 内置浏览器（Windows + Android，支持 Cookie 注入）
- window_manager（Windows 自绘标题栏、窗口操作与状态监听）
- integration_test（macOS / iOS 原生插件冒烟测试，配合 GitHub Actions macOS runner）

## 项目结构

如果你需要新建页面，请严格按照以下结构放置代码:
```
lib/
  main.dart              # 应用初始化、主题配置、全局横向 SafeArea（顶部/底部背景沉浸，由 AppBar 或页面内容避让系统栏）与启动页
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
      layout/desktop_window_frame.dart # Windows 全局窗口壳（自绘标题栏、提示 Overlay、内容裁剪与顶部缩放）
      layout/split_navigation_page.dart # 横屏两栏导航（左 1/3 功能按钮、右 2/3 独立详情导航）
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
    breakpoints.dart     # 响应式尺寸（横向课表最小节次列宽、日期列宽与行高）
    site_injections.dart # WebView URI 正则 CSS/JS 注入规则
  screen/
    guest/               # 匿名页面 如编辑器，webview等
      login.dart         # 登录页
      editor_page.dart   # 通用代码编辑器（re_editor + JSON 高亮）
      webview_page.dart  # 内置浏览器（flutter_inappwebview，支持 Cookie 注入，自动拼接教务处 URL 的 id 参数，CSS/JS 注入受 siteInjectionEnabled 控制，Windows+Android）
    schedule/            # 课程表（首页 tab）
      schedule.dart      # 课程表主页（状态管理 + _ScheduleBody，横屏使用浮动操作按钮）
      widgets/
        schedule_grid.dart # 课表方向切换、课程/调课/考试映射与详情，支持下拉刷新
        horizontal_schedule_grid.dart # 横屏周课表（固定日期列/周次与节次表头、横向时间轴、时段分组、今天高亮及默认聚焦今日/当前时间，手机隐藏滚动条）
        course_card.dart   # 课程卡片（横屏浅色底与课程色条）
        floating_schedule_controls.dart # 横屏视图切换、设置及翻周悬浮按钮，叠在时间轴上方、避开日期列和系统安全区域，窄窗自动换行
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
      profile_page.dart  # 个人资料（竖屏嵌入我的页面，横屏显示在右栏）
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
    desktop_window.dart # Windows 窗口初始化、状态监听与统一关闭行为
    api/                 # API 相关服务
      api_client.dart    # Dio 单例，登录/重登/拦截器
      academic_service.dart # 教务处数据抓取（GPA/成绩/考场/校历/空教室/通知/讲座）
      user_service.dart  # 用户信息
      course_service.dart # 课程表 + 可选 west2 调休数据（公开接口、按学期缓存）
      html_helper.dart   # HTML 解析辅助
    settings/
      app_settings.dart  # 统一设置管理（主题 + 语言 + 学期 + 网页注入，InheritedWidget + SP 持久化）
```

## 编码规范

- **每次项目结构或技术栈变更后，必须同步更新本 AGENTS.md 文件**

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
- 每次做完一个功能，就 commit 一次，提交信息遵循下方规范。

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

- `.github/workflows/build.yaml` 负责 main/tag/手动触发、调用各平台构建及汇总 Release。
- 平台构建分别位于 `windows.yaml`、`android.yaml`、`apple.yaml` 和 `linux.yaml`，均支持 `workflow_call` 与手动执行。
- 主工作流显式向 Android 子工作流传递 `KEY_STORE_PASSWORD`、`KEY_PASSWORD`、`KEY_ALIAS` 和 `KEYSTORE_BASE64` 四项签名 secrets；手动执行 Android 工作流时使用仓库 secrets。
- 主工作流和各平台工作流均按平台前缀、workflow 和 ref 设置 concurrency；同一分支的新运行取消旧运行，tag 构建不主动取消。

### Linux

- 原生工程位于 `linux/`，可执行文件名为 `fzu_assistant`。
- `.github/workflows/linux.yaml` 在 Ubuntu 24.04 runner 的 Debian forky 容器内构建 x86_64 release；当前 WebView 插件需要 WPE WebKit >= 2.50（trixie 仅提供 2.48，Ubuntu 24.04 缺少 WPE 包）。支持统一开发分支 `feat/platform-builds` 推送、PR、手动执行及主构建流程调用，tag Release 包含 Linux 产物。
- CI 安装 Flutter 的 GTK/Clang/CMake/Ninja 构建依赖，以及 WebView 插件的 WPE WebKit、WPEBackend-FDO、libwpe、epoxy、Wayland 和凭据存储的 libsecret 开发包。
- `linux/CMakeLists.txt` 针对 WPE >= 2.54 为 WebView beta 插件提供动画设置更名的兼容定义；升级插件后需检查是否可以移除。
- 发布包为 `FZU-assistant-v<version>-linux-x86_64.tar.gz`，包含完整 bundle，保留可执行权限与符号链接；解压后运行 `./fzu_assistant`。目标系统需提供与 Debian forky 构建兼容的 glibc、GTK、WPE WebKit 等运行库，凭据存储需要可用的 Secret Service。
- Windows 无法执行 Linux 原生构建，需在 Linux 或 GitHub Actions Ubuntu runner 上验证。

```bash
flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release
```

### macOS / iOS（暂不配置开发者签名）

- 原生工程：`macos/`、`ios/`；均使用 CocoaPods，最低系统版本为 macOS 12、iOS 15。Flutter 配置使用 `--no-enable-swift-package-manager`，与仓库内 Podfile 保持一致。
- macOS 沿用原生标题栏，Bundle ID 为 `com.weijx.fzuAssistant`，应用名为 `FZU Assistant`；Debug/Profile 和 Release 均需保留 `com.apple.security.network.client`，否则教务请求无法联网。
- macOS 使用本地 ad-hoc 签名（`CODE_SIGN_IDENTITY = -`），不配置 Apple Developer 证书、开发团队、Provisioning Profile 或公证；DMG 本身不签名。不要把 ad-hoc 签名误认为 Developer ID 发布签名。
- macOS 凭据使用 `MacOsOptions(usesDataProtectionKeychain: false)` 的传统 Keychain，不启用 Keychain Sharing，避免未配置开发者签名时需要 Provisioning Profile。
- iOS 保留 Keychain entitlements，使用 `flutter build ios --release --no-codesign`；把 `build/ios/iphoneos/Runner.app` 放进 `Payload/Runner.app` 后压成 IPA。未签名 IPA 需要用户另行签名才能安装到真机，不用于 App Store 发布。
- Apple 图标由 `assets/icon/icon.png`（iOS，移除 alpha）及 `assets/icon/icon_windows.png`（macOS）生成；配置在 `pubspec.yaml` 的 `flutter_launcher_icons`，生成后提交原生 Assets 目录。
- `.github/workflows/apple.yaml` 是可复用构建流程：在 PR 或手动执行时独立运行，主构建流程 `build.yaml` 调用它并把 DMG/IPA 加入 tag Release。Apple/Linux 改动统一在 `feat/platform-builds` 分支开发。
- macOS 发布包为 universal（arm64 + x86_64）；产物命名为 `FZU-assistant-v<version>-macos-universal-unsigned.dmg` 和 `FZU-assistant-v<version>-ios-arm64-unsigned.ipa`。Apple CI 仅构建、打包和上传产物，不再执行静态分析、测试或产物校验；独立 Check 工作流已移除。
- 原生冒烟测试放在 `integration_test/apple_smoke_test.dart`，覆盖 Keychain 凭据读写/删除、设置页和原生 WebView 的 HTML/JavaScript；需要时手动在 macOS 和 iPhone 模拟器运行，无需教务账号。普通单元/组件测试使用 `flutter test`。
- Windows 无法执行 Apple 原生构建；构建和原生冒烟测试必须在有 Xcode 的 macOS 上或 GitHub Actions 的 macOS runner 上验证。

```bash
flutter config --enable-ios --enable-macos-desktop --no-enable-swift-package-manager
flutter pub get
flutter test integration_test/apple_smoke_test.dart -d macos
flutter test integration_test/apple_smoke_test.dart -d <iPhone模拟器ID>
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

## 参考

参考项目统一存放在 `.reference/`，该目录不纳入版本控制。以下 URL 来自各本地仓库的 Git remote：

- [jwch](https://github.com/west2-online/jwch)（`.reference/jwch/`）：Go 教务处接口库，参考 HTML 解析、表单字段和 URL 格式。
- [fzuhelper-app](https://github.com/west2-online/fzuhelper-app)（`.reference/fzuhelper-app/`）：React Native 前端，参考 UI 交互和功能列表。
- [fzuhelper-server](https://github.com/west2-online/fzuhelper-server)（`.reference/fzu-helper-server/`）：福大助手 Go 服务端，参考业务设计。
- [FluxDown](https://github.com/zerx-lab/FluxDown)（`.reference/FluxDown/`）：Flutter 下载管理器，参考 Windows 安装包与自动更新流程。
- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)（`.reference/.PiliPlus/`）：Flutter 哔哩哔哩客户端，参考 Flutter UI 与交互实现。
