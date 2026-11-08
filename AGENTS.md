# FZU Assistant

福州大学一站式校园助手 —— 课表、成绩、考试、校历，开箱即用。

## UI 设计规范

- 新增、修改或检查界面前，必须先阅读根目录 [design.md](design.md)。Material 3、界面风格、共享组件、提示卡片、布局、安全区、弹层与页面交互规则统一维护在该文件；本文件保留业务、数据、权限、架构、构建和提交约束。

## 技术栈

- Flutter 3.47.6 + Dart 3.x
- open_filex（Android/iOS 文件打开）、share_plus（原生文件分享；Linux 使用文件目录/路径回退）
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
- tray_manager（Windows 原生托盘图标、显示窗口与明确退出菜单）
- pointycastle（统一身份认证 AES-ECB / PKCS#7 加密）、mobile_scanner（Android / iOS / macOS 学习中心现场扫码签到）
- geolocator（晚点名网页的前台定位、系统权限和原生定位协议回调）
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
    course_live_update.dart # Android 课程实况的上午/下午/晚上状态与切换时间
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
      layout/app_section.dart # 全应用风格表面、连接分组、懒加载列表项及自适应分隔；课程表网格不接入
      layout/app_expansion_tile.dart # 全应用共享的原生展开列表项，统一取消展开及收起边框
      feedback/app_info_card.dart # 独立短提示共享卡片：info 图标、简短说明及可选副标题
      layout/app_top_banner.dart # 缓存提示条背景延伸至状态栏，内容边距统一处理
      input/password_field.dart # 教务和 SSO 登录共用密码框、显隐按钮及自动填充
      layout/desktop_window_frame.dart # Windows 全局窗口壳（自绘标题栏、提示 Overlay、内容裁剪与顶部缩放）
      layout/split_navigation_page.dart # 横屏两栏导航（左 1/3 功能按钮、右 2/3 独立详情导航）
      tool_page_wrapper.dart  # 工具页包装器（loading/error/refresh/footer，支持 child 和 slivers 两种模式）
      masonry_sliver_grid.dart # 瀑布流网格封装（SliverMasonryGrid.extent + 断点常量）
      section.dart       # 区域组件
      term_selector_button.dart # 学期选择按钮
      half_screen_sheet.dart # 横屏右侧占窗口2/3，竖屏底部拖拽，独立滚动并按屏幕外侧避让系统栏
      sheet/app_bottom_sheet.dart # 普通内容的滚动适配入口，复用 showHalfScreenSheet 的横竖屏弹层、安全区及键盘处理
      sheet/sheet_drag_handle.dart # 统一顶部拖动柄，上下各8逻辑像素留白
      settings/          # MD3 设置分组、开关、单选弹层、状态、权限及操作组合
        settings_radio_tile.dart # 复用原生 RadioListTile，与普通设置图标及标题统一对齐
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
      academic/          # 教务快捷入口（选课、教务申请、学生证与附卡、毕业设计、嘉锡讲坛，复用带 Cookie 的 WebView）
      learning_center/   # 学习中心：独立 SSO 登录、4/5 层座位查询/预约、时段查询、分页预约记录、取消/签到/签退
        learning_center_page.dart # 入口与 SSO 会话管理
        learning_seats_page.dart # 北京时间未来七天日期卡片、四列半小时时间格和区间高亮；查询后 push 独立座位列表页，返回保留选择
        learning_available_seats_page.dart # 按日期/时段/楼层查询座位，参考 fzuhelper-app 分区、座位类型与空闲/占用统计，32px 右侧索引支持点击/连续滑动跳转及随列表滚动高亮当前区域；固定行高 SliverGrid 稳定滚动范围；占用座位 push 时段页，可用座位使用服务端 spaceId 预约
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
      settings_page.dart # 设置页面主页；底部自适应分隔后直接展示当前平台支持的功能入口或开关，无平台分类页
      course_reminder_settings_page.dart # Android 早课提醒：提醒开关、北京时间及通知/精确闹钟授权和通知渠道管理
      course_live_updates_settings_page.dart # Android 课程实况开关及通知、精确闹钟与实况授权
      android_permissions_page.dart # Android 预期权限固定清单：标题为权限名称，说明为具体用途和授权状态；不扫描权限，不展示 ID/类型，返回应用自动刷新
      windows_background_settings_page.dart # Windows 关闭到托盘开关与真实可用状态
      windows_notifications_settings_page.dart # Windows 明日课程及课程阶段通知，不暴露 Android 授权项
      schedule_sync_settings_page.dart # Android 夜间自动更新课表：统一手动更新、夜间自动开关/时间、精确闹钟权限及最近/下次同步状态
      home_settings_page.dart # 课表设置（学期单选弹层、课表显示、自定义课程及不展示课程；Android 日历同步在平台功能区）
      hidden_courses_page.dart # 独立管理当前账号的隐藏课程并逐项或全部恢复
      general_settings_page.dart  # 一般设置（语言 + 网页注入开关）
      theme/             # 主题相关
        theme_section.dart # 主题库、导入导出分享、界面风格、外观模式和竖向默认色卡
        theme_editor_page.dart # 基础信息、亮暗独立草稿、背景图片、课表色卡及顶部手机比例的真实课表预览
        theme_schedule_preview.dart # 只读本地缓存，按手机逻辑尺寸渲染首页 ScheduleGrid 后等比例缩放
    dev/                 # 开发者工具
      dev_tool.dart      # 开发者工具主页（英文标题/自适应分隔原页分组，保留原有导航与操作）
      learning_center_debug_page.dart # 学习中心 API 调试：分组操作按钮、token 显隐、原始参数/spaceId 直传、HTTP 状态和原始响应；无业务校验和确认弹窗
      shared_prefs_page.dart # SharedPreferences 查看/编辑/删除
      secure_storage_page.dart # SecureStorage 查看/编辑
      kv_tile.dart       # 通用键值对列表项组件（支持 onTap 编辑）
  service/               # 业务逻辑
    auth_storage.dart    # 凭据存储
    account_service.dart # 当前教务/SSO 会话状态与退出清理；教务退出先清 SSO 再清凭据和账号缓存
    captcha_solver.dart  # 验证码识别
    update_service.dart  # 更新检查服务
    app_themes.dart      # 默认色卡、统一 ThemeData 和 InterfaceTheme（经典列表/卡片分组）
    theme_visuals.dart   # Material 颜色角色与背景、课表、圆角和分割线的主题扩展
    theme_customization_service.dart # 应用目录主题 JSON/图片、校验和包含图片的可分享主题包
    theme_image_palette.dart # 后台解码及 Material 图片种子取色，不改变 dynamic_color 版本
    webview_environment.dart # Windows WebView2 环境初始化
    desktop_window.dart # Windows 窗口初始化、状态监听与统一关闭行为
    windows_background_service.dart # Windows 本机驻留偏好、托盘生命周期、恢复与明确退出
    course_reminder_service.dart # Android 明日课程提醒计划：缓存校历和课表、北京时间、调课与隐藏课程过滤；预排 180 天
    course_live_update_service.dart # Android 官方实况通知展示与独立开发者测试
    course_live_updates_controller.dart # 读取已接受的本地课表快照并安排真实课程实况
    android_task_scheduler.dart # android_alarm_manager_plus 的命名任务分发、后台入口、计划持久化/取消与 flutter_local_notifications 展示
    android_permissions_service.dart # 应用预期权限的实际授权状态读取和系统权限设置跳转
    api/                 # API 相关服务
      api_client.dart    # Dio 单例与请求会话代次；显式登录/退出使旧请求失效，同账号自动续会话可重试并继续保存有效结果；studentId 为稳定学号，userId 为会话 identifier
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

- `model/campus_service.dart` 定义 31 项官方校园服务，`screen/toolbox/campus_services/campus_services_page.dart` 按生活住宿、空间预约、学习活动、信息办事、地图校园网分组；保留原有公寓报修等入口，补齐邮箱、可信电子文档、统一支付、智慧学工、地图和网络服务。所有入口禁用教务 Cookie，公开地图、通知文件、网络指南与讲座报告不要求 SSO，其余复用统一认证；不预请求、不重复列出同地址的校园／校友活动。`WebViewArgs.injectSsoCookies` 区分统一认证与教务会话，SSO 登录复用不申请学习中心 token 的页面。WebView 为 HookWidget，SOURCEID_TGC 仅注入 SSO HTTPS host；退出清理原生 Cookie，挂载页面按会话代次销毁旧内容。外部 App 协议仅在用户点击时打开。
- `service/webview_campus_bridge.dart` 参考 FUU 兼容晚点名 `kysk-fdxy-app` 的定位与权限回调，仅允许 `https://yzsxg.fzu.edu.cn` 的晚点名主文档；HTML5 定位同样验证来源。通过 geolocator 请求系统前台权限和当前坐标，不保存位置、不申请后台定位、不请求第三方地址反解；拒绝或失败回传空结果，导航、退出或换号使在途回调失效。Android WebView 使用系统 UA 追加校园 App 标识，SSO 登录请求使用相同 UA，学习中心 token 请求保留独立 UA。

## 自定义课程

- `model/custom_course.dart` 和 `service/custom_course_store.dart` 管理本地自定义课程；按稳定学号、学期、ID 隔离，存储键 `custom_courses_v1`，不写教务缓存、退出不删除。`screen/settings/custom_courses_page.dart` 提供新增/编辑/删除、周次单双周/星期/节次、教师地点备注和颜色，参数定义在 app_routes.dart。课表设置并列提供自定义课程管理与不展示课程管理入口，首页右上角加号直接打开创建页，周课表和提醒合并课程并监听修改，缺少正式课表/校历时提醒继续提示未知而不误报无课。

## 日历导出

- Android `screen/settings/calendar_sync_settings_page.dart` 直接写入系统日历；`service/calendar_sync_service.dart` 管理默认关闭的日历写入开关、考试及提前提醒，需日历读写授权。手动更新、夜间自动同步开关/时间、精确闹钟权限和刷新状态集中在平台功能区的“夜间自动更新课表”页 `screen/settings/schedule_sync_settings_page.dart`，小组件和日历同步页仅保留各自选项，不添加跳转到夜间更新页的重复入口，保存提示也不提供该跳转。复用 WidgetSyncService 的命名精确唤醒任务、登录及完整课表刷新，同次刷新更新缓存、小组件与已开启的日历，不另建原生调度层。前台缓存及课程设置更新时，同次本地快照发布将当前及临近完整学期写入已开启的日历；只使用本地缓存，不重复联网，不改夜间任务时间或成功状态。发布与日历配置、退出共用原生锁并校验账号与输入基线，关闭日历时不写入，旧会话响应不得回写课程或校历缓存。统一自动同步开关默认开启，默认北京时间 23:00；关闭后日历写入选择保留，允许手动同步且不要求精确闹钟权限。旧配置按“小组件夜间开关或日历开关”迁移有效自动状态，首次配置后统一开关独立控制后台任务。重新进入前台恢复计划，插件负责重启恢复，联网前先安排次日闹钟。
- `model/calendar_sync.dart` 与 `model/calendar_export.dart` 共用实际课程计算、UTC 时间和稳定哈希 UID；Android 必须使用系统重复日程，不按常规上课次数展开写入独立事件。同课程的星期、节次和地点合并为有学期截止的每周/隔周 RRULE，停课、单次隐藏及不连续周次使用 EXDATE，单次调课/换教室通过 ORIGINAL_ID / ORIGINAL_SYNC_ID / ORIGINAL_INSTANCE_TIME 关联原重复日程；仅考试和没有原始节次的单次补课使用独立事件。常规重复项使用 DURATION 而非 DTEND。合并当前及临近学期、自定义课程、已授权缓存调休和单次隐藏，考试解析失败保留对应旧日程。后台仅用安全存储教务凭据，不写回前台会话，不请求 SSO/支付或未授权第三方接口。
- 本地插件 `SystemCalendarSync.kt` 在所有 Flutter 引擎自动注册，通过 Android Calendar Provider 创建按账号哈希隔离的本地专属日历；`CalendarReconcile.kt` 仅对完整刷新学期中有应用标记的事件比对增删改，保留手工日程与其他日历，重复同步不新增重复项。配置、退出及前台输入写入与后台提交共用原生锁和代次基线；失败保留旧数据，提供最近成功时间及新增/更新/删除数量。关闭或教务退出停止日历同步，保留已写入日程，换账号需重新开启。不将同步配置/状态加入 WebDAV。
- 新重复日程使用 `fzu-v2` UID；成功写入重复项和单次例外后，按完整学期范围迁移清理旧 `fzu-v1` 展开课程，考试保留原 UID。父项先于例外写入，例外先于父项删除，真实 Calendar Provider 的 Instances 必须验证单次排除、调课和恢复。设置页提供“删除本应用全部日程”确认按钮，先在同一原生锁下使在途输入失效并关闭日历同步，再清理本应用所有账号、所有学期带应用 UID 的日程；保留手动添加的独立日程及其他应用/日历，不自动删除手机上的实际日程来测试按钮。清理后保留统一课表自动同步开关和小组件的夜间计划。
- 非 Android 平台保留 `service/calendar_export_service.dart` 和 `screen/settings/calendar_export_page.dart` 的本地 ICS 导出、打开、分享和复制路径，Linux 保留打开与复制。仅读取当前账号的所选学期缓存；文本转义和 UTF-8 折行遵守 RFC 5545，不上传课表或提供在线订阅。
- `android/app/src/androidTest/java/com/weijx/fzu_assistant/CalendarSyncInstrumentation.java` 在模拟器真实 Calendar Provider 上使用独立偏好和测试账号验证增删改、去重、提醒及手工/历史日程保留，结束清理测试日历；不改实际课表或登录凭据。

## 自定义主题

- `ThemeCustomizationService` 将主题清单和背景图片保存到应用文档目录的 `fzu-themes/`，亮暗模式分别保存 Material 颜色覆盖、图片、压暗、模糊、面板透明度、课程卡片颜色/透明度/圆角及分割线。默认色卡和系统动态配色继续保留，经典/卡片风格与亮暗模式独立。编辑使用草稿，保存后应用，未保存退出需确认。
- 课程卡片色卡独立于 App 主题色，原有 20 色命名为 Tailwind，另一预设 FUU 复用官方 `utils/random-color.ts` 的 25 色及暗色 C0 透明度。`course_color_palettes.dart` 统一管理预设；每个亮暗 `ThemeVariant` 分别保存预设键和 DIY 色序列，主题包包含此配置，旧主题缺字段时沿用 Tailwind。课程按名称稳定选色，专属课程颜色优先；选择或编辑色卡时清除当前模式的统一课程底色与强调色覆盖，使色卡立即生效，保留文字、透明度及其他样式。
- 课程色卡可从当前编辑模式的 App 壁纸生成，浅色使用浅色背景图、深色使用深色背景图，不读取原始系统壁纸。提取沿用后台 isolate 的安全解码与量化，生成最多 8 个实际图片代表色，支持继续改色和加减；没有背景图时隐藏生成入口，失败保留原色卡，不更改 App 配色来源、背景、其他样式或另一模式。
- 主题背景选图在 Android/iOS 使用官方 `image_picker` 系统相册入口，Android 显式启用 Photo Picker，不读取完整照片元数据、不新增整个相册的读取权限；桌面继续使用 `file_selector`。选中后复用现有解码校验和应用目录图片导入，取消选择保持草稿，`dynamic_color` 版本保持不变。
- 每个亮暗配置独立保存 `colorSource`（手机系统配色、App 壁纸取色、自选种子色）和 `seedColor`；旧文件缺少来源时沿用 `baseThemeKey`，旧主题的颜色覆盖继续兼容。通过各模式的 `isSeedColorCustom` 保留显式自定义选择，即使当前颜色与现成色卡相同，旧文件仍按种子色识别。重新生成整体配色只替换该模式的 Material 配色覆盖，保留课表颜色和其他样式。手机壁纸取色复用系统动态配色接口，不读取原始系统壁纸文件。
- 背景图取色在后台 isolate 解码、采样并使用 Material Color Utilities 生成种子；浅色和深色分别使用对应背景图。已选 App 壁纸取色时，更换对应背景图自动更新种子，保留单独微调的颜色及其他样式；不升级 `dynamic_color`。
- `interface_style` 持久化独立界面风格，并通过 `InterfaceTheme` 注入种子色和动态色的明暗主题。WebDAV 白名单包含该偏好，新导出采用卡片默认值；旧备份仅缺少此新增字段时仍按经典列表兼容，其他缺失或未知字段仍拒绝。
- `.fzutheme` 为包含 `theme.json` 和相对路径图片的 ZIP，导入分配新 ID，不覆盖原主题。限制文件、解码尺寸及参数范围，禁止路径穿越和符号链接；分享不包含账号、凭据、绝对路径或其他应用数据。自定义主题 ID 和本地图片不加入 WebDAV 白名单，恢复默认色卡时清除当前自定义主题选择。

## WebDAV 同步

- `service/webdav_sync_service.dart` 和 `screen/settings/webdav_settings_page.dart` 提供手动上传/下载、测试连接及默认关闭的“每次打开自动同步”；`common/widget/webdav_auto_sync.dart` 等待设置加载后在启动和后台恢复时触发，不因短暂失焦重复同步。使用配置目录下 `fzu-assistant-sync.json`，白名单同步应用偏好、自定义课程和隐藏课程，不同步凭据、Cookie、缓存、WebDAV 配置、自动开关或同步基线，密码只写 SecureStorage。手动下载验证并预览确认后覆盖，运行时立即应用；自动同步以目录和用户名隔离的内容摘要基线判断单端变化，首次两端不同或两端都修改时保留数据并提示手动选择，现有文件缺少可用的 ETag 条件验证器时禁止自动上传。标准服务器上传使用强 ETag / If-None-Match，坚果云的限定兼容见下文；手动确认和自动同步共用互斥锁，配置变化使在途结果失效，恢复与自定义课程保存同队列并在写前检查本地变化。标准 PUT 遇到 409 时使用 MKCOL 按需递归创建配置目录，201 为新建、405 为已存在，补建后仅重试一次且保留条件请求头，认证失败或重定向不得补建。读取同步文件的 404/409 视为尚无备份，首次写入仍须保证不覆盖已存在文件。连接测试使用当前输入和独立随机文件，验证写入、读取及删除，不保存输入、不改同步基线或正式备份；创建冲突时不删除已有文件，创建后读取失败仍清理，清理失败或上传结果不明须报告临时文件名。禁止跟随认证请求重定向，文件最大 5 MB，失败回滚本地设置。
- 新备份使用 `schemaVersion: 2`，数据格式版本与可选的创建端 `appVersion: {version, buildNumber}` 分开保存及预览；App 版本不参与内容变化摘要。已发布的 `version: 1` 备份继续支持，缺少创建端版本时显示未记录，仅将该历史格式缺失的 `interface_style` 迁移为经典列表；其他缺失或未知设置、未知未来 schema、混合版本字段一律拒绝，不自动降级或覆盖。
- `service/webdav_history.dart` 为同步服务的历史实现。主文件保持原路径，旧 `fzu-assistant-history.json` 索引只读兼容；新历史先保存不可变快照 `fzu-assistant-history/<sha256>.json`，再新增独立元数据 `fzu-assistant-history/metadata/<sha256>.json`，不再反复覆盖共享索引或要求历史索引的强 ETag。通过 `PROPFIND Depth: 1` 汇总元数据，严格验证 DAV XML、同源同目录的直属文件名，再从已校验的摘要构建 GET 地址，不请求任意服务端 href、不跨源或跟随认证跳转。上传前保存旧远端及待上传快照，快照与元数据均只创建不覆盖，标准服务器使用 `If-None-Match: *`，既有同名内容需校验摘要与元数据；历史保存、列举或校验失败时保留当前主文件，主文件覆盖继续要求可用 ETag 和 `If-Match`。失败上传可能保留可供预览的候选快照，不将其误称为当前同步版本。不自动裁剪或删除历史文件，数量、单文件与汇总大小均有限制。
- 坚果云官方 HTTPS WebDAV 端点的兼容只针对 `dav.jianguoyun.com`：已实测其裸 ETag 必须原样用于 `If-Match`，不得补引号或退化为无条件覆盖；仅接受单个安全的不透明值，仍拒绝弱标签、通配符、列表和控制字符。该端点会忽略 PUT 的 `If-None-Match: *`，因此主文件首次创建、历史快照、metadata 及连接测试都先通过随机临时目录的 `MKCOL 201` 确认归属，上传目录内的 payload，再以同源固定目标的 `MOVE` / `Overwrite: F` 发布。已存在目标返回的 409 仅按创建冲突处理，沿用读取校验或主文件冲突反馈，不无条件重试覆盖。始终清理本次明确拥有的临时文件及目录，不删除正式目标或其他临时目录；清理失败或结果不明必须报告确切临时路径。其他服务器继续使用标准条件请求，不扩散裸 ETag 或状态码兼容规则。
- 历史快照经选择、校验和预览确认后仅恢复本地设置及课程记录，当前远端同步文件不改，用户可再显式上传；恢复前先在本机保存同一白名单的恢复点，写入失败回滚，恢复点可离线选择恢复，不加入远端同步白名单。历史恢复清除旧同步基线，避免下次自动下载悄然撤销用户选择；当前远端的正常下载成功后重新记住基线。历史、上传和恢复沿用全局互斥锁，确认及每个后续提交检查配置和教务账号代次，本地课程编辑仍共用原队列。
- 连接设置的密码框下方直接放“测试并保存”原生 FilledButton，与三个输入框共用横向边距并占满可用宽度，不保留测试说明或重复保存入口。显式保存先完整测试当前输入的目录、用户名和密码，临时文件写入、读取及清理成功后才串行保存目录、用户名和 SecureStorage 密码；测试失败、配置过期、账号切换或页面销毁不得保存新输入或覆盖旧配置，保存失败回滚。成功或失败沿用现有反馈，不开始自动同步、不改自动同步开关或同步内容基线、不触发上传下载；保存使旧同步配置代次失效，排队及写入期间继续校验页面、账号与配置代次。独立“测试连接”继续只测试当前未保存输入，不隐式保存配置，也不改自动同步开关或基线。

## 培养计划

- `AcademicService.getCultivatePlan()` 直接读取教务处，按年级/学院/专业精确匹配，失败时用年级查询回退匹配专业，WebForms 令牌随每次响应更新，不接入 west2 服务。`screen/toolbox/academic/cultivate_plan_page.dart` 为工具箱入口，支持刷新及打开官方页面手动选择。最终链接仅接受教务处培养方案域名和路径，保留当前会话 id。

## 学业动态

- `model/academic_change.dart`、`service/academic_changes_service.dart` 和 `screen/toolbox/academic_changes/academic_changes_page.dart` 提供本地成绩与考试变化记录；工具箱提供入口，成绩和考场页显示可跨启动恢复的未读提示。仅在成功获取最新官方数据后比对，首次建立基线不提示，识别新成绩、分数变化和考试新增/变更/撤回；忽略返回顺序、重复或无法解析记录造成的伪变化，考试查询要求完整课程行且不依赖行样式，截断响应不得清空缓存或记录撤回。保留最近 100 条，支持逐条或全部已读。基线与记录均不参与 WebDAV 同步；退出清除，账号、请求代次和串行写入防止旧响应污染。此阶段不新增轮询、夜间任务或系统推送。

## 考场查询

- 考试安排复用 `CourseService` 的选课结果，从 `rawExamTime` 提取日期、时间与地点，不再请求独立的 `exam_list.aspx`。`ExamRoomInfo` 按北京时间解释起止时刻，只有结束后标记已考完；待考按开始时间升序、已考按最近优先、未安排或无法解析的记录置后并保留原文。查询失败保留缓存，旧请求不得覆盖新学期选择。

## 成绩学期汇总

- `common/utils/grade_summary.dart` 统一数字、五级制及两级制成绩排序和配色；`model/semester_summary.dart` 按学期、课程名、教师及二专业区分课程，已出分的补考替代原记录，同一课程不重复计学分。成绩页保留原始明细，汇总显示有效课程数、总修学分、最高成绩及估算 GPA；按学分加权，排除不计绩点的选修类别、二专业与两级制课程，学分或绩点缺失时明确显示缺失，不按零分计算。估算结果仅供参考，以教务处为准。

## 教务快捷入口

- 学生证补办、附卡补办、乘车区间更改与毕业设计（论文）统一放在 AcademicShortcutsPage，复用教务 Cookie 与会话 id 注入，不引入第三方服务。

## 历年卷

- `service/api/paper_service.dart` 使用公开 west2 online 历年卷目录/下载接口，不携带任何教务或 SSO 凭据；请求前后都检查独立 papersAccess。`screen/toolbox/paper/papers_page.dart` 默认 tip 仅展示说明与设置入口，allow 才构建查询组件，hide 从工具箱隐藏且直接路由也不请求。支持目录导航、当前目录本地搜索、浏览器查看/下载与复制下载地址；禁止路径穿越和非 HTTP(S) 下载地址，撤回授权即卸载数据页。

## 水电缴费

- `model/utility_payment.dart` 保存官方建行四校区深链，`screen/toolbox/utility_payment/utility_payment_page.dart` 提供旗山、铜盘、晋江、怡山缴费跳转。仅 Android/iOS 展示操作，桌面说明需手机建行 App。拉起失败可复制原链接或进入建行官方安装页；不接入 west2 服务。

## 小米设备的课程提醒

- 保留 `android_alarm_manager_plus` 调度与 `flutter_local_notifications` 展示通知的插件实现，不恢复通知实验 stash 或新增原生调度层。通过现有 reminders MethodChannel 的只读 `deviceInfo` 读取 Android Build.MANUFACTURER / BRAND，归一化精确识别 Xiaomi、Redmi、POCO，仅显示 MIUI / HyperOS 后台本地通知限制及 root 后可尝试解除限制的提示，不按品牌强制关闭开关、取消计划、拦截授权或禁用开发者测试。品牌检测未完成或失败不得阻断提醒操作，所有设备继续正常授权与插件调度流程；不检测或自动修改 root 状态。开发者工具保留直接通知测试入口，不读取机型、不显示系统限制或 root 提示，也不附加品牌门槛。

## Android 实况通知

- 仅接入 Android 官方 Live Updates API，复用 `flutter_local_notifications`，不增加厂商私有协议或另建原生调度层。`service/course_live_update_service.dart` 提供开发者工具的上课中、下课和下节课示例，使用独立渠道和同一测试通知 ID；不读取真实课表、不联网、不改变早课提醒或夜间同步计划。活动状态请求 promoted ongoing，倒计时使用系统 chronometer；结束状态清除 ongoing 和 promotion，转为可清除的普通通知，测试通知设置自动过期并提供手动清除。正常通知权限不足时可请求授权；不支持或未允许实况时回退普通通知，不宣称已提升展示。权限页在 Android 16 及以上展示实况通知授权状态，并通过官方设置 Intent 管理。
- Android 全部系统通知默认使用 `Importance.high` / `Priority.high`，允许系统以横幅展示；沿用既有通知渠道，不删除重建或更换 ID 绕过用户设置。已创建渠道的提醒方式由系统设置控制，应用不能强制修改。实况通知通过插件读取本应用当前通知，首次发布、课程阶段或课程内容变化时可重新提醒，单纯进度及倒计时刷新使用 `onlyAlertOnce` 保持静默；不使用悬浮窗、全屏 Intent 或私有协议强制展开系统卡片。
- `model/course_live_update.dart` 按上午 1–4 节、下午 5–8 节、晚上 9–11 节处理一天内已筛选的课程：当前时段还有课程时显示下节课，当前时段最后一门结束时直接结束实况并发普通结束通知，不跨午休或晚餐等待下一时段；每个时段第一门课提前五分钟开始预告。Dev Tools 的两分钟测试复用这套判断，以示例上午两门课和下午课程验证，在 0/30/60/110 秒依次展示上课中、下节课、上课中、上午结束，两次上课进度均从零开始。下节课正文显示剩余时间，测试按秒、真实课表按分钟刷新，并保留系统 chronometer。复用 `android_alarm_manager_plus` 命名后台任务，后台引擎在两分钟测试中每秒更新进度，单项示例每五秒更新；阶段闹钟作为恢复入口，离开页面继续执行。重复启动、单项预览、清除和退出撤销旧测试，延迟回调按当前时间跳过过期阶段，不补发整串通知。
- Android 平台功能区提供独立“实况通知”设置页 `screen/settings/course_live_updates_settings_page.dart`，开关默认关闭，与明日课程提醒和 Dev Tools 示例独立；普通通知及精确闹钟需授权，promotion 不可用时回退普通通知。`service/course_live_updates_controller.dart` 仅读取原生锁下已经接受的小组件快照，复用自定义课、隐藏课、调课与授权缓存处理，不联网。前台本地快照发布、夜间完整刷新成功和前台恢复后重排；进度按分钟刷新，阶段切换使用现有命名后台闹钟。真实通知和测试使用不同 ID，关闭真实开关仅取消真实任务；退出统一取消，并在回调与发布前核对原生账号代次及快照，旧账号回调不得覆盖新账号。设备开关不加入 WebDAV；当前仅做 Android，不新增 iOS/macOS 的实况接入。

## 招聘会与宣讲会

- `model/job_fair.dart`、`service/api/job_fair_service.dart` 和 `screen/toolbox/job_fair/job_fair_page.dart` 直接读取学校就业网的公开月度接口，不携带教务/SSO 凭据、不接入 west2 服务。支持月份选择、活动分类、未开始/往期、刷新和官方详情，时间按北京时间解释；失败保留上次数据并提示月份差异，部分坏记录提示略过，全量不可解析时报错，旧响应不得覆盖新选择。

## 嘉锡讲坛原生查询

- `model/lecture.dart`、`AcademicService.getLectures()` 和 `screen/toolbox/academic/lectures_page.dart` 直接读取教务处已报名讲座七列表格，复用教务 Cookie 与当前 identifier，支持 UTF-8/GBK、北京时间、刷新和官方页面回退。工具箱和教务快捷入口均进入原生页；未登录/缓存模式、会话失效、缺失表格与空报名列表分别处理，刷新失败保留旧数据，不接入 west2 服务。

## 历年卷应用内下载

- `service/paper_download_service.dart`、`screen/toolbox/paper/paper_download_sheet.dart` 和 `paper_file_actions.dart` 在原有 papersAccess 授权下提供下载进度、取消/重试、本地打开和分享。每次操作重新获取动态下载地址，独立无凭据客户端最多跟随五次 HTTP(S) 重定向，撤回授权立即取消且重新允许不能恢复旧任务。文件写入应用私有目录的独立子目录，使用 .part、完整性检查和失败清理，禁止路径穿越、保留文件名或覆盖已有文件。新增 open_filex 和 share_plus：Android/iOS 使用原生文件打开，桌面使用 file URI；Linux 不显示文件分享，桌面提供打开目录和复制本地路径。

## 一码通应用图标快捷操作

- `service/app_shortcut_service.dart` 对接 Android `AppShortcutBridge.kt` 和 iOS `AppDelegate.swift` / `SceneDelegate.swift`，动态注册唯一一码通快捷操作，通过正常登录流程后由 Home 切换一码通 Tab；冷/热启动操作等待登录后消费，恢复 Activity 不重复消费，未知 iOS 操作转交原有生命周期。语言随应用文案更新，不持久化二维码或登录数据。Android 的同一桥接也接收小组件打开课表操作。

## Android 桌面课程小组件

- `model/next_course_widget.dart`、`service/next_course_widget_service.dart`、`screen/settings/next_course_widget_settings_page.dart` 与 Android `NextCourseWidgetBridge.kt` / `NextCourseWidgetProvider.kt` 提供桌面课程。设置入口置于主设置底部 Android 功能区，支持系统确认添加与手动更新。从本地校历匹配实际学期，合并课表、自定义课程、单双周、调课及隐藏课程生成最多 180 天最小快照，不保存账号标识、凭据或支付码；缺少有效缓存时提示刷新，不能误报无课。原生使用系统小组件半小时更新和手动刷新重新渲染本地显示；时间统一北京时间，支持正在上课/下一节、同起始时刻冲突与真实缓存更新时间，点击回到周课表。缓存、设置、语言和前台恢复触发更新，教务退出使在途写入失效并清空，原生写入串行且只保留未完成队列；小组件异常不得阻断教务退出。
- “添加到桌面”使用官方 `requestPinAppWidget`，返回 true 只表示桌面接受请求，分别反馈请求已提交、不支持和调用失败，不宣称已添加或已授权；用户取消没有回调。小组件没有可申请的通用运行时权限，不声明桌面宿主的 `BIND_APPWIDGET`。添加操作之后通过共享信息卡片提供系统确认及手动添加指引，厂商桌面授权通过官方应用信息页入口检查，不调用私有权限接口或猜测授权状态。成功回调使用显式 provider、独立 variant action 和不可变 PendingIntent，查询实际绑定的小组件后刷新，不依赖系统填入的 widget ID；三个 receiver 保持 `exported=false`。

- 小组件完整周课表从北京时间本周一开始生成，包含已过去日期，周次与日期按实际校历匹配，不跟随首页手动选择的历史学期。
- `service/widget_sync_service.dart` 使用现有 `AndroidTaskScheduler` 的独立 `widgetSync` 命名任务，每晚默认北京时间 23:00 通过精确唤醒闹钟重新登录教务，刷新实际学期及近期跨学期的校历、课表缓存并发布所有课程小组件；时间、统一自动开关与手动同步在“夜间自动更新课表”页设置，精确闹钟需系统授权。保留插件调度及重启恢复，不另建原生调度层。后台登录只使用安全存储中的教务凭据，不写回登录会话，不请求 SSO 或支付服务，联网失败保留已有缓存及最近成功时间。
- 本地插件 `packages/fzu_widget_bridge` 由 Flutter 自动注册到前台和后台引擎，只负责后台存储、有限时长唤醒锁与原生小组件更新；以任务代次和本地输入基线校验所有在途结果，退出/换号/设置或课程修改后拒绝旧数据写入。`common/utils/widget_preference_bridge.dart` 将影响小组件的前台缓存、设置、自定义课程及 WebDAV 恢复写入统一送入同一原生锁，学期缓存在原生合并，前台发布也校验输入基线。缓存和不含身份信息的快照通过受限提交一起更新；每代同步分配独立闹钟 ID，旧回调不能覆盖新计划。取消同步先在内存失效代次，磁盘失败也不恢复授权，再独立取消闹钟，不影响课程提醒。回到前台重新读取后台缓存并刷新课表。第三方调休继续遵守独立授权，夜间只使用已授权的缓存调休。

## 编码规范

- 历史 home_style / timeline_days 存储值忽略，不恢复已移除的功能。

- west2 online 服务按功能独立配置 `FeatureAccess.tip / allow / hide`：默认 tip，入口可见但不得请求服务；allow 才启用请求；hide 隐藏入口，仍可在设置中恢复。原 west2 调课布尔开关迁移到 `west2AdjustmentsAccess`，已允许的用户保持 allow；历年卷使用独立 `papersAccess`。统一设置页为 `screen/settings/third_party_settings_page.dart`，模型为 `model/feature_access.dart`，周课表和后台提醒共同读取同一授权状态。
- 本轮功能约束：自定义课程按账号和学期保存，并覆盖周课表与提醒；WebDAV 同步应用设置、自定义课程和隐藏课程，提供默认关闭的每次打开自动同步，禁止上传登录凭据、Cookie、支付数据、缓存及 WebDAV 密码，手动下载覆盖前须确认，自动同步冲突须手动选择。WebDAV 密码只放 SecureStorage。校园服务通过域名隔离的 SSO 会话进入，不把教务 Cookie 当作 SSO Cookie。

- Android 明日课程提醒默认关闭，默认北京时间 21:00；预生成未来 180 天的通知正文，使用 android_alarm_manager_plus 精确唤醒，在独立后台 Dart isolate 执行命名任务，通过 flutter_local_notifications 展示通知，不依赖前台页面或网络。通知与精确闹钟由用户授权；刷新缓存、调课/隐藏课程/语言设置变更和应用恢复前台时重排，退出教务账号取消计划及测试通知。根据校历日期匹配实际学期，不跟随界面选择的历史学期；缺少课表/校历或超出有效课表周次时提示刷新，不误报无课。AndroidTaskScheduler 持久化计划，闹钟设置 exact/wakeup/allowWhileIdle/rescheduleOnReboot；后台入口保留 @pragma(vm:entry-point)，不引用 UI/主 isolate 内存，执行前核对任务代次防止退出或重排后展示旧通知；插件负责重启恢复。通知默认高重要性、公开锁屏内容，现有系统渠道的用户设置不能由应用强制覆盖，设置提供渠道直达入口。开发者工具仅 Android 显示“Notify in one minute”，使用独立测试闹钟，重复点击替换旧测试，不影响正式计划。

- 教务处成功登录后，将账号绑定的历史 Cookie 与 identifier 保存到 SecureStorage；启动/同账号登录失败且有历史会话时进入缓存模式，保留稳定学号，旧 identifier 不用于业务请求。课表、考场、校历与事件优先展示已有缓存，强制刷新也不得清空缓存；主页提示缓存模式并支持重试登录，退出教务账号同时删除历史会话。

- **每次项目结构或技术栈变更后，必须同步更新本 AGENTS.md 文件**

- 页面统一用 HookWidget，状态用 useState/useEffect/useMemoized
- Android 权限管理手动维护预期权限清单（通知、精确闹钟、扫码相机、安装更新、联网、定时唤醒和重启恢复），不扫描安装包或插件权限；通知、精确闹钟、安装未知应用使用实际系统状态，不仅依据 manifest 的授权标志。
- 页面导航统一使用 `context.pushNamed(AppRoutes.xxx)` / `context.pushReplacementNamed(AppRoutes.xxx)`；教务退出使用 `context.replaceAllNamed(AppRoutes.login)` 清空根导航栈，防止横屏嵌套导航或返回键回到已退出页面。路由名和参数定义在 `app_routes.dart`，页面构建集中在 `app_router.dart`，禁止页面直接构造 `MaterialPageRoute`
- 教务处数据抓取在 AcademicService 中实现，用 Dio GET/POST 请求 HTML 页面，html 包解析 DOM
- 教务处页面多为 GBK 编码，用 `charset` 包的 `gbk.decode()` 解码
- 请求教务处接口需要带 `queryParameters: {'id': userId}`
- ASP.NET WebForms 页面需要先 GET 获取 __VIEWSTATE/__EVENTVALIDATION，再 POST 提交
- UI 文本必须通过 `AppLocalizations.of(context)!.xxx` 引用，禁止硬编码中文/英文字符串；开发者工具（`lib/screen/dev/`）文案直接定义，不使用国际化。
- Service 层错误消息保留中文（无 BuildContext），UI 层捕获后展示
- 状态管理模式：AppSettingsProvider 使用 InheritedWidget + ValueNotifier + SharedPreferences 持久化；普通查询页复用 common/hooks/use_async_data.dart，保留刷新期间的旧数据，特殊分页/条件查询独立管理状态
- 单次隐藏课程保存在 AppSettings.hiddenCourseSessions，按稳定学号 + 学期 + 课程 + 周次/星期/节次隔离；课程详情列表底部提供“我不想上”，说明文字作为按钮的 subtitle，CourseSessions 统一过滤周课表，不展示课程管理页支持逐项/全部恢复。非本周课程提示卡和考试卡不提供此操作，刷新课表与登出不删除隐藏记录。
- 学习中心协议参考 `.reference/fzuhelper-app/lib/sso-login.ts` 和 `utils/learning-center/api-service.ts`。SSO Cookie 与学习中心 token 存在 SecureStorage，按教务账号隔离，教务登出时清理；SSO 密码不保存。SSO Cookie 仅发送给其所属域名，学习中心变更请求不自动重试。正常签到须校验现场一分钟有效二维码，直接签到仅在开发者调试页提供。
- 一码通协议参考 `.reference/fzuhelper-app/lib/ykt-login.ts`：无 voucher 时直接展示服务端返回的 20 位在线消费码，不请求离线参数或前端 RSA 配置；有 voucher 时生成离线消费码，SO 正文为原始字节、SP 正文为 Base64，二维码必须按字节编码；摘要对大写十六进制文本计算 SHA1，时间戳使用 Unix 秒。入馆二维码和 Code128 使用服务端用户 account。一码通 token 存在按教务账号隔离的 SecureStorage，SSO/教务登出时清理；支付码、RSA 配置和用户密钥只保留内存。消费码在页面前台每 50 秒刷新，后台/隐藏路由停止刷新并恢复亮度，重新进入时刷新；未开通离线支付仍可使用在线消费码和入馆码。一码通 SSO 登录不依赖学习中心授权。
- 学习中心日期和无时区的服务端时间统一按北京时间（Asia/Shanghai，UTC+8）解释，不受设备时区影响；日期卡片、22 点后默认次日、过去时段禁用、未来七天范围、预约状态及现场二维码校验使用同一时间约定，预约最长 4 小时。
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
- 本地 Git hooks 统一维护在 [.githooks/](.githooks/)，通过 `bash scripts/install-git-hooks.sh` 安装到当前仓库的 `core.hooksPath`，不修改全局 Git 配置。原 `.git/hooks/` 中的文件保留，不直接覆盖。
- 本地主线构建号按第一父链计算：普通提交增加一次，`--amend` 不增加，合并提交只计算主线上的一次提交；分支及 detached HEAD 沿用可追溯的远端主线编号。浅克隆不得用不完整历史生成构建号。
- `pre-commit` 保留 Dart 格式检查，`post-commit` 按实际提交历史核对并在必要时自动 amend 构建号，`post-merge` 仅校准新创建的合并提交，不改写快进取得的提交或 squash 前的 HEAD；校准必须防止递归、保留提交签名状态及其他暂存内容，不额外留下校准提交。pubspec 或待格式化 Dart 文件存在未暂存修改，以及 `git commit --only` 等临时 index 模式时，在改写前拒绝，保留原内容。post 阶段失败须明确说明提交已经存在并保留恢复文件，不能静默跳过签名或检查。CI 继续独立计算构建号。

## 国际化

- 使用 Flutter 官方 `gen-l10n` 方案，配置文件 `l10n.yaml`
- ARB 文件：`lib/l10n/app_zh.arb`（中文）、`lib/l10n/app_en.arb`（英文）
- 添加新语言：新建 `app_XX.arb` → `flutter gen-l10n` → 在 `AppSettings._localeOptions` 注册
- 语言切换：「我的 → 设置 → 一般设置 → 语言」原生单选弹层，通过 `AppSettings` 持久化到 SharedPreferences
- `MaterialApp.locale` 绑定 `AppSettings.currentLocale`，`null` 表示跟随系统

## Windows 注意事项

- Windows 专用图标为 `assets/icon/icon_windows.svg/png`（浅色圆角底），`windows/runner/resources/app_icon.ico` 包含 16–256px 多尺寸。程序、任务栏、安装器及桌面/开始菜单快捷方式使用同一 ICO，自绘标题栏使用对应 PNG。修改原生图标后需重新构建，Hot Reload 不更新 exe 图标。修改 SVG 后，在项目根目录使用 ImageMagick 重新生成：
  ```powershell
  magick -background none -density 384 assets/icon/icon_windows.svg -resize 1024x1024 PNG32:assets/icon/icon_windows.png
  magick assets/icon/icon_windows.png -define icon:auto-resize=256,128,96,64,48,40,32,24,20,16 windows/runner/resources/app_icon.ico
  ```
- `flutter_inappwebview` 在 Windows 上需要 WebView2 Runtime
- `windows/runner/flutter_window.cpp` 中有 `closeWindow` 方法频道的 workaround（修复关窗 bug）
- Windows 标题栏由 `window_manager` 隐藏，`MaterialApp.builder` 加入全局 `DesktopWindowFrame`；首帧完成后由 Dart 显示窗口。窗口壳拥有独立 Overlay，Navigator 内容使用 ClipRect，防止页面过渡覆盖标题栏。关闭按钮、Alt+F4 和系统菜单关闭统一交给 `DesktopWindow.onCloseRequested`，明确退出继续共用现有 `closeWindow` 修复。
- `service/windows_background_service.dart` 通过 `tray_manager` 官方 `TrayIcon` / `Menu` API 管理托盘，不新增原生后台服务或调度层。`windows_close_to_tray` 为本机独立偏好，缺省及旧安装均关闭；用户开启且托盘实际可用后，普通关闭仅隐藏窗口并保留后台课程通知。托盘单击／双击或“显示窗口”恢复并聚焦原窗口，右键提供“退出应用”；关闭驻留前先恢复窗口，托盘创建或可见性失败不得隐藏窗口，普通关闭仍可退出。此偏好不加入 WebDAV 白名单，不自动注册开机启动。
- `main` 在 `DesktopWindow.initialize()` 后初始化后台服务，并在当前本地化上下文更新托盘文案；设置加载后仅绑定一个 `WindowsCourseNotifications` 实例，toast 点击复用 `WindowsBackgroundService.restoreWindow()`，恢复最小化及隐藏的现有窗口。明确退出依次等待通知 `shutdown()`、移除托盘、调用 `closeWindow`；通知清理失败也必须允许进程退出。关闭到托盘不停止通知。安装版更新保留 `UpdateService` 的显式 `exit(0)` 和安装器关闭／重启路径，不能改成普通关窗。
- 设置主列表的平台区分别判断 Android 与 Windows：Android 专属项使用 `CourseReminderService.androidSupported`，Windows 仅展示“后台运行”和“课程通知”，路由分别为 `/settings/windows-background` 与 `/settings/windows-notifications`；不通过扩大通用 `supported` 条件暴露 Android 权限、日历、小组件或实况授权入口。
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
- 各平台完整检出历史（`fetch-depth: 0`），共用 `.github/actions/build-number`，只计算当前构建版本可追溯的 `origin/main` 第一父链提交数，并通过 Flutter `--build-number` 注入。合并提交计一次，不累计侧分支内部提交；历史 tag 和手动构建其他分支沿用其所基于的主线编号。保留本地 pre-commit hook，但 CI 构建号独立计算，不依赖 hook 或 `pubspec.yaml` 中的 build 后缀。
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
1. 在需要发布release时，先切换到 `main` 分支，抬升语义化版本号（`x.y.z`），提交 commit，正常执行 pre-commit hook；发布构建号由 Actions 按上述主线规则独立计算并注入
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

## 教室全天占用与已下载试卷

- `service/api/classroom_usage_service.dart` 直接读取教务处 `kbcx_zb.aspx`，复用教务会话、每次响应的 WebForms 令牌与请求代次检查；校区、教学楼使用下拉选项实际值。`model/classroom_usage.dart` 保存教室信息及占用节次，`screen/toolbox/empty_room/classroom_usage_page.dart` 提供日期、校区、教学楼及可展开的 1–11 节占用展示，不提供搜索框；工具箱和空教室页均有入口。筛选项元数据与占用查询分开，只有点击条件下方的“查询”按钮才请求占用结果，进入页面、修改条件及重试筛选项均不自动查询；条件改变清除旧结果。解析须展开 rowspan/colspan 并校验完整周表表头、教室元数据和行列，缺失或截断响应报错，不能显示为空闲；结果列表懒加载。
- `service/paper_library_service.dart` 和 `screen/toolbox/paper/paper_library_page.dart` 管理应用目录 `paper_downloads/` 的已下载试卷，提供本地搜索、空间统计、打开、分享、复制路径和确认删除，Linux 保留打开与复制路径。入口仅位于历年卷页，不依赖在线历年卷授权、不联网、不清除账号或其他应用数据。兼容旧 `paper-*` 下载目录；新下载在 `pending-paper-*` 写入，完整后整体重命名为 `saved-paper-*`，避免将半成品或合法 `.part` 文件名混淆。枚举不跟随链接，每次文件操作重新校验目录与普通文件，删除仅处理选中文件及空目录，不递归清理。

## 参考

参考项目统一存放在 `.reference/`，该目录不纳入版本控制。以下 URL 来自各本地仓库的 Git remote：

- [jwch](https://github.com/west2-online/jwch)（`.reference/jwch/`）：Go 教务处接口库，参考 HTML 解析、表单字段和 URL 格式。
- [fzuhelper-app](https://github.com/west2-online/fzuhelper-app)（`.reference/fzuhelper-app/`）：React Native 前端，参考 UI 交互和功能列表。
- [fzuhelper-server](https://github.com/west2-online/fzuhelper-server)（`.reference/fzu-helper-server/`）：福大助手 Go 服务端，参考业务设计。
- [FluxDown](https://github.com/zerx-lab/FluxDown)（`.reference/FluxDown/`）：Flutter 下载管理器，参考 Windows 安装包与自动更新流程。
- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)（`.reference/PiliPlus/`）：Flutter 哔哩哔哩客户端，参考 Flutter UI 与交互实现。

## Review

- review 修改直接 amend / squash 到对应功能的原提交，不创建额外 review 或 fixup 提交。
