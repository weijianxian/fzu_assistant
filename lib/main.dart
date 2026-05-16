import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/constants/breakpoints.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/l10n/locale_provider.dart';
import 'package:fzu_assistant/service/api_client.dart';

import 'package:fzu_assistant/theme/theme_provider.dart';

import 'package:fzu_assistant/screen/guest/login.dart';
import 'package:fzu_assistant/screen/schedule/schedule.dart';
import 'package:fzu_assistant/screen/toolbox/toolbox.dart';
import 'package:fzu_assistant/screen/my/my.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    final themeState = useMemoized(() => ThemeState()..load());
    final localeState = useMemoized(() => LocaleState()..load());
    useEffect(() => () { themeState.dispose(); localeState.dispose(); }, []);

    return AnimatedBuilder(
      animation: Listenable.merge([themeState.themeIndex, themeState.themeMode, localeState.localeIndex]),
      builder: (_, _) => LocaleProvider(
        state: localeState,
        child: ThemeProvider(
          state: themeState,
          child: MaterialApp(
            title: 'FZU Assistant',
            debugShowCheckedModeBanner: false,
            theme: themeState.lightTheme,
            darkTheme: themeState.darkTheme,
            themeMode: themeState.currentThemeMode,
            locale: localeState.currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SplashScreen(),
          ),
        ),
      ),
    );
  }
}

/// 启动页：检查凭据 → 自动登录 → 跳转主页或登录页
class SplashScreen extends HookWidget {
  const SplashScreen({super.key});

  Future<Widget> _autoLogin() async {
    final ok = await ApiClient.instance.relogin();
    return ok ? const HomeScreen() : const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = useFuture(useMemoized(_autoLogin));

    if (snapshot.hasData) return snapshot.data!;
    return const SplashScreenContent();
  }
}

class SplashScreenContent extends StatelessWidget {
  const SplashScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                  selectedIndex: currentPage.value,
                  onDestinationSelected: (i) => currentPage.value = i,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(icon: const Icon(Icons.home), label: Text(l10n.navSchedule)),
                    NavigationRailDestination(icon: const Icon(Icons.build), label: Text(l10n.navToolbox)),
                    NavigationRailDestination(icon: const Icon(Icons.person), label: Text(l10n.navMy)),
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
                    BottomNavigationBarItem(icon: const Icon(Icons.home), label: l10n.navSchedule),
                    BottomNavigationBarItem(icon: const Icon(Icons.build), label: l10n.navToolbox),
                    BottomNavigationBarItem(icon: const Icon(Icons.person), label: l10n.navMy),
                  ],
                  onTap: (i) => currentPage.value = i,
                ),
        );
      },
    );
  }
}
