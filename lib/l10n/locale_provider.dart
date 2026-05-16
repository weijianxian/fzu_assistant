import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';

class LocaleState {
  final localeKey = ValueNotifier<String>('system');

  static const _options = [
    ('system', null, 'System'),
    ('zh', Locale('zh'), '中文'),
    ('en', Locale('en'), 'English'),
  ];

  static String labelOf(String key) =>
      _options.firstWhere((o) => o.$1 == key, orElse: () => _options.first).$3;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString(SpKeys.localeKey) ?? 'system';
    final valid = _options.any((o) => o.$1 == saved);
    localeKey.value = valid ? saved : 'system';

    localeKey.addListener(() {
      SharedPreferences.getInstance().then(
        (sp) => sp.setString(SpKeys.localeKey, localeKey.value),
      );
    });
  }

  Locale? get currentLocale {
    final match = _options.where((o) => o.$1 == localeKey.value);
    return match.isNotEmpty ? match.first.$2 : null;
  }

  void dispose() => localeKey.dispose();
}

class LocaleProvider extends InheritedWidget {
  final LocaleState state;
  const LocaleProvider({super.key, required this.state, required super.child});

  static LocaleState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LocaleProvider>()!.state;
  }

  @override
  bool updateShouldNotify(LocaleProvider old) => localeKey != old.localeKey;

  ValueNotifier<String> get localeKey => state.localeKey;
}
