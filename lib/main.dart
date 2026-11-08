import 'dart:async';

import 'package:fzu_assistant/service/custom_course_store.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/layout/desktop_window_frame.dart';
import 'package:fzu_assistant/common/widget/webdav_auto_sync.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/app_shortcut_service.dart';
import 'package:fzu_assistant/service/next_course_widget_service.dart';
import 'package:fzu_assistant/service/desktop_window.dart';
import 'package:fzu_assistant/service/windows_background_service.dart';
import 'package:fzu_assistant/service/windows_course_notifications.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/webview_environment.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/app_theme_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppShortcutService.instance.initialize();
  await DesktopWindow.instance.initialize();
  await WindowsBackgroundService.instance.initialize();
  if (WindowsBackgroundService.supported) {
    WindowsBackgroundService.instance.beforeExit =
        WindowsCourseNotifications.instance.shutdown;
  }
  await initWebViewEnvironment();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  try {
    await CustomCourseStore.instance.load();
  } catch (_) {
    // A damaged local record must not block login; the editor shows the error.
  }
  runApp(const MyApp());
  if (DesktopWindow.isWindows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(DesktopWindow.instance.show());
    });
  }
}

class MyApp extends HookWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = useMemoized(AppSettings.new);
    final settingsReady = useMemoized(() => settings.load(), [settings]);
    final navigatorKey = useMemoized(GlobalKey<NavigatorState>.new);
    final messengerKey = useMemoized(GlobalKey<ScaffoldMessengerState>.new);
    useEffect(() {
      var mounted = true;
      VoidCallback? unbind;
      VoidCallback? unbindWindowsNotifications;
      unawaited(
        settingsReady
            .then((_) {
              if (mounted) {
                unbind = NextCourseWidgetService.instance.bind(settings);
                unbindWindowsNotifications = WindowsCourseNotifications.instance
                    .bind(
                      settings,
                      onActivate:
                          WindowsBackgroundService.instance.restoreWindow,
                    );
              }
            })
            .catchError((Object _) {
              // Settings already report their loading failure in the app.
            }),
      );
      return () {
        mounted = false;
        unbind?.call();
        unbindWindowsNotifications?.call();
      };
    }, [settings, settingsReady]);
    useEffect(() {
      unawaited(settings.initDynamicColor());
      return null;
    }, [settings]);
    useEffect(
      () =>
          () => settings.dispose(),
      [],
    );

    return AnimatedBuilder(
      animation: Listenable.merge([
        settings.themeKey,
        settings.activeCustomTheme,
        settings.systemColorRevision,
        settings.themeModeKey,
        settings.interfaceStyle,
        settings.localeKey,
        settings.selectedSemesterKey,
        settings.termsKey,
      ]),
      builder: (_, _) => AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
          debugShowCheckedModeBanner: false,
          theme: settings.lightTheme,
          darkTheme: settings.darkTheme,
          themeMode: settings.currentThemeMode,
          locale: settings.currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final l10n = AppLocalizations.of(context)!;
            WindowsBackgroundService.instance.updateLabels(
              WindowsBackgroundLabels(
                appName: l10n.appName,
                showWindow: l10n.windowsBackgroundRestore,
                exit: l10n.windowsBackgroundExit,
              ),
            );
            final scheme = Theme.of(context).colorScheme;
            final overlayStyle = scheme.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark;
            return DesktopWindowFrame(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle.copyWith(
                  statusBarColor: Colors.transparent,
                  systemStatusBarContrastEnforced: false,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarContrastEnforced: false,
                ),
                child: WebDavAutoSync(
                  settings: settings,
                  ready: settingsReady,
                  navigatorKey: navigatorKey,
                  messengerKey: messengerKey,
                  child: AppThemeBackground(child: child!),
                ),
              ),
            );
          },
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// 启动页：检查凭据 → 自动登录 → 跳转主页或登录页
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scale = Tween(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    final api = ApiClient.instance;
    final ok = await api.relogin() || await api.restoreCachedSession();
    if (!mounted) return;
    context.pushReplacementNamed(ok ? AppRoutes.home : AppRoutes.login);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'app-icon',
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 100,
                      height: 100,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator.adaptive(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
