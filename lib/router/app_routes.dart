import 'package:flutter/material.dart';
import 'package:fzu_assistant/screen/guest/login.dart';
import 'package:fzu_assistant/screen/guest/editor_page.dart';
import 'package:fzu_assistant/screen/guest/webview_page.dart';
import 'package:fzu_assistant/screen/toolbox/gpa/gpa_page.dart';
import 'package:fzu_assistant/screen/toolbox/marks/marks_page.dart';
import 'package:fzu_assistant/screen/toolbox/credit/credit_page.dart';
import 'package:fzu_assistant/screen/toolbox/unified_exam/unified_exam_page.dart';
import 'package:fzu_assistant/screen/toolbox/exam_room/exam_room_page.dart';
import 'package:fzu_assistant/screen/toolbox/empty_room/empty_room_page.dart';
import 'package:fzu_assistant/screen/toolbox/notice/notice_page.dart';
import 'package:fzu_assistant/screen/my/calendar/calendar_page.dart';
import 'package:fzu_assistant/screen/my/about/about_page.dart';
import 'package:fzu_assistant/screen/settings/settings_page.dart';
import 'package:fzu_assistant/screen/settings/schedule_settings_page.dart';
import 'package:fzu_assistant/screen/settings/general_settings_page.dart';
import 'package:fzu_assistant/screen/settings/theme/theme_section.dart';
import 'package:fzu_assistant/screen/dev/dev_tool.dart';
import 'package:fzu_assistant/screen/dev/shared_prefs_page.dart';
import 'package:fzu_assistant/screen/dev/secure_storage_page.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const home = '/home';
  static const gpa = '/gpa';
  static const marks = '/marks';
  static const credit = '/credit';
  static const unifiedExam = '/unified-exam';
  static const examRoom = '/exam-room';
  static const emptyRoom = '/empty-room';
  static const notice = '/notice';
  static const calendar = '/calendar';
  static const settings = '/settings';
  static const scheduleSettings = '/settings/schedule';
  static const generalSettings = '/settings/general';
  static const themeSettings = '/settings/theme';
  static const about = '/about';
  static const dev = '/dev';
  static const devSharedPrefs = '/dev/shared-prefs';
  static const devSecureStorage = '/dev/secure-storage';
  static const webview = '/webview';
  static const editor = '/editor';

  static final routes = <String, WidgetBuilder>{
    login: (_) => const LoginPage(),
    gpa: (_) => const GpaPage(),
    marks: (_) => const MarksPage(),
    credit: (_) => const CreditPage(),
    unifiedExam: (_) => const UnifiedExamPage(),
    examRoom: (_) => const ExamRoomPage(),
    emptyRoom: (_) => const EmptyRoomPage(),
    notice: (_) => const NoticePage(),
    calendar: (_) => const CalendarPage(),
    settings: (_) => const SettingsPage(),
    scheduleSettings: (_) => const ScheduleSettingsPage(),
    generalSettings: (_) => const GeneralSettingsPage(),
    themeSettings: (_) => const ThemeSection(),
    about: (_) => const AboutPage(),
    dev: (_) => const DevToolPage(),
    devSharedPrefs: (_) => const SharedPrefsPage(),
    devSecureStorage: (_) => const SecureStoragePage(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    final builder = routes[name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }
    // 需要参数的页面
    switch (name) {
      case webview:
        final args = settings.arguments as WebViewArgs;
        return MaterialPageRoute(
          builder: (_) => WebViewPage(
            url: args.url,
            title: args.title,
            injectCookies: args.injectCookies,
          ),
          settings: settings,
        );
      case editor:
        final args = settings.arguments as EditorArgs;
        return MaterialPageRoute(
          builder: (_) => EditorPage(
            title: args.title,
            initialValue: args.initialValue,
            onSave: args.onSave,
          ),
          settings: settings,
        );
    }
    return null;
  }
}

// -- 参数类 --

class WebViewArgs {
  final String url;
  final String? title;
  final bool injectCookies;

  const WebViewArgs({required this.url, this.title, this.injectCookies = true});
}

class EditorArgs {
  final String title;
  final String initialValue;
  final Future<bool> Function(String value) onSave;

  const EditorArgs({
    required this.title,
    required this.initialValue,
    required this.onSave,
  });
}

// -- Context 导航扩展 --

extension NavigationX on BuildContext {
  Future<T?> push<T>(Widget page) =>
      Navigator.of(this).push<T>(MaterialPageRoute(builder: (_) => page));

  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) =>
      Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);

  Future<T?> pushReplacement<T, TO>(Widget page) => Navigator.of(
    this,
  ).pushReplacement<T, TO>(MaterialPageRoute(builder: (_) => page));

  Future<T?> pushAndRemoveAll<T>(Widget page) =>
      Navigator.of(this).pushAndRemoveUntil<T>(
        MaterialPageRoute(builder: (_) => page),
        (_) => false,
      );

  void pop<T>([T? result]) => Navigator.of(this).pop<T>(result);
}
