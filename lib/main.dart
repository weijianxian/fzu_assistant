import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/screen/guest/login.dart';
import 'package:fzu_assistant/screen/home/home.dart';
import 'package:fzu_assistant/service/api_client.dart';
import 'package:fzu_assistant/theme/theme_provider.dart';

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
    final state = useMemoized(() => ThemeState()..load());
    useEffect(() => state.dispose, [state]);

    return AnimatedBuilder(
      animation: Listenable.merge([state.themeIndex, state.themeMode]),
      builder: (_, _) => ThemeProvider(
        state: state,
        child: MaterialApp(
          title: 'FZU Assistant',
          debugShowCheckedModeBanner: false,
          theme: state.lightTheme,
          darkTheme: state.darkTheme,
          themeMode: state.currentThemeMode,
          home: const SplashScreen(),
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
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
