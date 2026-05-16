import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';

class LocaleState {
  final localeIndex = ValueNotifier<int>(0); // 0=系统, 1=中文, 2=English
  static const _defaultKey = 'system';

  static const _options = [
    ('system', null, 'System'),
    ('zh', Locale('zh'), '中文'),
    ('en', Locale('en'), 'English'),
  ];

  static List<String> get labels => _options.map((o) => o.$3).toList();

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final savedKey = sp.getString(SpKeys.localeKey) ?? _defaultKey;
    final idx = _options.indexWhere((o) => o.$1 == savedKey);
    localeIndex.value = idx >= 0 ? idx : 0;

    localeIndex.addListener(() {
      final key = _options[localeIndex.value].$1;
      SharedPreferences.getInstance().then((sp) => sp.setString(SpKeys.localeKey, key));
    });
  }

  Locale? get currentLocale => _options[localeIndex.value].$2;

  void dispose() => localeIndex.dispose();
}

class LocaleProvider extends InheritedWidget {
  final LocaleState state;
  const LocaleProvider({super.key, required this.state, required super.child});

  static LocaleState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LocaleProvider>()!.state;
  }

  @override
  bool updateShouldNotify(LocaleProvider old) => localeIndex != old.localeIndex;

  ValueNotifier<int> get localeIndex => state.localeIndex;
}
