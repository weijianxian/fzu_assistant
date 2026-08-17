import 'package:flutter/material.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/dev/dev_tool.dart';
import 'package:fzu_assistant/screen/dev/secure_storage_page.dart';
import 'package:fzu_assistant/screen/dev/shared_prefs_page.dart';
import 'package:fzu_assistant/screen/guest/editor_page.dart';
import 'package:fzu_assistant/screen/guest/login.dart';
import 'package:fzu_assistant/screen/guest/webview_page.dart';
import 'package:fzu_assistant/screen/home/home_screen.dart';
import 'package:fzu_assistant/screen/my/about/about_page.dart';
import 'package:fzu_assistant/screen/my/calendar/calendar_page.dart';
import 'package:fzu_assistant/screen/settings/advanced_settings_page.dart';
import 'package:fzu_assistant/screen/settings/general_settings_page.dart';
import 'package:fzu_assistant/screen/settings/home_settings_page.dart';
import 'package:fzu_assistant/screen/settings/settings_page.dart';
import 'package:fzu_assistant/screen/settings/theme/theme_section.dart';
import 'package:fzu_assistant/screen/toolbox/credit/credit_page.dart';
import 'package:fzu_assistant/screen/toolbox/empty_room/empty_room_page.dart';
import 'package:fzu_assistant/screen/toolbox/evaluation/evaluation_page.dart';
import 'package:fzu_assistant/screen/toolbox/exam_room/exam_room_page.dart';
import 'package:fzu_assistant/screen/toolbox/gpa/gpa_page.dart';
import 'package:fzu_assistant/screen/toolbox/marks/marks_page.dart';
import 'package:fzu_assistant/screen/toolbox/notice/notice_page.dart';
import 'package:fzu_assistant/screen/toolbox/unified_exam/unified_exam_page.dart';

abstract final class AppRouter {
  static final _routes = <String, WidgetBuilder>{
    AppRoutes.login: (_) => const LoginPage(),
    AppRoutes.home: (_) => const HomeScreen(),
    AppRoutes.gpa: (_) => const GpaPage(),
    AppRoutes.marks: (_) => const MarksPage(),
    AppRoutes.credit: (_) => const CreditPage(),
    AppRoutes.unifiedExam: (_) => const UnifiedExamPage(),
    AppRoutes.examRoom: (_) => const ExamRoomPage(),
    AppRoutes.emptyRoom: (_) => const EmptyRoomPage(),
    AppRoutes.notice: (_) => const NoticePage(),
    AppRoutes.evaluation: (_) => const EvaluationPage(),
    AppRoutes.calendar: (_) => const CalendarPage(),
    AppRoutes.settings: (_) => const SettingsPage(),
    AppRoutes.homeSettings: (_) => const HomeSettingsPage(),
    AppRoutes.generalSettings: (_) => const GeneralSettingsPage(),
    AppRoutes.advancedSettings: (_) => const AdvancedSettingsPage(),
    AppRoutes.themeSettings: (_) => const ThemeSection(),
    AppRoutes.about: (_) => const AboutPage(),
    AppRoutes.dev: (_) => const DevToolPage(),
    AppRoutes.devSharedPrefs: (_) => const SharedPrefsPage(),
    AppRoutes.devSecureStorage: (_) => const SecureStoragePage(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = _routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }

    return switch (settings.name) {
      AppRoutes.webview => _webViewRoute(settings),
      AppRoutes.editor => _editorRoute(settings),
      _ => null,
    };
  }

  static Route<dynamic> _webViewRoute(RouteSettings settings) {
    final args = settings.arguments as WebViewArgs;
    return MaterialPageRoute(
      builder: (_) => WebViewPage(
        url: args.url,
        title: args.title,
        injectCookies: args.injectCookies,
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _editorRoute(RouteSettings settings) {
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
}
