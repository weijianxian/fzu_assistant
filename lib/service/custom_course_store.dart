import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local user data stays separate from fetched academic caches and survives logout.
class CustomCourseStore extends ValueNotifier<List<CustomCourse>> {
  CustomCourseStore() : super(const []);
  static final instance = CustomCourseStore();
  static const storageKey = 'custom_courses_v1';
  Future<void> _pending = Future.value();
  bool _loaded = false;

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.catchError((Object _) {});
    return next;
  }

  /// Also used after WebDAV restores the stored JSON.
  Future<void> load() => _serialize(_read);

  Future<void> _read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    final loaded = raw == null
        ? <CustomCourse>[]
        : CustomCourse.parseList(jsonDecode(raw));
    value = List.unmodifiable(loaded);
    _loaded = true;
  }

  List<CustomCourse> forTerm(String account, String term) => value
      .where((course) => course.account == account && course.term == term)
      .toList(growable: false);

  List<Course> coursesForTerm(String account, String term) => forTerm(
    account,
    term,
  ).map((course) => course.toCourse()).toList(growable: false);

  int? colorForCourse(Course course) => value
      .where((entry) => entry.courseType == course.type)
      .firstOrNull
      ?.color;

  Future<void> save(CustomCourse course, {CustomCourse? previous}) =>
      _serialize(() async {
        course.validate();
        if (!_loaded) await _read();
        if (previous != null &&
            (previous.account != course.account || previous.id != course.id)) {
          throw StateError('不能将课程移动到其他账号');
        }
        if (previous != null &&
            previous.key != course.key &&
            value.any((entry) => entry.key == course.key)) {
          throw StateError('目标学期已存在这门自定义课程');
        }
        await _write([
          for (final entry in value)
            if (entry.key != course.key && entry.key != previous?.key) entry,
          course,
        ]);
      });

  Future<void> remove(CustomCourse course) => _serialize(() async {
    if (!_loaded) await _read();
    await _write(value.where((entry) => entry.key != course.key).toList());
  });

  Future<void> replaceAll(List<CustomCourse> courses) => _serialize(() async {
    final validated = CustomCourse.parseList(
      courses.map((entry) => entry.toJson()).toList(),
    );
    await _write(validated);
  });

  Future<void> _write(List<CustomCourse> courses) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      storageKey,
      jsonEncode(courses.map((course) => course.toJson()).toList()),
    );
    if (!saved) throw StateError('无法保存自定义课程');
    _loaded = true;
    value = List.unmodifiable(courses);
  }
}
