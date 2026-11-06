import 'package:flutter/material.dart';
import 'package:fzu_assistant/screen/toolbox/academic_changes/academic_changes_page.dart';
import 'package:fzu_assistant/screen/settings/calendar_export_page.dart';
import 'package:fzu_assistant/screen/settings/next_course_widget_settings_page.dart';
import 'package:fzu_assistant/screen/toolbox/academic/lectures_page.dart';
import 'package:fzu_assistant/screen/toolbox/job_fair/job_fair_page.dart';
import 'package:fzu_assistant/screen/toolbox/utility_payment/utility_payment_page.dart';
import 'package:fzu_assistant/screen/toolbox/paper/papers_page.dart';
import 'package:fzu_assistant/screen/toolbox/academic/cultivate_plan_page.dart';
import 'package:fzu_assistant/screen/settings/webdav_settings_page.dart';
import 'package:fzu_assistant/screen/settings/custom_courses_page.dart';
import 'package:fzu_assistant/screen/settings/hidden_courses_page.dart';
import 'package:fzu_assistant/screen/toolbox/campus_services/campus_services_page.dart';
import 'package:fzu_assistant/screen/settings/third_party_settings_page.dart';
import 'package:fzu_assistant/screen/settings/android_permissions_page.dart';
import 'package:fzu_assistant/screen/settings/course_reminder_settings_page.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/my/account_management_page.dart';
import 'package:fzu_assistant/screen/campus_code/campus_code_page.dart';
import 'package:fzu_assistant/screen/dev/dev_tool.dart';
import 'package:fzu_assistant/screen/dev/learning_center_debug_page.dart';
import 'package:fzu_assistant/screen/guest/sso_login_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_center_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_seats_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_available_seats_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_seat_times_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_appointments_page.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_scanner_page.dart';
import 'package:fzu_assistant/screen/dev/secure_storage_page.dart';
import 'package:fzu_assistant/screen/dev/shared_prefs_page.dart';
import 'package:fzu_assistant/screen/guest/editor_page.dart';
import 'package:fzu_assistant/screen/guest/login.dart';
import 'package:fzu_assistant/screen/guest/webview_page.dart';
import 'package:fzu_assistant/screen/home/home_screen.dart';
import 'package:fzu_assistant/screen/my/about/about_page.dart';
import 'package:fzu_assistant/screen/my/calendar/calendar_page.dart';
import 'package:fzu_assistant/screen/my/profile_page.dart';
import 'package:fzu_assistant/screen/settings/advanced_settings_page.dart';
import 'package:fzu_assistant/screen/settings/general_settings_page.dart';
import 'package:fzu_assistant/screen/settings/home_settings_page.dart';
import 'package:fzu_assistant/screen/settings/settings_page.dart';
import 'package:fzu_assistant/screen/settings/theme/theme_section.dart';
import 'package:fzu_assistant/screen/toolbox/credit/credit_page.dart';
import 'package:fzu_assistant/screen/toolbox/academic/academic_shortcuts_page.dart';
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
    AppRoutes.jobFair: (_) => const JobFairPage(),
    AppRoutes.lectures: (_) => const LecturesPage(),
    AppRoutes.evaluation: (_) => const EvaluationPage(),
    AppRoutes.academicShortcuts: (_) => const AcademicShortcutsPage(),
    AppRoutes.cultivatePlan: (_) => const CultivatePlanPage(),
    AppRoutes.learningCenter: (_) => const LearningCenterPage(),
    AppRoutes.campusCode: (_) => const CampusCodePage(),
    AppRoutes.campusServices: (_) => const CampusServicesPage(),
    AppRoutes.utilityPayment: (_) => const UtilityPaymentPage(),
    AppRoutes.campusServicesLogin: (_) =>
        const SsoLoginPage(loadStudyToken: false),
    AppRoutes.campusCodeLogin: (_) => const SsoLoginPage(loadStudyToken: false),
    AppRoutes.learningSeats: (_) => const LearningSeatsPage(),
    AppRoutes.learningAppointments: (_) => const LearningAppointmentsPage(),
    AppRoutes.ssoLogin: (_) => const SsoLoginPage(),
    AppRoutes.devLearningCenter: (_) => const LearningCenterDebugPage(),
    AppRoutes.calendar: (_) => const CalendarPage(),
    AppRoutes.profile: (_) => const ProfilePage(),
    AppRoutes.settings: (_) => const SettingsPage(),
    AppRoutes.webDavSettings: (_) => const WebDavSettingsPage(),
    AppRoutes.thirdPartySettings: (_) => const ThirdPartySettingsPage(),
    AppRoutes.courseReminderSettings: (_) => const CourseReminderSettingsPage(),
    AppRoutes.nextCourseWidgetSettings: (_) =>
        const NextCourseWidgetSettingsPage(),
    AppRoutes.androidPermissions: (_) => const AndroidPermissionsPage(),
    AppRoutes.accountManagement: (_) => const AccountManagementPage(),
    AppRoutes.homeSettings: (_) => const HomeSettingsPage(),
    AppRoutes.academicChanges: (_) => const AcademicChangesPage(),
    AppRoutes.calendarExport: (_) => const CalendarExportPage(),
    AppRoutes.customCourses: (_) => const CustomCoursesPage(),
    AppRoutes.hiddenCourses: (_) => const HiddenCoursesPage(),
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
      AppRoutes.papers => MaterialPageRoute(
        settings: settings,
        builder: (_) =>
            PapersPage(path: (settings.arguments as PapersArgs?)?.path ?? '/'),
      ),
      AppRoutes.customCourseEdit => MaterialPageRoute(
        settings: settings,
        builder: (_) => CustomCourseEditPage(
          args: settings.arguments as CustomCourseEditArgs,
        ),
      ),
      AppRoutes.learningSeatTimes => MaterialPageRoute(
        settings: settings,
        builder: (_) {
          final args = settings.arguments as LearningSeatTimesArgs;
          return LearningSeatTimesPage(
            spaceId: args.spaceId,
            date: args.date,
            floor: args.floor,
            seatName: args.seatName,
          );
        },
      ),
      AppRoutes.learningAvailableSeats => MaterialPageRoute(
        settings: settings,
        builder: (_) {
          final args = settings.arguments as LearningAvailableSeatsArgs;
          return LearningAvailableSeatsPage(
            date: args.date,
            begin: args.begin,
            end: args.end,
            floor: args.floor,
          );
        },
      ),
      AppRoutes.learningScanner => MaterialPageRoute(
        settings: settings,
        builder: (_) {
          final args = settings.arguments as LearningScannerArgs;
          return LearningScannerPage(
            appointmentId: args.appointmentId,
            token: args.token,
          );
        },
      ),
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
        injectSsoCookies: args.injectSsoCookies,
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
