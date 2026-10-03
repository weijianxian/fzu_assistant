import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/layout/desktop_window_frame.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_router.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/desktop_window.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/webview_environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopWindow.instance.initialize();
  await initWebViewEnvironment();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
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
    final settings = useMemoized(
      () => AppSettings()
        ..load()
        ..initDynamicColor(),
    );
    useEffect(
      () =>
          () => settings.dispose(),
      [],
    );

    return AnimatedBuilder(
      animation: Listenable.merge([
        settings.themeKey,
        settings.themeModeKey,
        settings.localeKey,
        settings.selectedSemesterKey,
        settings.termsKey,
      ]),
      builder: (_, _) => AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
          debugShowCheckedModeBanner: false,
          theme: settings.lightTheme,
          darkTheme: settings.darkTheme,
          themeMode: settings.currentThemeMode,
          locale: settings.currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final scheme = Theme.of(context).colorScheme;
            final overlayStyle = scheme.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark;
            return DesktopWindowFrame(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarContrastEnforced: false,
                ),
                child: ColoredBox(
                  color: scheme.surface,
                  child: SafeArea(top: false, bottom: false, child: child!),
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
    final ok = await ApiClient.instance.relogin();
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
    return Scaffold(
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
