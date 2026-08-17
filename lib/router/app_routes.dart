import 'package:flutter/material.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const gpa = '/gpa';
  static const marks = '/marks';
  static const credit = '/credit';
  static const unifiedExam = '/unified-exam';
  static const examRoom = '/exam-room';
  static const emptyRoom = '/empty-room';
  static const notice = '/notice';
  static const evaluation = '/evaluation';
  static const calendar = '/calendar';
  static const settings = '/settings';
  static const homeSettings = '/settings/home';
  static const generalSettings = '/settings/general';
  static const advancedSettings = '/settings/advanced';
  static const themeSettings = '/settings/theme';
  static const about = '/about';
  static const dev = '/dev';
  static const devSharedPrefs = '/dev/shared-prefs';
  static const devSecureStorage = '/dev/secure-storage';
  static const webview = '/webview';
  static const editor = '/editor';
}

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

extension NavigationX on BuildContext {
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) =>
      Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);

  Future<T?> pushReplacementNamed<T, TO>(
    String routeName, {
    Object? arguments,
  }) => Navigator.of(
    this,
  ).pushReplacementNamed<T, TO>(routeName, arguments: arguments);
}
