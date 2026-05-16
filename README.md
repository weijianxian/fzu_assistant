# FZU Assistant

> 福州大学一站式校园助手 — 课表、成绩、考试、校历，开箱即用。

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

## 技术架构

```
lib/
├── model/          # 数据模型层 — StudentInfo, Course, GPA, Mark ...
├── service/        # 网络与业务层 — API 客户端、登录、课表、学业数据
├── screen/         # 页面层
│   ├── schedule/   #   课程表
│   ├── toolbox/    #   工具箱（成绩、GPA、考场、学分、统考）
│   ├── my/         #   个人中心、校历
│   ├── settings/   #   主题设置
│   └── guest/      #   登录
└── main.dart       # 应用入口
```

**核心设计：**

- **Service 架构** — 共享 `ApiClient` 单例，统一管理请求、Cookie 持久化和自动续登
- **验证码识别** — 内置验证码自动求解，免去手动输入
- **安全存储** — 凭据通过 `flutter_secure_storage` 加密存储，不落明文
- **响应式状态** — 基于 `flutter_hooks` 管理页面状态

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

## 项目依赖

| 依赖 | 用途 |
|------|------|
| `dio` | HTTP 客户端 |
| `dio_cookie_manager` | Cookie 持久化 |
| `flutter_secure_storage` | 加密存储凭据 |
| `flutter_hooks` | 响应式状态管理 |
| `html` | 教务系统页面解析 |
| `crypto` | 密码加密处理 |

## 参与贡献

欢迎提交 Issue 和 Pull Request。

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m 'feat: add something'`
4. 推送分支：`git push origin feature/your-feature`
5. 提交 Pull Request

## 开源协议

本项目基于 [MIT License](LICENSE) 开源。
