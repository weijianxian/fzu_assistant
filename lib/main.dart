import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fzu_assistant/constants/breakpoints.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fzu_assistant/screen/guest/login.dart';
import 'package:fzu_assistant/screen/schedule/schedule.dart';
import 'package:fzu_assistant/screen/toolbox/toolbox.dart';
import 'package:fzu_assistant/screen/my/my.dart';

WebViewEnvironment? webViewEnvironment;

Future<void> _initWebViewEnvironment() async {
  if (!Platform.isWindows) return;
  try {
    if (await WebViewEnvironment.getAvailableVersion() == null) return;
    final dir = await getApplicationSupportDirectory();
    webViewEnvironment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(
        userDataFolder: '${dir.path}/flutter_inappwebview',
      ),
    );
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initWebViewEnvironment();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends HookWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = useMemoized(() => AppSettings()..load());
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
      ]),
      builder: (_, _) => AppSettingsProvider(
        settings: settings,
        child: MaterialApp(
          title: 'FZU Assistant',
          debugShowCheckedModeBanner: false,
          theme: settings.lightTheme,
          darkTheme: settings.darkTheme,
          themeMode: settings.currentThemeMode,
          locale: settings.currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    try {
      await CourseService().getCurrentWeek();
    } catch (_) {}
    final ok = await ApiClient.instance.relogin();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ok ? const HomeScreen() : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SplashScreenContent();
}

class SplashScreenContent extends StatefulWidget {
  const SplashScreenContent({super.key});

  @override
  State<SplashScreenContent> createState() => _SplashScreenContentState();
}

class _SplashScreenContentState extends State<SplashScreenContent>
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

const _pages = [SchedulePage(), ToolboxPage(), MyPage()];

class HomeScreen extends HookWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPage = useState(0);
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kNavBreakpoint;

        return Scaffold(
          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  leading: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Hero(
                      tag: 'app-icon',
                      child: Image.asset(
                        'assets/icon/icon.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),
                  selectedIndex: currentPage.value,
                  onDestinationSelected: (i) => currentPage.value = i,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.home),
                      label: Text(l10n.navSchedule),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.build),
                      label: Text(l10n.navToolbox),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person),
                      label: Text(l10n.navMy),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(index: currentPage.value, children: _pages),
              ),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: currentPage.value,
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home),
                      label: l10n.navSchedule,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.build),
                      label: l10n.navToolbox,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person),
                      label: l10n.navMy,
                    ),
                  ],
                  onTap: (i) => currentPage.value = i,
                ),
        );
      },
    );
  }
}
