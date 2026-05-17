# FZU Assistant

> 福州大学一站式校园助手 — 课表、成绩、考试、校历，开箱即用，本地优先。

<img src="https://socialify.git.ci/weijianxian/fzu_assistant/image?custom_language=Flutter&custom_description=%e7%a6%8f%e5%a4%a7%e4%b8%80%e7%ab%99%e5%bc%8f%e6%a0%a1%e5%9b%ad%e5%8a%a9%e6%89%8b+%e2%80%94+%e8%af%be%e8%a1%a8%e3%80%81%e6%88%90%e7%bb%a9%e3%80%81%e8%80%83%e8%af%95%e3%80%81%e6%a0%a1%e5%8e%86%ef%bc%8c%e5%bc%80%e7%ae%b1%e5%8d%b3%e7%94%a8%ef%bc%8c%e6%9c%ac%e5%9c%b0%e4%bc%98%e5%85%88%e3%80%82&description=1&font=JetBrains+Mono&forks=1&issues=1&language=1&logo=https%3A%2F%2Favatars.githubusercontent.com%2Fu%2F33548986%3Fv%3D4&name=1&owner=1&pulls=1&stargazers=1&theme=Auto" width="640" height="320" />

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows-lightgrey" />
</p>

## 功能一览

| 模块 | 说明 |
|------|------|
| **课程表** | 自动同步教务系统课表，支持按周查看 |
| **成绩查询** | GPA、学分、各科成绩一站式查询 |
| **考试安排** | 考场、座位、时间一目了然 |
| **校历** | 学期起止、假期安排随时查看 |
| **统一考试** | 四六级等统一考试信息查询 |
| **深色模式** | 亮暗主题无缝切换，支持自定义主题色 |
| **多语言** | 支持中文 / English，可在"我的"页面切换 |

## 技术架构

```
lib/
├── l10n/               # 国际化 — ARB 翻译文件 + 自动生成的 AppLocalizations
├── model/              # 数据模型层 — StudentInfo, Course, GPA, Mark ...
├── service/            # 网络与业务层 — API 客户端、登录、课表、学业数据
├── screen/             # 页面层
│   ├── schedule/       #   课程表
│   ├── toolbox/        #   工具箱（成绩、GPA、考场、学分、统考）
│   ├── my/             #   个人中心、校历、关于
│   ├── settings/       #   主题设置
│   └── guest/          #   登录
├── theme/              # 主题配置
└── main.dart           # 应用入口
```

**核心设计：**

- **Service 架构** — 共享 `ApiClient` 单例，统一管理请求、Cookie 持久化和自动续登
- **验证码识别** — 内置验证码自动求解，免去手动输入
- **安全存储** — 凭据通过 `flutter_secure_storage` 加密存储，不落明文
- **响应式状态** — 基于 `flutter_hooks` 管理页面状态
- **国际化** — Flutter `gen-l10n` + ARB 文件，支持中英双语

## 快速开始

### 环境要求

- Flutter 3.x / Dart 3.x
- Android Studio 或 VS Code（含 Flutter 插件）

### 运行

```bash
git clone https://github.com/your-username/fzu_assistant.git
cd fzu_assistant
flutter pub get
flutter run
```

### 构建发布包

```bash
# Android
flutter build apk --release

# Windows
flutter build windows --release
```

## CI/CD

项目使用 GitHub Actions 自动化构建：

| 触发条件 | 行为 |
|----------|------|
| 推送至 `main` | 构建 Windows & Android 安装包 |
| 推送 `v*` 标签 | 构建并自动发布 GitHub Release |
| 手动触发 | 在 Actions 页面按需构建 |

### Android 签名配置

Release 构建需要在仓库 **Settings → Secrets and variables → Actions** 中配置以下 Secrets：

| Secret | 说明 |
|--------|------|
| `KEYSTORE_BASE64` | 密钥库的 Base64 编码 |
| `KEY_STORE_PASSWORD` | 密钥库密码 |
| `KEY_ALIAS` | 密钥别名 |
| `KEY_PASSWORD` | 密钥密码 |

首次生成密钥：

```bash
keytool -genkey -v -keystore release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias release

# 转为 Base64
base64 -i release.jks | tr -d '\n'
```

## 国际化

项目使用 Flutter 官方 `gen-l10n` 方案：

- 翻译文件位于 `lib/l10n/app_zh.arb`（中文）和 `lib/l10n/app_en.arb`（英文）
- 添加新语言：新建 `app_XX.arb`，运行 `flutter gen-l10n`，在 `LocaleState.locales` 中注册
- 用户可在「我的 → 语言」中切换语言，选择会持久化保存

## 项目依赖

| 依赖 | 用途 |
|------|------|
| `dio` | HTTP 客户端 |
| `dio_cookie_manager` | Cookie 持久化 |
| `flutter_secure_storage` | 加密存储凭据 |
| `flutter_hooks` | 响应式状态管理 |
| `flutter_localizations` + `intl` | 国际化 |
| `html` | 教务系统页面解析 |
| `crypto` | 密码加密处理 |

## 参与贡献

欢迎提交 Issue 和 Pull Request。

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m 'feat: add something'`
4. 推送分支：`git push origin feature/your-feature`
5. 提交 Pull Request

## 感谢
 - <https://github.com/west2-online/jwch>
 - <https://github.com/west2-online/fzuhelper-server>